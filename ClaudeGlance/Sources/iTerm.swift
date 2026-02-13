import AppKit

enum ITerm {
    private static let bundleID = "com.googlecode.iterm2"

    static func focusSession(tty: String) {
        guard tty.isValidTTY else { return }
        guard NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first != nil else { return }

        let devicePath = "/dev/\(tty)"
        let script = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(devicePath)" then
                                select t
                            end if
                        end repeat
                    end repeat
                end repeat
                activate
            end tell
            """
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}
