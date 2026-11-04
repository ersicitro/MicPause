import ApplicationServices
import Foundation

enum PlaybackState: String {
  case playing
  case paused
  case unknown
}

/// 网易云音乐是 CEF 应用：无 AppleScript、无媒体键、内容区无障碍树为空。
/// 唯一可靠的接口是它的原生菜单栏：控制 -> 暂停/播放。
/// 菜单标题本身即状态：标题为「暂停」表示正在播放，标题为「播放」表示已暂停。
final class NeteaseController {
  static let bundleID = "com.netease.163music"

  private static let menuTitle = "控制"
  private static let itemTitles: Set<String> = ["暂停", "播放"]

  static var isRunning: Bool {
    AccessibilityProbe.applicationElement(bundleID) != nil
  }

  static func state() -> PlaybackState {
    guard AXTrust.isTrusted else { return .unknown }
    guard let found = controlItem() else { return .unknown }
    return found.title == "暂停" ? .playing : .paused
  }

  /// 暂停。返回是否真的执行了按下动作。
  @discardableResult
  static func pause() -> Bool {
    guard AXTrust.isTrusted else { return false }
    guard let found = controlItem(), found.title == "暂停" else { return false }
    return AccessibilityProbe.press(found.item)
  }

  /// 恢复。返回是否真的执行了按下动作。
  @discardableResult
  static func resume() -> Bool {
    guard AXTrust.isTrusted else { return false }
    guard let found = controlItem(), found.title == "播放" else { return false }
    return AccessibilityProbe.press(found.item)
  }

  private static func controlItem() -> (item: AXUIElement, title: String)? {
    AccessibilityProbe.controlMenuItem(bundleID: bundleID, menuTitle: menuTitle, itemTitles: itemTitles)
  }
}
