import AppKit
import AVFoundation
import CoreGraphics

final class VideoView: NSView {
    let videoLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        videoLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(videoLayer)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        videoLayer.frame = bounds
    }
}

final class OverlayPanel: NSPanel {
    var skip: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { skip?() }
        else { super.keyDown(with: event) }
    }
}

struct TargetWindow {
    let id: CGWindowID
    let bounds: CGRect

    static func find(pid: pid_t, id: CGWindowID? = nil) -> TargetWindow? {
        let options: CGWindowListOption = id == nil ? [.optionOnScreenOnly, .excludeDesktopElements] : .optionIncludingWindow
        let rows = CGWindowListCopyWindowInfo(options, id ?? kCGNullWindowID) as? [[String: Any]] ?? []
        for row in rows {
            guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (row[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  (row[kCGWindowIsOnscreen as String] as? Bool) == true,
                  let number = row[kCGWindowNumber as String] as? NSNumber,
                  let dictionary = row[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  bounds.width >= 300, bounds.height >= 240 else { continue }
            return TargetWindow(id: number.uint32Value, bounds: bounds)
        }
        return nil
    }

    @MainActor var contentFrame: NSRect {
        // CG uses the primary screen's top-left; AppKit uses its bottom-left.
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: bounds.minX, y: primaryTop - bounds.maxY,
                      width: bounds.width, height: bounds.height - 32)
    }
}

@MainActor
final class StartupOverlay: NSObject, NSApplicationDelegate {
    private let workspace = NSWorkspace.shared
    private var processed = Set<pid_t>()
    private var observers: [NSObjectProtocol] = []
    private var target: NSRunningApplication?
    private var targetWindowID: CGWindowID?
    private var panel: OverlayPanel?
    private var player: AVPlayer?
    private var observations: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var tracking: Timer?
    private var deadline = Date.distantPast
    private let once = CommandLine.arguments.contains("--once")
    private let beganAt = Date()

    private func argument(_ flag: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for app in workspace.runningApplications where matches(app) { processed.insert(app.processIdentifier) }
        observe(NSWorkspace.didLaunchApplicationNotification) { [weak self] app in self?.begin(app) }
        observe(NSWorkspace.didActivateApplicationNotification) { [weak self] app in
            guard let self else { return }
            if self.panel?.isVisible == true, self.target?.processIdentifier != app.processIdentifier {
                self.log("FOCUS_LEFT for=\(app.bundleIdentifier ?? "unknown")")
                self.finish("focus-changed")
            }
            self.begin(app)
        }
        observe(NSWorkspace.didTerminateApplicationNotification) { [weak self] app in
            guard let self else { return }
            self.processed.remove(app.processIdentifier)
            if self.target?.processIdentifier == app.processIdentifier { self.finish("target-closed") }
        }
        if let value = argument("--preview"), let pid = Int32(value), let app = NSRunningApplication(processIdentifier: pid) {
            processed.remove(pid)
            begin(app, preview: true)
        }
        log("WATCHING ChatGPT/Codex")
    }

    private func observe(_ name: Notification.Name, action: @escaping (NSRunningApplication) -> Void) {
        observers.append(workspace.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { action(app) }
        })
    }

    private func matches(_ app: NSRunningApplication) -> Bool {
        if ["com.openai.codex", "com.openai.chat"].contains(app.bundleIdentifier ?? "") { return true }
        if let override = ProcessInfo.processInfo.environment["CODEX_APP_PATH"] {
            return app.bundleURL?.standardizedFileURL == URL(fileURLWithPath: override).standardizedFileURL
        }
        return false
    }

    private func begin(_ app: NSRunningApplication, preview: Bool = false) {
        guard (preview || matches(app)), !processed.contains(app.processIdentifier) else { return }
        if target != nil { finish("new-target") }
        processed.insert(app.processIdentifier)
        target = app
        deadline = Date().addingTimeInterval(30)
        log("TARGET pid=\(app.processIdentifier) bundle=\(app.bundleIdentifier ?? "unknown") path=\(app.bundleURL?.path ?? "unknown")")
        tracking = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        update()
    }

    private func update() {
        guard let target else { return }
        guard !target.isTerminated else { finish("target-closed"); return }
        if panel?.isVisible != true, Date() > deadline { finish("no-visible-window-or-video"); return }
        guard target.isActive else { return }
        guard let info = TargetWindow.find(pid: target.processIdentifier, id: targetWindowID) else {
            if panel != nil { finish("window-hidden") }
            return
        }
        if panel == nil { prepare(info) }
        let frame = info.contentFrame
        if panel?.frame != frame {
            panel?.setFrame(frame, display: true)
            log("OVERLAY_FRAME window=\(info.id) x=\(frame.minX) y=\(frame.minY) width=\(frame.width) height=\(frame.height)")
        }
        if panel?.isVisible == true, panel?.isKeyWindow == false { panel?.makeKey() }
    }

    private func prepare(_ info: TargetWindow) {
        let explicit = argument("--video").map { URL(fileURLWithPath: $0) }
        guard let video = explicit ?? Bundle.main.url(forResource: "startup", withExtension: "mp4") else {
            finish("video-missing"); return
        }
        targetWindowID = info.id
        let frame = info.contentFrame
        let view = VideoView(frame: NSRect(origin: .zero, size: frame.size))
        let window = OverlayPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel = window
        window.skip = { [weak self] in self?.finish("escape-skip") }

        let item = AVPlayerItem(url: video)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        self.player = player
        view.videoLayer.player = player
        observations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed { DispatchQueue.main.async { self?.finish("video-error") } }
        })
        observations.append(view.videoLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self, weak window] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                guard let self, let window, self.panel === window, self.target?.isActive == true else { return }
                window.makeKeyAndOrderFront(nil)
                self.log("VIDEO_VISIBLE pid=\(self.target?.processIdentifier ?? 0) window=\(info.id) frame=\(window.frame)")
            }
        })
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish("video-ended") }
        }
        player.play()
    }

    private func finish(_ reason: String) {
        guard target != nil else { return }
        log("ENDED \(reason)")
        tracking?.invalidate()
        tracking = nil
        player?.pause()
        player = nil
        observations.removeAll()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        let oldPanel = panel
        panel = nil
        target = nil
        targetWindowID = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reason == "video-ended" || reason == "escape-skip" ? 0.25 : 0
            oldPanel?.animator().alphaValue = 0
        }, completionHandler: {
            oldPanel?.close()
            if self.once { NSApp.terminate(nil) }
        })
    }

    private func log(_ message: String) {
        print(String(format: "%.3f", Date().timeIntervalSince(beganAt)) + " " + message)
        fflush(stdout)
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracking?.invalidate()
        player?.pause()
        for observer in observers { workspace.notificationCenter.removeObserver(observer) }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = StartupOverlay()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
