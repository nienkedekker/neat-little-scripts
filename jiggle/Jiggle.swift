import AppKit
import CoreGraphics
import IOKit.pwr_mgt
import ServiceManagement

// menu bar app that nudges the cursor 1px and back on a timer so macOS never
// sees you as idle. also holds a power assertion so the display stays awake.

let nudgeInterval: TimeInterval = 30

enum Duration: Int, CaseIterable {
    case fifteen = 15, thirty = 30, hour = 60, twoHours = 120, forever = 0

    var label: String {
        switch self {
        case .fifteen: return "15 minutes"
        case .thirty: return "30 minutes"
        case .hour: return "1 hour"
        case .twoHours: return "2 hours"
        case .forever: return "Until I stop it"
        }
    }
}

final class Jiggler {
    private var timer: Timer?
    private var endsAt: Date?
    private var assertion: IOPMAssertionID = 0
    private var lastSeen: CGPoint = .zero

    var isRunning: Bool { timer != nil }

    var remaining: TimeInterval? {
        guard let endsAt else { return nil }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    var onChange: (() -> Void)?

    func start(_ duration: Duration) {
        stop()
        endsAt = duration == .forever ? nil : Date().addingTimeInterval(Double(duration.rawValue) * 60)
        lastSeen = cursor()
        holdDisplayAwake()
        timer = Timer.scheduledTimer(withTimeInterval: nudgeInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        UserDefaults.standard.set(true, forKey: "running")
        onChange?()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endsAt = nil
        releaseDisplay()
        UserDefaults.standard.set(false, forKey: "running")
        onChange?()
    }

    func toggle(_ duration: Duration) {
        isRunning ? stop() : start(duration)
    }

    private func tick() {
        if let endsAt, Date() >= endsAt {
            stop()
            return
        }
        let now = cursor()
        // you're using the mouse yourself, no need to fake it
        if now != lastSeen {
            lastSeen = now
            onChange?()
            return
        }
        move(to: CGPoint(x: now.x + 1, y: now.y))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            move(to: now)
            tapRightShift()
            self?.lastSeen = cursor()
        }
        onChange?()
    }

    private func holdDisplayAwake() {
        guard assertion == 0 else { return }
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Jiggle is keeping you available" as CFString,
            &assertion
        )
    }

    private func releaseDisplay() {
        guard assertion != 0 else { return }
        IOPMAssertionRelease(assertion)
        assertion = 0
    }
}

let eventSource = CGEventSource(stateID: .hidSystemState)

func cursor() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

func move(to p: CGPoint) {
    CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

// right shift: counts as keyboard activity, types nothing. some apps track only
// keys and clicks, and ignore mouse movement entirely.
func tapRightShift() {
    let rightShift: CGKeyCode = 60
    for down in [true, false] {
        CGEvent(keyboardEventSource: eventSource, virtualKey: rightShift, keyDown: down)?
            .post(tap: .cghidEventTap)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let jiggler = Jiggler()
    private let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var defaultDuration: Duration = {
        Duration(rawValue: UserDefaults.standard.integer(forKey: "duration")) ?? .forever
    }()

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = buildMenu()
        jiggler.onChange = { [weak self] in self?.refresh() }
        // pick up where we left off, so a restart or rebuild doesn't leave you idle
        if UserDefaults.standard.bool(forKey: "running") {
            jiggler.start(defaultDuration)
        }
        refresh()
        requestAccessibilityIfNeeded()
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host ?? url.path.replacingOccurrences(of: "/", with: "") {
            case "on": jiggler.start(defaultDuration)
            case "off": jiggler.stop()
            case "toggle": jiggler.toggle(defaultDuration)
            default: break
            }
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Start", action: #selector(toggleJiggle), keyEquivalent: "j")
        toggle.target = self
        toggle.tag = 1
        menu.addItem(toggle)

        let durations = NSMenu()
        for d in Duration.allCases {
            let mi = NSMenuItem(title: d.label, action: #selector(pickDuration(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = d.rawValue
            durations.addItem(mi)
        }
        let durationItem = NSMenuItem(title: "Run for", action: nil, keyEquivalent: "")
        durationItem.submenu = durations
        menu.addItem(durationItem)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.tag = 2
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit Jiggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func refresh() {
        let on = jiggler.isRunning
        item.button?.image = icon(on ? "JiggleActiveTemplate" : "JiggleTemplate",
                                  describedAs: on ? "Jiggling" : "Idle")

        if on, let left = jiggler.remaining {
            let mins = Int(left / 60) + 1
            status.title = "Jiggling — \(mins) min left"
        } else {
            status.title = on ? "Jiggling" : "Not jiggling"
        }

        item.menu?.item(withTag: 1)?.title = on ? "Stop" : "Start"
        item.menu?.item(withTag: 2)?.state = loginEnabled ? .on : .off
        for mi in item.menu?.item(withTitle: "Run for")?.submenu?.items ?? [] {
            mi.state = (mi.representedObject as? Int) == defaultDuration.rawValue ? .on : .off
        }
    }

    // template images are recolored by the menu bar, so the asset is pure black
    private func icon(_ name: String, describedAs description: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = description
        return image
    }

    @objc private func toggleJiggle() {
        jiggler.toggle(defaultDuration)
    }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int, let d = Duration(rawValue: raw) else { return }
        defaultDuration = d
        UserDefaults.standard.set(raw, forKey: "duration")
        if jiggler.isRunning { jiggler.start(d) }
        refresh()
    }

    private var loginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLogin() {
        do {
            loginEnabled ? try SMAppService.mainApp.unregister() : try SMAppService.mainApp.register()
        } catch {
            NSLog("login item failed: \(error)")
        }
        refresh()
    }

    private func requestAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
