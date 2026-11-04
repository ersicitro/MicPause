-- ChatGPT / Codex 桌面客户端：使用应用自己提供的聚焦和单击听写快捷键。
-- 全局启动：Command + Shift + D
-- 聚焦输入框：Control + Option + Shift + F
-- 切换听写：Control + Option + Shift + D
on run
    try
        set targetInfo to my locateClient()
        set targetPath to item 1 of targetInfo
        set targetName to item 2 of targetInfo
        tell application targetPath to activate
        tell application "System Events"
            tell application process targetName
                repeat 30 times
                    if frontmost and (count of windows) > 0 then exit repeat
                    delay 0.1
                end repeat
                if not frontmost or (count of windows) = 0 then error "请先打开一个 ChatGPT / Codex 聊天窗口。"
            end tell
            keystroke "f" using {control down, option down, shift down}
            delay 0.25
            if not (frontmost of application process targetName) then error "前台应用已变化，取消听写。"
            keystroke "d" using {control down, option down, shift down}
        end tell
    on error errorMessage
        display dialog "听写快捷操作未完成：" & return & errorMessage & return & return & "请给“ChatGPT 听写助手”开启设备控制权限，并确认已设置聚焦和单击听写快捷键。" buttons {"好"} default button "好" with title "ChatGPT 听写"
    end try
end run

on locateClient()
    set userApps to POSIX path of (path to applications folder from user domain)
    repeat with clientName in {"ChatGPT", "Codex"}
        repeat with basePath in {"/Applications/", userApps}
            set candidate to (contents of basePath) & (contents of clientName) & ".app"
            try
                set existingApp to POSIX file candidate as alias
                return {POSIX path of existingApp, contents of clientName}
            end try
        end repeat
    end repeat
    error "没有找到 ChatGPT.app 或 Codex.app。请先将桌面客户端安装到系统或自己的“应用程序”文件夹。"
end locateClient
