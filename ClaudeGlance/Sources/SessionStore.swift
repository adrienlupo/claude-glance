import AppKit
import Foundation
import Observation
import os

struct SessionInfo: Identifiable {
    let id: String
    let cwd: String
    var status: SessionStatus
    let timestamp: Date
    let pid: Int32
    let tty: String
    var contextPercentage: Int?

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }
}

struct StatusCount: Identifiable {
    let status: SessionStatus
    let count: Int
    var id: String { status.rawValue }
}

@MainActor
@Observable
final class SessionStore {
    private static let logger = Logger(subsystem: "claude-glance", category: "sessions")
    private static let sessionExpiryInterval: TimeInterval = 1800
    private static let debounceDelay: TimeInterval = 0.2
    private static let healthCheckInterval: DispatchTimeInterval = .milliseconds(500)

    var sessions: [SessionInfo] = []

    private let sessionsDirectory: URL
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var processMonitors: [String: DispatchSourceProcess] = [:]
    private var healthCheckTimer: DispatchSourceTimer?
    private var debounceWork: DispatchWorkItem?
    private var wakeObserver: NSObjectProtocol?

    var countsByStatus: [StatusCount] {
        let counts = Dictionary(grouping: sessions, by: { $0.status })
        return [SessionStatus.busy, .waiting, .idle].compactMap { status in
            guard let count = counts[status]?.count, count > 0 else { return nil }
            return StatusCount(status: status, count: count)
        }
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        sessionsDirectory = home.appendingPathComponent(".claude-glance/sessions")
        try? FileManager.default.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true
        )
        loadSessions()
        startWatching()
        startHealthCheck()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadSessions() }
        }
    }

    deinit {
        // Safe: singleton held by AppDelegate, always deallocated on main thread at app termination
        MainActor.assumeIsolated {
            dispatchSource?.cancel()
            healthCheckTimer?.cancel()
            debounceWork?.cancel()
            processMonitors.values.forEach { $0.cancel() }
            if let observer = wakeObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
        }
    }

    private func isSessionAlive(_ json: [String: Any]) -> Bool {
        guard let pid = json["pid"] as? Int, pid > 0 else {
            return false
        }
        let result = Darwin.kill(Int32(pid), 0)
        guard result == 0 || (result == -1 && errno == EPERM) else {
            return false
        }
        if let tty = json["tty"] as? String, tty.isValidTTY {
            return Darwin.access("/dev/\(tty)", F_OK) == 0
        }
        return true
    }

    private func loadSessions() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            Self.logger.error("Failed to list sessions directory: \(self.sessionsDirectory.path, privacy: .public)")
            return
        }

        let now = Date()
        var loaded: [SessionInfo] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cwd = json["cwd"] as? String,
                  let statusStr = json["status"] as? String,
                  let ts = json["ts"] as? TimeInterval else {
                Self.logger.warning("Malformed session file: \(file.lastPathComponent, privacy: .public)")
                continue
            }

            let sessionId = file.deletingPathExtension().lastPathComponent
            let timestamp = Date(timeIntervalSince1970: ts)
            let age = now.timeIntervalSince(timestamp)

            let ctxFile = sessionsDirectory.appendingPathComponent("\(sessionId).ctx")

            if age > Self.sessionExpiryInterval {
                try? FileManager.default.removeItem(at: file)
                try? FileManager.default.removeItem(at: ctxFile)
                continue
            }

            if !isSessionAlive(json) {
                try? FileManager.default.removeItem(at: file)
                try? FileManager.default.removeItem(at: ctxFile)
                continue
            }

            guard let status = SessionStatus(rawValue: statusStr) else { continue }
            let pid = Int32(json["pid"] as? Int ?? 0)
            let tty = json["tty"] as? String ?? ""
            let contextPct = (try? String(contentsOf: ctxFile, encoding: .utf8))
                .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

            let session = SessionInfo(
                id: sessionId,
                cwd: cwd,
                status: status,
                timestamp: timestamp,
                pid: pid,
                tty: tty,
                contextPercentage: contextPct
            )
            loaded.append(session)
            monitorProcess(session)
        }

        let activeIds = Set(loaded.map(\.id))
        for id in processMonitors.keys where !activeIds.contains(id) {
            processMonitors.removeValue(forKey: id)?.cancel()
        }

        sessions = loaded.sorted { $0.projectName < $1.projectName }
    }

    private func monitorProcess(_ session: SessionInfo) {
        guard session.pid > 0, processMonitors[session.id] == nil else { return }

        let source = DispatchSource.makeProcessSource(
            identifier: session.pid,
            eventMask: .exit,
            queue: .main
        )
        let sessionId = session.id
        source.setEventHandler { [weak self] in
            self?.removeSession(sessionId)
        }
        processMonitors[sessionId] = source
        source.resume()
    }

    private func removeSession(_ sessionId: String) {
        processMonitors.removeValue(forKey: sessionId)?.cancel()
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions.remove(at: index)
            let file = sessionsDirectory.appendingPathComponent("\(sessionId).json")
            let ctxFile = sessionsDirectory.appendingPathComponent("\(sessionId).ctx")
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: ctxFile)
        }
    }

    private func startWatching() {
        fileDescriptor = Darwin.open(sessionsDirectory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            Self.logger.error("Failed to open sessions directory for watching")
            return
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )

        dispatchSource?.setEventHandler { [weak self] in
            guard let self else { return }
            self.debounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.loadSessions()
            }
            self.debounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceDelay, execute: work)
        }

        dispatchSource?.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            Darwin.close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        dispatchSource?.resume()
    }

    private func startHealthCheck() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: Self.healthCheckInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            for i in (0..<self.sessions.count).reversed() {
                let s = self.sessions[i]
                let rc = s.pid > 0 ? Darwin.kill(s.pid, 0) : -1
                let alive = rc == 0 || (rc == -1 && errno == EPERM)
                if !alive {
                    self.removeSession(s.id)
                }
            }
        }
        timer.resume()
        healthCheckTimer = timer
    }

}
