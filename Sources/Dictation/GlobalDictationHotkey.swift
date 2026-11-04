import Cocoa
import Carbon

// Only a stopped process owned by this user at the exact helper executable is eligible.
func stoppedHelperPIDs(_ output: String, executable: String, uid: uid_t) -> [pid_t] {
    output.split(separator: "\n").compactMap { line in
        let fields = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        guard fields.count == 4, let pid = pid_t(fields[0]), pid > 1,
              let owner = uid_t(fields[1]), owner == uid,
              fields[2].first == "T", String(fields[3]) == executable else { return nil }
        return pid
    }
}

final class HotkeyApp: NSObject, NSApplicationDelegate {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x43474454
    private var lastTrigger = Date.distantPast
    private var launchToken: UUID?

    func applicationDidFinishLaunching(_ notification: Notification) {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event = event, let context = context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            let app = Unmanaged<HotkeyApp>.fromOpaque(context).takeUnretainedValue()
            guard result == noErr, identifier.signature == app.signature, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            app.launchHelper()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let registered = installed == noErr ? RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &hotkey) : installed

        guard registered == noErr else {
            let alert = NSAlert()
            alert.messageText = "无法注册 ⌘⇧D 全局快捷键"
            alert.informativeText = "系统返回错误 \(registered)。可能已有其他全局工具占用了该组合键。请退出重复运行的听写热键程序，或检查其他快捷键工具。"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        writeStatus("registered: Command+Shift+D; menu-icon=hidden; pid=\(ProcessInfo.processInfo.processIdentifier)")
    }

    private func launchHelper() {
        guard launchToken == nil, Date().timeIntervalSince(lastTrigger) > 0.5 else { return }
        lastTrigger = Date()
        let token = UUID()
        launchToken = token
        // Release a failed/hung launch request so the next deliberate press can recover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.launchToken == token { self?.launchToken = nil }
        }
        // This app registers one hotkey only; the existing authorized helper handles UI automation.
        let helper = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("ChatGPT 听写助手.app")
        guard FileManager.default.fileExists(atPath: helper.path) else { launchToken = nil; return }
        let recovered = recoverStoppedHelper(helper)
        DispatchQueue.main.asyncAfter(deadline: .now() + (recovered ? 0.25 : 0)) {
            self.openHelper(helper, token: token, mayRecover: true)
        }
    }

    private func recoverStoppedHelper(_ helper: URL) -> Bool {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,uid=,state=,comm="]
        let output = Pipe()
        ps.standardOutput = output
        ps.standardError = FileHandle.nullDevice
        do { try ps.run() } catch { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard ps.terminationStatus == 0 else { return false }
        let executable = helper.appendingPathComponent("Contents/MacOS/applet").path
        let candidates = stoppedHelperPIDs(String(decoding: data, as: UTF8.self), executable: executable, uid: getuid())
        var recovered = false
        for pid in candidates {
            // Re-read immediately before signalling, reducing PID reuse risk.
            let check = Process()
            check.executableURL = URL(fileURLWithPath: "/bin/ps")
            check.arguments = ["-p", String(pid), "-o", "pid=,uid=,state=,comm="]
            let fresh = Pipe()
            check.standardOutput = fresh
            check.standardError = FileHandle.nullDevice
            do { try check.run() } catch { continue }
            let current = fresh.fileHandleForReading.readDataToEndOfFile()
            check.waitUntilExit()
            guard check.terminationStatus == 0,
                  stoppedHelperPIDs(String(decoding: current, as: UTF8.self), executable: executable, uid: getuid()).contains(pid) else { continue }
            if kill(pid, SIGKILL) == 0 { recovered = true }
        }
        return recovered
    }

    private func openHelper(_ helper: URL, token: UUID, mayRecover: Bool) {
        NSWorkspace.shared.openApplication(at: helper, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async {
                guard self.launchToken == token else { return }
                if let error = error {
                    // Retry only after removing a confirmed stopped process, never blindly
                    // retry a successful launch: that could toggle recording twice.
                    if mayRecover && self.recoverStoppedHelper(helper) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self.openHelper(helper, token: token, mayRecover: false)
                        }
                        return
                    }
                    self.launchToken = nil
                    let alert = NSAlert()
                    alert.messageText = "无法打开 ChatGPT 听写助手"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                } else {
                    self.launchToken = nil
                }
            }
        }
    }

    private func writeStatus(_ status: String) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("MicPause")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("global-hotkey-status.txt")
        try? "\(Date()): \(status)\n".write(to: path, atomically: true, encoding: .utf8)
    }

    func applicationWillTerminate(_ notification: Notification) {
        writeStatus("stopped")
        if let hotkey = hotkey { UnregisterEventHotKey(hotkey) }
        if let handler = handler { RemoveEventHandler(handler) }
    }
}

if CommandLine.arguments.contains("--self-test") {
    let path = "/test/ChatGPT 听写助手.app/Contents/MacOS/applet"
    precondition(stoppedHelperPIDs("100 501 T \(path)", executable: path, uid: 501) == [100])
    precondition(stoppedHelperPIDs("100 501 S \(path)", executable: path, uid: 501).isEmpty)
    precondition(stoppedHelperPIDs("100 502 T \(path)", executable: path, uid: 501).isEmpty)
    precondition(stoppedHelperPIDs("100 501 T /other/applet", executable: path, uid: 501).isEmpty)
    precondition(stoppedHelperPIDs("bad data", executable: path, uid: 501).isEmpty)
    print("PASS: stopped helper recovery guards (state, path, owner, malformed data)")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = HotkeyApp()
app.delegate = delegate
app.run()
