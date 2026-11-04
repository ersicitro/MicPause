import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let monitor: MicMonitor
  private var config: AppConfig
  private var micActive = false

  init(monitor: MicMonitor, config: AppConfig) {
    self.monitor = monitor
    self.config = config
    super.init()

    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu

    updateIcon()

    monitor.onUpdate = { [weak self] status in
      self?.micActive = status.micActive
      self?.updateIcon()
    }
  }

  private func updateIcon() {
    // 菜单栏图标：打包时由 install.sh 放进 Contents/Resources/shh_menu_bar.png。
    // 彩色原样显示（不是 template），停用时降透明度。
    if let path = Bundle.main.path(forResource: "shh_menu_bar", ofType: "png"),
       let image = NSImage(contentsOfFile: path) {
      image.isTemplate = false
      image.size = NSSize(width: 20, height: 20)
      statusItem.button?.image = image
      statusItem.button?.appearsDisabled = !config.enabled
    } else if let image = NSImage(systemSymbolName: micActive ? "mic.fill" : "mic",
                                  accessibilityDescription: "MicPause") {
      image.isTemplate = true
      statusItem.button?.image = image
    }
    statusItem.button?.title = micActive ? " 占用中" : ""
  }

  // 每次点开菜单都重新构建，状态永远是最新的
  func menuWillOpen(_ menu: NSMenu) {
    rebuild(menu)
  }

  private func addInfoItem(_ menu: NSMenu, _ title: String) {
    menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
  }

  private func addActionItem(_ menu: NSMenu, _ title: String, _ selector: Selector) {
    let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
    item.target = self
    menu.addItem(item)
  }

  private func rebuild(_ menu: NSMenu) {
    menu.removeAllItems()

    let snapshot = AudioProbe.snapshot()
    addInfoItem(menu, "麦克风：\(snapshot.isMicActive ? "占用中" : "空闲")")

    let neteaseLabel: String
    if NeteaseController.isRunning {
      switch NeteaseController.state() {
      case .playing: neteaseLabel = "播放中"
      case .paused: neteaseLabel = "已暂停"
      case .unknown: neteaseLabel = "状态未知"
      }
    } else {
      neteaseLabel = "未运行"
    }
    addInfoItem(menu, "网易云音乐：\(neteaseLabel)")

    menu.addItem(NSMenuItem.separator())

    addActionItem(
      menu,
      config.enabled ? "停用自动化（当前：启用）" : "启动自动化（当前：停用）",
      #selector(toggleEnabled)
    )
    addActionItem(
      menu,
      "开机自启：\(LoginItemController.isEnabled ? "已开启" : "未开启")",
      #selector(toggleLoginItem)
    )
    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(title: "退出 MicPause", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
  }

  @objc private func toggleEnabled() {
    config.enabled.toggle()
    config.save()
    monitor.config = config
    Logger.shared.log("总开关 -> \(config.enabled ? "启用" : "停用")")
    if !config.enabled {
      micActive = false
    }
    updateIcon()
  }

  @objc private func toggleLoginItem() {
    if LoginItemController.isEnabled {
      LoginItemController.disable()
    } else if !LoginItemController.enable() {
      let alert = NSAlert()
      alert.messageText = "无法设置开机自启"
      alert.informativeText = "可以在 系统设置 > 通用 > 登录项 中手动添加 MicPause。"
      alert.runModal()
    }
  }

  @objc private func quit() {
    Logger.shared.log("退出")
    NSApp.terminate(nil)
  }
}
