import Foundation

final class MicMonitor {
  var config: AppConfig
  var onUpdate: ((MicMonitor.Status) -> Void)?

  struct Status {
    var micActive: Bool
    var lastAction: String
  }

  private var timer: DispatchSourceTimer?
  private var isMicActive = false
  private var activeSince: Date?
  private var idleSince: Date?
  private var pausedByUs = false
  private var lastAction = "待机"

  init(config: AppConfig) {
    self.config = config
  }

  func start() {
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    timer.schedule(deadline: .now() + 0.3, repeating: .milliseconds(250))
    timer.setEventHandler { [weak self] in
      self?.tick()
    }
    self.timer = timer
    timer.resume()
    Logger.shared.log("监听已启动：间隔 250ms")
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }

  private func tick() {
    guard config.enabled else {
      activeSince = nil
      idleSince = nil
      isMicActive = false
      return
    }

    let snapshot = AudioProbe.snapshot()
    let active = evaluate(snapshot)
    let now = Date()

    if active {
      idleSince = nil
      if !isMicActive {
        activeSince = now
      } else if let since = activeSince,
                now.timeIntervalSince(since) >= config.pauseDelaySeconds {
        handleMicStarted()
        activeSince = nil
      }
      isMicActive = true
    } else {
      activeSince = nil
      if isMicActive {
        idleSince = now
      } else if let since = idleSince,
                now.timeIntervalSince(since) >= config.resumeDelaySeconds {
        handleMicStopped()
        idleSince = nil
      }
      isMicActive = false
    }
  }

  private func evaluate(_ snapshot: MicSnapshot) -> Bool {
    let all = snapshot.activeBundleIDs
    let filtered = all.filter { config.isAllowed($0) && !config.isExcluded($0) }
    if !filtered.isEmpty {
      return true
    }
    if !all.isEmpty {
      // 有进程在用麦，但全部命中黑名单（例如微信语音、网易云听歌识曲）
      return false
    }
    return config.treatUnattributedDeviceAsActive && !snapshot.activeDeviceNames.isEmpty
  }

  private func handleMicStarted() {
    guard NeteaseController.isRunning else {
      lastAction = "麦克风占用（网易云未运行）"
      Logger.shared.log(lastAction)
      emit()
      return
    }

    switch NeteaseController.state() {
    case .playing:
      if NeteaseController.pause() {
        pausedByUs = true
        lastAction = "麦克风占用 → 已暂停网易云"
        Logger.shared.log(lastAction)
      } else {
        lastAction = "暂停指令发送失败"
        Logger.shared.log(lastAction)
      }
    case .paused:
      lastAction = "麦克风占用（网易云本来就是暂停的）"
      Logger.shared.log(lastAction)
    case .unknown:
      lastAction = "读不到网易云状态（辅助功能权限？）"
      Logger.shared.log(lastAction)
    }
    emit()
  }

  private func handleMicStopped() {
    guard pausedByUs else {
      lastAction = "麦克风空闲（无需恢复）"
      Logger.shared.log(lastAction)
      emit()
      return
    }
    pausedByUs = false

    guard NeteaseController.isRunning, NeteaseController.state() == .paused else {
      lastAction = "麦克风空闲（网易云已播放中，跳过恢复）"
      Logger.shared.log(lastAction)
      emit()
      return
    }

    if NeteaseController.resume() {
      lastAction = "麦克风空闲 → 已恢复播放"
    } else {
      lastAction = "恢复指令发送失败"
    }
    Logger.shared.log(lastAction)
    emit()
  }

  private func emit() {
    onUpdate?(Status(micActive: isMicActive, lastAction: lastAction))
  }
}
