import ApplicationServices
import AppKit
import Foundation

enum AccessibilityProbe {
  static func isTrusted(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  static func dump(bundleID: String, depthLimit: Int = 6) -> [String] {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
      return ["未找到运行中的应用: \(bundleID)"]
    }

    let element = AXUIElementCreateApplication(app.processIdentifier)
    var lines: [String] = []
    walk(element, depth: 0, depthLimit: depthLimit, lines: &lines)
    return lines
  }

  static func findButtons(bundleID: String) -> [String] {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
      return ["未找到运行中的应用: \(bundleID)"]
    }

    let element = AXUIElementCreateApplication(app.processIdentifier)
    var found: [String] = []
    collect(element, depth: 0, found: &found)
    return found
  }

  static func controlMenuItem(bundleID: String, menuTitle: String, itemTitles: Set<String>) -> (item: AXUIElement, title: String)? {
    guard let element = applicationElement(bundleID) else { return nil }
    return search(element, depth: 0, menuTitle: menuTitle, itemTitles: itemTitles)
  }

  static func applicationElement(_ bundleID: String) -> AXUIElement? {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
      return nil
    }
    return AXUIElementCreateApplication(app.processIdentifier)
  }

  private static func search(
    _ element: AXUIElement,
    depth: Int,
    menuTitle: String,
    itemTitles: Set<String>
  ) -> (item: AXUIElement, title: String)? {
    guard depth <= 6 else { return nil }
    if role(of: element) == kAXMenuBarItemRole as String,
       (value(element, kAXTitleAttribute) as? String) == menuTitle {
      for child in children(of: element) {
        for grandchild in children(of: child) {
          if role(of: grandchild) == kAXMenuItemRole as String,
             let title = value(grandchild, kAXTitleAttribute) as? String,
             itemTitles.contains(title) {
            return (grandchild, title)
          }
        }
      }
    }
    for child in children(of: element) {
      if let found = search(child, depth: depth + 1, menuTitle: menuTitle, itemTitles: itemTitles) {
        return found
      }
    }
    return nil
  }

  @discardableResult
  static func activate(bundleID: String) -> Bool {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
      return false
    }
    return app.activate(options: .activateIgnoringOtherApps)
  }

  @discardableResult
  static func press(_ element: AXUIElement) -> Bool {
    AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
  }

  private static func value(_ element: AXUIElement, _ attribute: String) -> Any? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else {
      return nil
    }
    return ref
  }

  private static func role(of element: AXUIElement) -> String {
    value(element, kAXRoleAttribute) as? String ?? "?"
  }

  private static func describe(_ element: AXUIElement) -> String {
    let role = role(of: element)
    let title = value(element, kAXTitleAttribute) as? String
    let description = value(element, kAXDescriptionAttribute) as? String
    let identifier = value(element, kAXIdentifierAttribute) as? String
    var parts = [role, title, description, identifier].compactMap { $0 }.filter { !$0.isEmpty }
    if role == kAXMenuItemRole as String {
      if let cmdChar = value(element, "AXMenuItemCmdChar") as? String {
        parts.append("cmd=\(cmdChar)")
      }
      if let cmdVirtualKey = value(element, "AXMenuItemCmdVirtualKey") as? Int {
        parts.append("vk=\(cmdVirtualKey)")
      }
      if let cmdModifiers = value(element, "AXMenuItemCmdModifiers") as? Int {
        parts.append("mod=\(cmdModifiers)")
      }
    }
    return parts.joined(separator: " | ")
  }

  private static func children(of element: AXUIElement) -> [AXUIElement] {
    guard let raw = value(element, kAXChildrenAttribute), let list = raw as? [AXUIElement] else {
      return []
    }
    return list
  }

  private static func walk(_ element: AXUIElement, depth: Int, depthLimit: Int, lines: inout [String]) {
    guard depth <= depthLimit else { return }
    lines.append(String(repeating: "  ", count: depth) + describe(element))
    for child in children(of: element) {
      walk(child, depth: depth + 1, depthLimit: depthLimit, lines: &lines)
    }
  }

  private static func collect(_ element: AXUIElement, depth: Int, found: inout [String]) {
    guard depth <= 8 else { return }
    if role(of: element) == kAXButtonRole as String {
      found.append("depth=\(depth) " + describe(element))
    }
    for child in children(of: element) {
      collect(child, depth: depth + 1, found: &found)
    }
  }
}
