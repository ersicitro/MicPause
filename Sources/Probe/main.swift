import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "state"

func timestamp() -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm:ss.SSS"
  return formatter.string(from: Date())
}

func printSnapshot(_ snapshot: MicSnapshot) {
  print("[\(timestamp())] 麦克风活跃=\(snapshot.isMicActive) 网易云出声=\(snapshot.isNeteaseOutputting)")
  if !snapshot.activeBundleIDs.isEmpty {
    for bundleID in snapshot.activeBundleIDs.sorted() {
      print("    麦: \(bundleID)")
    }
  }
  if !snapshot.activeDeviceNames.isEmpty {
    for name in snapshot.activeDeviceNames.sorted() {
      print("    设备: \(name)")
    }
  }
}

switch command {
case "state":
  let snapshot = AudioProbe.snapshot()
  printSnapshot(snapshot)

case "watch":
  print("开始监听（Ctrl+C 退出）。请现在去播放网易云音乐，然后在 ChatGPT / Codex / WorkBuddy 里做一次语音输入。")
  var last = AudioProbe.snapshot().signature
  printSnapshot(AudioProbe.snapshot())
  while true {
    let snapshot = AudioProbe.snapshot()
    if snapshot.signature != last {
      last = snapshot.signature
      printSnapshot(snapshot)
    }
    Thread.sleep(forTimeInterval: 0.25)
  }

case "mediakey":
  print("发送媒体键 播放/暂停 -> \(MediaKey.sendPlayPause() ? "成功" : "失败")")

case "trypause":
  let before = AudioProbe.snapshot()
  print("暂停前：网易云出声=\(before.isNeteaseOutputting)")
  guard before.isNeteaseOutputting else {
    print("网易云当前没有出声，无法判断。请先在网易云里播放一首歌再运行本命令。")
    exit(2)
  }
  print("发送媒体键 ...")
  _ = MediaKey.sendPlayPause()
  Thread.sleep(forTimeInterval: 1.5)
  let after = AudioProbe.snapshot()
  print("暂停后：网易云出声=\(after.isNeteaseOutputting)")
  if !after.isNeteaseOutputting {
    print("结论：媒体键 >> 生效，网易云已暂停")
  } else {
    print("结论：媒体键 >> 无效，网易云仍在播放")
  }

case "mr":
  print("now playing client: \(MediaRemoteProbe.nowPlayingClientBundleID() ?? "无")")
  print("is playing: \(MediaRemoteProbe.isPlaying().map(String.init) ?? "无")")
  print("playback state: \(MediaRemoteProbe.playbackState().map(String.init) ?? "无")")

case "mrpause":
  let before = AudioProbe.snapshot()
  print("发送前：网易云出声=\(before.isNeteaseOutputting)")
  print("send command -> \(MediaRemoteProbe.send(.togglePlayPause) ? "已发送" : "发送失败")")
  Thread.sleep(forTimeInterval: 1.5)
  let after = AudioProbe.snapshot()
  print("发送后：网易云出声=\(after.isNeteaseOutputting)")
  print(before.isNeteaseOutputting && !after.isNeteaseOutputting ? "结论：MediaRemote >> 生效" : "结论：MediaRemote >> 无效")

case "controlstate":
  guard let found = AccessibilityProbe.controlMenuItem(
    bundleID: NeteaseTarget.bundlePrefix,
    menuTitle: "控制",
    itemTitles: ["暂停", "播放"]
  ) else {
    print("未找到控制菜单项"); exit(3)
  }
  print("菜单项标题=\(found.title) -> \(found.title == "暂停" ? "正在播放" : "已暂停")")
  let snapshot = AudioProbe.snapshot()
  print("（参考）CoreAudio 输出运行中=\(snapshot.isNeteaseOutputting) 麦克风活跃=\(snapshot.isMicActive)")

case "trymenu":
  let before = AudioProbe.snapshot()
  print("触发前：网易云出声=\(before.isNeteaseOutputting)")
  guard let found = AccessibilityProbe.controlMenuItem(
    bundleID: NeteaseTarget.bundlePrefix,
    menuTitle: "控制",
    itemTitles: ["暂停", "播放"]
  ) else {
    print("没有在「控制」菜单里找到 暂停/播放 菜单项")
    exit(3)
  }
  if arguments.count > 1, arguments[1] == "activate" {
    print("先激活网易云 -> \(AccessibilityProbe.activate(bundleID: NeteaseTarget.bundlePrefix) ? "成功" : "失败")")
    Thread.sleep(forTimeInterval: 0.6)
  }
  print("找到菜单项：\(found.title) -> 按下")
  print("AXPress -> \(AccessibilityProbe.press(found.item) ? "成功" : "失败")")
  Thread.sleep(forTimeInterval: 1.5)
  let after = AudioProbe.snapshot()
  print("触发后：网易云出声=\(after.isNeteaseOutputting)")
  if before.isNeteaseOutputting != after.isNeteaseOutputting {
    print("结论：菜单触发 >> 生效（\(before.isNeteaseOutputting ? "已暂停" : "已恢复播放")）")
  } else {
    print("结论：菜单触发 >> 状态没变")
  }

case "axtrusted":
  print("辅助功能权限: \(AccessibilityProbe.isTrusted(prompt: false) ? "已授权" : "未授权")")

case "axdump":
  let bundleID = arguments.count > 1 ? arguments[1] : NeteaseTarget.bundlePrefix
  guard AccessibilityProbe.isTrusted(prompt: true) else {
    print("没有辅助功能权限，请在 系统设置 > 隐私与安全性 > 辅助功能 中把当前终端加进去。")
    exit(1)
  }
  for line in AccessibilityProbe.dump(bundleID: bundleID) {
    print(line)
  }

case "axbuttons":
  let bundleID = arguments.count > 1 ? arguments[1] : NeteaseTarget.bundlePrefix
  guard AccessibilityProbe.isTrusted(prompt: true) else {
    print("没有辅助功能权限。")
    exit(1)
  }
  let buttons = AccessibilityProbe.findButtons(bundleID: bundleID)
  print("共找到 \(buttons.count) 个按钮：")
  for button in buttons { print("  " + button) }

default:
  print("""
  用法: micprobe <命令>
    state      打印一次当前麦克风/网易云状态
    watch      持续监听，状态变化才打印
    mediakey   发送一次播放/暂停媒体键
    trypause   验证媒体键能否暂停网易云（需先在网易云里播放音乐）
    axdump     Dump 指定 bundle id 的无障碍树
    axbuttons  列出指定 bundle id 的所有按钮
  """)
}
