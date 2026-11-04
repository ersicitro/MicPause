import Foundation

enum MediaRemoteCommand: Int32 {
  case play = 0
  case pause = 1
  case togglePlayPause = 2
  case stop = 3
}

enum MediaRemoteProbe {
  private typealias BoolCallback = @convention(block) (Bool) -> Void
  private typealias GetIsPlaying = @convention(c) (DispatchQueue, BoolCallback) -> Void

  private typealias IntCallback = @convention(block) (Int32) -> Void
  private typealias GetPlaybackState = @convention(c) (DispatchQueue, IntCallback) -> Void

  private typealias ObjectCallback = @convention(block) (AnyObject?) -> Void
  private typealias GetClient = @convention(c) (DispatchQueue, ObjectCallback) -> Void

  private typealias GetClientBundleID = @convention(c) (AnyObject) -> Unmanaged<CFString>?
  private typealias GetClientParentBundleID = @convention(c) (AnyObject) -> Unmanaged<CFString>?

  private typealias SendCommand = @convention(c) (Int32, NSDictionary, (@convention(block) (Int32) -> Void)?) -> Void

  private static var handle: UnsafeMutableRawPointer?

  private static func open() -> UnsafeMutableRawPointer? {
    if let handle { return handle }
    let paths = [
      "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
      "/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/MediaRemote"
    ]
    for path in paths {
      if let opened = dlopen(path, RTLD_LAZY) {
        handle = opened
        return opened
      }
    }
    return nil
  }

  static func nowPlayingClientBundleID() -> String? {
    guard let handle = open(),
          let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingClient") else {
      return nil
    }
    let getter = unsafeBitCast(symbol, to: GetClient.self)

    let callback: ObjectCallback = { client in
      guard let client else { return }
      let resolved = bundleID(of: client)
      pendingBundleID = resolved
      pendingSemaphore?.signal()
    }

    pendingBundleID = nil
    let semaphore = DispatchSemaphore(value: 0)
    pendingSemaphore = semaphore
    getter(DispatchQueue.global(), callback)
    _ = semaphore.wait(timeout: .now() + 0.5)
    pendingSemaphore = nil
    return pendingBundleID
  }

  private static var pendingBundleID: String?
  private static var pendingSemaphore: DispatchSemaphore?

  private static func bundleID(of client: AnyObject) -> String? {
    guard let handle = open() else { return nil }
    for symbolName in ["MRNowPlayingClientGetBundleIdentifier", "MRNowPlayingClientGetParentAppBundleIdentifier"] {
      guard let symbol = dlsym(handle, symbolName) else { continue }
      let getter = unsafeBitCast(symbol, to: GetClientBundleID.self)
      if let unmanaged = getter(client) {
        return unmanaged.takeUnretainedValue() as String
      }
    }
    return nil
  }

  static func isPlaying() -> Bool? {
    guard let handle = open(),
          let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
      return nil
    }
    let getter = unsafeBitCast(symbol, to: GetIsPlaying.self)
    var result: Bool?
    let semaphore = DispatchSemaphore(value: 0)
    let callback: BoolCallback = { value in
      result = value
      semaphore.signal()
    }
    getter(DispatchQueue.global(), callback)
    _ = semaphore.wait(timeout: .now() + 0.5)
    return result
  }

  static func playbackState() -> Int32? {
    guard let handle = open(),
          let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPlaybackState") else {
      return nil
    }
    let getter = unsafeBitCast(symbol, to: GetPlaybackState.self)
    var result: Int32?
    let semaphore = DispatchSemaphore(value: 0)
    let callback: IntCallback = { value in
      result = value
      semaphore.signal()
    }
    getter(DispatchQueue.global(), callback)
    _ = semaphore.wait(timeout: .now() + 0.5)
    return result
  }

  @discardableResult
  static func send(_ command: MediaRemoteCommand) -> Bool {
    guard let handle = open(),
          let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else {
      return false
    }
    let sender = unsafeBitCast(symbol, to: SendCommand.self)
    sender(command.rawValue, NSDictionary(), nil)
    return true
  }
}
