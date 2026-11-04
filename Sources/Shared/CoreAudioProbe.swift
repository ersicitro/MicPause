import CoreAudio
import Foundation

struct AudioProcessInfo {
  let objectID: AudioObjectID
  let bundleID: String?
  let isRunningInput: Bool
  let isRunningOutput: Bool
}

struct MicSnapshot {
  var activeBundleIDs: [String]
  var activeDeviceNames: [String]
  var isNeteaseOutputting: Bool

  var isMicActive: Bool {
    !activeBundleIDs.isEmpty || !activeDeviceNames.isEmpty
  }

  var signature: String {
    "in:\(activeBundleIDs.sorted().joined(separator: ","))|dev:\(activeDeviceNames.sorted().joined(separator: ","))|ne:\(isNeteaseOutputting)"
  }
}

enum NeteaseTarget {
  static let bundlePrefix = "com.netease.163music"
}

enum AudioProbe {
  static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  static func address(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
  }

  static func objectIDs(_ objectID: AudioObjectID, _ addr: inout AudioObjectPropertyAddress) -> [AudioObjectID] {
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size) == noErr, size > 0 else {
      return []
    }
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var ids = [AudioObjectID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &ids) == noErr else {
      return []
    }
    return ids
  }

  static func processObjectIDs() -> [AudioObjectID] {
    var addr = address(kAudioHardwarePropertyProcessObjectList)
    return objectIDs(systemObject, &addr)
  }

  static func stringProperty(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var size = UInt32(MemoryLayout<CFString?>.size)
    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<CFString?>.alignment
    )
    defer { raw.deallocate() }
    let pointer = raw.bindMemory(to: CFString?.self, capacity: 1)
    pointer.initialize(to: nil)
    defer { pointer.deinitialize(count: 1) }
    guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, raw) == noErr else {
      return nil
    }
    return pointer.pointee as String?
  }

  static func flagProperty(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
    var addr = address(selector)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &value) == noErr else {
      return false
    }
    return value != 0
  }

  static func processes() -> [AudioProcessInfo] {
    processObjectIDs().map { objectID in
      AudioProcessInfo(
        objectID: objectID,
        bundleID: stringProperty(objectID, kAudioProcessPropertyBundleID),
        isRunningInput: flagProperty(objectID, kAudioProcessPropertyIsRunningInput),
        isRunningOutput: flagProperty(objectID, kAudioProcessPropertyIsRunningOutput)
      )
    }
  }

  static func inputDevices() -> [AudioDeviceID] {
    var addr = address(kAudioHardwarePropertyDevices)
    return objectIDs(systemObject, &addr).filter { inputChannelCount($0) > 0 }
  }

  static func deviceName(_ device: AudioDeviceID) -> String {
    stringProperty(device, kAudioObjectPropertyName) ?? "device-\(device)"
  }

  static func isDeviceInputRunning(_ device: AudioDeviceID) -> Bool {
    flagProperty(device, kAudioDevicePropertyDeviceIsRunningSomewhere)
      || flagProperty(device, kAudioDevicePropertyDeviceIsRunningSomewhere, scope: kAudioDevicePropertyScopeInput)
  }

  static func inputChannelCount(_ device: AudioDeviceID) -> UInt32 {
    var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else {
      return 0
    }
    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { raw.deallocate() }
    let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, list) == noErr else {
      return 0
    }
    return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + $1.mNumberChannels }
  }

  static func snapshot() -> MicSnapshot {
    let all = processes()
    let micBundles = all.filter(\.isRunningInput).compactMap(\.bundleID)
    let neteaseOutputting = all.contains { process in
      guard let bundleID = process.bundleID else { return false }
      return bundleID.hasPrefix(NeteaseTarget.bundlePrefix) && process.isRunningOutput
    }
    let runningDevices = inputDevices().filter(isDeviceInputRunning).map(deviceName)

    return MicSnapshot(
      activeBundleIDs: micBundles,
      activeDeviceNames: runningDevices,
      isNeteaseOutputting: neteaseOutputting
    )
  }
}

extension AudioProbe {
  static func flagProperty(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope
  ) -> Bool {
    var addr = address(selector, scope: scope)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &value) == noErr else {
      return false
    }
    return value != 0
  }
}
