import Foundation

struct AppConfig: Codable {
  /// 总开关
  var enabled: Bool = true
  /// 麦克风释放后，等待多少秒确认真的空闲，再恢复播放（去抖）
  var resumeDelaySeconds: Double = 0.6
  /// 麦克风占用持续多少秒才暂停，避免极短促的误触发
  var pauseDelaySeconds: Double = 0.15
  /// 是否把「无法归因到具体 App 的输入设备占用」也算作麦克风活跃
  var treatUnattributedDeviceAsActive: Bool = true
  /// 黑名单：这些 App 用麦克风时不暂停音乐
  /// 网易云自己必须在列表里——它的「听歌识曲」会开麦，否则会把自己暂停掉
  var excludedBundleIDs: [String] = [
    "com.netease.163music",
    "com.tencent.xinWeChat",
    "com.tencent.WeChatMac",
    "us.zoom.xos",
    "com.microsoft.teams2",
    "com.apple.VoiceMemos",
    "com.apple.Photo-Booth",
    "com.apple.FaceTime",
    "com.apple.Siri",
    "com.apple.assistant.assistantd"
  ]
  /// 白名单：非空时，只有这些 App 用麦克风才暂停（前缀匹配）
  var allowedBundleIDs: [String] = []
  /// 写日志
  var writeLogFile: Bool = true

  static let defaultConfig = AppConfig()

  static var fileURL: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent("MicPause/config.json")
  }

  static var logFileURL: URL {
    FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
      .appendingPathComponent("Logs/micpause.log")
  }

  static func load() -> AppConfig {
    guard let data = try? Data(contentsOf: fileURL),
          let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
      let config = defaultConfig
      config.save()
      return config
    }
    return config
  }

  func save() {
    let directory = AppConfig.fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(self) else { return }
    try? data.write(to: AppConfig.fileURL)
  }

  func isExcluded(_ bundleID: String) -> Bool {
    excludedBundleIDs.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
  }

  func isAllowed(_ bundleID: String) -> Bool {
    guard !allowedBundleIDs.isEmpty else { return true }
    return allowedBundleIDs.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
  }
}

final class Logger {
  static let shared = Logger()

  var enabled: Bool = true

  private let queue = DispatchQueue(label: "com.micpause.logger")
  private var fileHandle: FileHandle?

  private init() {
    let url = AppConfig.logFileURL
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if !FileManager.default.fileExists(atPath: url.path) {
      FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    fileHandle = FileHandle(forWritingAtPath: url.path)
    fileHandle?.seekToEndOfFile()
  }

  func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let line = "[\(formatter.string(from: Date()))] \(message)\n"
    queue.async { [weak self] in
      guard let data = line.data(using: .utf8) else { return }
      if self?.enabled == true {
        self?.fileHandle?.write(data)
      }
      FileHandle.standardOutput.write(data)
    }
  }
}
