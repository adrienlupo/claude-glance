import AppKit

enum ITerm {
    private static let bundleID = "com.googlecode.iterm2"

    static func focusSession(tty: String) {
        guard tty.isValidTTY else { return }
        guard NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        ).first != nil else { return }

        let devicePath = "/dev/\(tty)"
        let source = """
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
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }
}
