import Cocoa

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isActive = false
    var timer: Timer?
    var approvedHashes = Set<String>()
    var approveCount = 0
    var toggleMenuItem: NSMenuItem!
    var countMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚡ OFF"
        }

        let menu = NSMenu()
        toggleMenuItem = NSMenuItem(title: "Enable Auto-Approve", action: #selector(toggleAutoApprove), keyEquivalent: "a")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        countMenuItem = NSMenuItem(title: "Approved: 0", action: nil, keyEquivalent: "")
        countMenuItem.isEnabled = false
        menu.addItem(countMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleAutoApprove() {
        isActive.toggle()
        approvedHashes.removeAll()

        if isActive {
            statusItem.button?.title = "⚡ ON"
            toggleMenuItem.title = "Disable Auto-Approve"
            startMonitoring()
            showNotification(title: "Claude Auto-Approve", body: "Auto-approve ENABLED")
        } else {
            statusItem.button?.title = "⚡ OFF"
            toggleMenuItem.title = "Enable Auto-Approve"
            stopMonitoring()
            showNotification(title: "Claude Auto-Approve", body: "Auto-approve DISABLED — \(approveCount) approved")
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.checkAndApprove()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkAndApprove() {
        guard isActive else { return }

        // Scan ALL windows and tabs in Terminal.app
        let terminalScript = """
        set results to ""
        tell application "System Events"
            if not (exists process "Terminal") then return ""
        end tell
        tell application "Terminal"
            repeat with w in windows
                set winIdx to index of w
                repeat with t in tabs of w
                    set tabIdx to 0
                    try
                        set tabContents to contents of t
                        set contentLen to length of tabContents
                        if contentLen > 1000 then
                            set tabContents to text ((contentLen) - 1000) thru -1 of tabContents
                        end if
                        set results to results & "<<<TAB:" & winIdx & ">>>" & tabContents
                    end try
                end repeat
            end repeat
        end tell
        return results
        """

        if let allContent = runAppleScript(terminalScript), !allContent.isEmpty {
            // Split by tab markers and process each
            let tabs = allContent.components(separatedBy: "<<<TAB:")
            for tab in tabs {
                guard !tab.isEmpty else { continue }
                // Extract window index from "N>>>content"
                let parts = tab.components(separatedBy: ">>>")
                guard parts.count >= 2 else { continue }
                let winIdx = parts[0]
                let content = parts.dropFirst().joined(separator: ">>>")
                processTab(content: content, app: "Terminal", windowIndex: winIdx)
            }
        }

        // Also check iTerm2
        let itermScript = """
        tell application "System Events"
            if not (exists process "iTerm2") then return ""
        end tell
        tell application "iTerm2"
            set results to ""
            repeat with w in windows
                set winIdx to index of w
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            set sText to text of s
                            set contentLen to length of sText
                            if contentLen > 1000 then
                                set sText to text ((contentLen) - 1000) thru -1 of sText
                            end if
                            set results to results & "<<<TAB:" & winIdx & ">>>" & sText
                        end try
                    end repeat
                end repeat
            end repeat
            return results
        end tell
        """

        if let allContent = runAppleScript(itermScript), !allContent.isEmpty {
            let tabs = allContent.components(separatedBy: "<<<TAB:")
            for tab in tabs {
                guard !tab.isEmpty else { continue }
                let parts = tab.components(separatedBy: ">>>")
                guard parts.count >= 2 else { continue }
                let winIdx = parts[0]
                let content = parts.dropFirst().joined(separator: ">>>")
                processTab(content: content, app: "iTerm2", windowIndex: winIdx)
            }
        }
    }

    func processTab(content: String, app: String, windowIndex: String) {
        guard !content.isEmpty else { return }

        // Only look at the LAST 400 chars (the active prompt area)
        let tail = String(content.suffix(400))

        // Create a hash to avoid re-approving the same prompt
        let hash = "\(app)-\(windowIndex)-\(tail.hashValue)"
        if approvedHashes.contains(hash) { return }

        // Detect Claude Code permission prompts
        // Claude Code shows various prompt patterns when waiting for approval:
        let hasPrompt = detectClaudePrompt(in: tail)

        if hasPrompt {
            sendApproval(app: app, windowIndex: windowIndex)
            approvedHashes.insert(hash)

            // Keep hash set from growing forever (max 200)
            if approvedHashes.count > 200 {
                approvedHashes.removeFirst()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.approveCount += 1
                self.countMenuItem.title = "Approved: \(self.approveCount)"
            }
        }
    }

    func detectClaudePrompt(in text: String) -> Bool {
        // Claude Code permission prompt patterns
        // The terminal shows tool use blocks and waits for user input
        let patterns: [(String, Bool)] = [
            // Claude Code CLI prompt patterns
            ("Allow once", false),
            ("Allow always", false),
            ("allow this action", true),
            ("Do you want to proceed", true),
            ("Allow tool", true),
            ("approve this", true),
            // Claude Code shows "Yes" / "No" choices
            ("(Y)es", false),
            // Bash tool permission prompt
            ("Run command", true),
            // Edit/Write permission
            ("Write to", true),
            // The actual prompt waiting patterns at end of output
            ("Allow?", false),
            ("allow?", false),
            ("(y/N)", false),
            ("(Y/n)", false),
            ("[Y/n]", false),
            ("[y/N]", false),
            // Claude sometimes shows these
            ("Press Enter to allow", true),
            ("enter to continue", true),
        ]

        for (pattern, caseInsensitive) in patterns {
            if caseInsensitive {
                if text.range(of: pattern, options: .caseInsensitive) != nil {
                    return true
                }
            } else {
                if text.contains(pattern) {
                    return true
                }
            }
        }

        return false
    }

    func sendApproval(app: String, windowIndex: String) {
        // Focus the specific window and send 'y' keystroke
        let script = """
        tell application "\(app)"
            set index of window \(windowIndex) to 1
            activate
        end tell
        delay 0.15
        tell application "System Events"
            keystroke "y"
            delay 0.1
            keystroke return
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {}
    }

    func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    func showNotification(title: String, body: String) {
        let script = "display notification \"\(body)\" with title \"\(title)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

// MARK: - Main
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
