import Cocoa

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isActive = false
    var timer: Timer?
    var lastApprovedHash = ""
    var approveCount = 0
    var toggleMenuItem: NSMenuItem!
    var countMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚡ OFF"
            button.action = #selector(toggleFromClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

    @objc func toggleFromClick() {
        toggleAutoApprove()
    }

    @objc func toggleAutoApprove() {
        isActive.toggle()

        if isActive {
            statusItem.button?.title = "⚡ ON"
            toggleMenuItem.title = "Disable Auto-Approve"
            startMonitoring()
            showNotification(title: "Claude Auto-Approve", body: "Auto-approve ENABLED — Claude can work freely")
        } else {
            statusItem.button?.title = "⚡ OFF"
            toggleMenuItem.title = "Enable Auto-Approve"
            stopMonitoring()
            showNotification(title: "Claude Auto-Approve", body: "Auto-approve DISABLED — Approved \(approveCount) prompts this session")
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkAndApprove()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkAndApprove() {
        guard isActive else { return }

        // Check both Terminal.app and iTerm2
        if let content = getTerminalContent(app: "Terminal") {
            processContent(content, app: "Terminal")
        }
        if let content = getTerminalContent(app: "iTerm") {
            processContent(content, app: "iTerm")
        }
    }

    func getTerminalContent(app: String) -> String? {
        let script: String
        if app == "Terminal" {
            script = """
            tell application "System Events"
                if not (exists process "Terminal") then return ""
            end tell
            tell application "Terminal"
                if (count of windows) = 0 then return ""
                set t to contents of selected tab of front window
                if length of t > 600 then
                    set t to text ((length of t) - 600) thru -1 of t
                end if
                return t
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                if not (exists process "iTerm2") then return ""
            end tell
            tell application "iTerm2"
                if (count of windows) = 0 then return ""
                tell current session of current tab of current window
                    set t to text
                    if length of t > 600 then
                        set t to text ((length of t) - 600) thru -1 of t
                    end if
                    return t
                end tell
            end tell
            """
        }

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

    func processContent(_ content: String, app: String) {
        guard !content.isEmpty else { return }

        // Hash the last 200 chars to detect new prompts
        let tail = String(content.suffix(200))
        let hash = tail.hashValue.description

        // Skip if we already approved this exact content
        if hash == lastApprovedHash { return }

        // Detect Claude Code permission prompts
        // Claude shows tool use blocks ending with approval prompts
        let permissionPatterns = [
            "Allow once",           // Claude Code "Allow once" button text
            "Allow always",         // Claude Code "Allow always" option
            "(Y)es",               // Yes/No prompt pattern
            "Do you want to allow",
            "Allow tool",
            "Press y to allow",
            "approve this action",
        ]

        let hasPrompt = permissionPatterns.contains { pattern in
            content.range(of: pattern, options: .caseInsensitive) != nil
        }

        if hasPrompt {
            sendApproval(app: app)
            lastApprovedHash = hash
            approveCount += 1
            countMenuItem.title = "Approved: \(approveCount)"
        }
    }

    func sendApproval(app: String) {
        let script = """
        tell application "\(app == "iTerm" ? "iTerm2" : app)"
            activate
        end tell
        delay 0.15
        tell application "System Events"
            keystroke "y"
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

    func showNotification(title: String, body: String) {
        let script = """
        display notification "\(body)" with title "\(title)"
        """
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
app.setActivationPolicy(.accessory)  // No dock icon, menu bar only
let delegate = AppDelegate()
app.delegate = delegate
app.run()
