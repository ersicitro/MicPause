import AppKit
import Foundation

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let config = AppConfig.load()
Logger.shared.enabled = config.writeLogFile
AXTrust.evaluateAtStartup()

let monitor = MicMonitor(config: config)
let statusBarController = StatusBarController(monitor: monitor, config: config)

monitor.start()
Logger.shared.log("MicPause 已在菜单栏启动")
LoginItemController.registerIfNeeded()

if !AXTrust.isTrusted {
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    Logger.shared.log("警告：没有辅助功能权限，无法控制网易云音乐")
    let alert = NSAlert()
    alert.messageText = "MicPause 需要设备控制权限"
    alert.informativeText = "网易云音乐不支持 AppleScript 和媒体键，MicPause 通过它的原生菜单来暂停/恢复播放。请在 系统设置 > 隐私与安全 中打开「辅助功能」（新版系统可能叫「设备控制和数据访问」），添加并允许 MicPause，然后退出并重新打开本工具。"
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后自己设置")
    if alert.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
      )
    }
  }
}

application.run()
