import Foundation
import ServiceManagement

enum LoginItemController {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  @discardableResult
  static func enable() -> Bool {
    do {
      try SMAppService.mainApp.register()
      Logger.shared.log("开机自启 -> 已启用")
      return true
    } catch {
      Logger.shared.log("开机自启启用失败：\(error.localizedDescription)")
      return false
    }
  }

  @discardableResult
  static func disable() -> Bool {
    do {
      try SMAppService.mainApp.unregister()
      Logger.shared.log("开机自启 -> 已停用")
      return true
    } catch {
      Logger.shared.log("开机自启停用失败：\(error.localizedDescription)")
      return false
    }
  }

  /// 首次启动时自动注册一次，之后完全由菜单栏开关控制。
  static func registerIfNeeded() {
    switch SMAppService.mainApp.status {
    case .enabled:
      Logger.shared.log("开机自启：已启用")
    case .requiresApproval:
      Logger.shared.log("开机自启：需要在 系统设置 > 通用 > 登录项 中批准")
    default:
      // .notRegistered / .notFound 都直接尝试注册；.notFound 实际也能注册成功
      _ = enable()
    }
  }
}
