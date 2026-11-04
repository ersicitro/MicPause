import Foundation

/// 无障碍授权状态只在启动时评估一次并缓存。
/// 未授权时绝不能调用 AX 读写接口——那样每次调用都会让系统弹一次权限框。
/// TCC 的授权状态对进程是缓存的，授权后必须重启本工具才会生效。
enum AXTrust {
  private(set) static var isTrusted = false

  static func evaluateAtStartup() {
    isTrusted = AccessibilityProbe.isTrusted(prompt: false)
  }
}
