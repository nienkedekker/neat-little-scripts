import AppKit
import ServiceManagement

// menu bar clock showing the mac's local time next to Amsterdam time

let remote = TimeZone(identifier: "Europe/Amsterdam")!
let remoteFlag = "🇳🇱"

// regional indicator letters render as a flag, e.g. "ID" → 🇮🇩
func flag(_ country: String) -> String {
    let scalars = country.uppercased().unicodeScalars.compactMap { UnicodeScalar(0x1F1E6 + $0.value - 65) }
    return String(String.UnicodeScalarView(scalars))
}

// zone.tab maps tz names to countries, so the local flag follows the mac's time zone
func countryCode(for zone: TimeZone) -> String? {
    guard let tab = try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8) else { return nil }
    for line in tab.split(separator: "\n") where !line.hasPrefix("#") {
        let cols = line.split(separator: "\t")
        if cols.count >= 3, cols[2] == zone.identifier { return String(cols[0]) }
    }
    return nil
}

func city(_ zone: TimeZone) -> String {
    (zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier)
        .replacingOccurrences(of: "_", with: " ")
}

func format(_ date: Date, in zone: TimeZone, _ pattern: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_GB")
    f.timeZone = zone
    f.dateFormat = pattern
    return f.string(from: date)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private var timer: Timer?
    private var localFlag = "🏠"
    private let localLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let remoteLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let offsetLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = buildMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(zoneChanged),
                                               name: .NSSystemTimeZoneDidChange, object: nil)
        // timers stall during sleep, so catch up straight away on wake
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(tick),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        zoneChanged()
    }

    @objc private func zoneChanged() {
        NSTimeZone.resetSystemTimeZone()
        localFlag = countryCode(for: .current).map(flag) ?? "🏠"
        tick()
    }

    // fires on the minute and reschedules itself, so the clock never drifts
    @objc private func tick() {
        refresh()
        timer?.invalidate()
        let next = (Date().timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60
        let t = Timer(fire: Date(timeIntervalSinceReferenceDate: next), interval: 0, repeats: false) { [weak self] _ in
            self?.tick()
        }
        // common mode keeps it ticking while the menu is open
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        for line in [localLine, remoteLine, offsetLine] {
            line.isEnabled = false
            menu.addItem(line)
        }
        menu.addItem(.separator())

        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem(title: "Quit WorldClock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func refresh() {
        let now = Date()
        let local = TimeZone.current
        let title = "\(localFlag) \(format(now, in: local, "HH:mm"))  \(remoteFlag) \(format(now, in: remote, "HH:mm"))"
        // monospaced digits stop the menu bar shifting as the minutes change
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        item.button?.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])

        localLine.title = "\(localFlag) \(city(local)): \(format(now, in: local, "EEE d MMM, HH:mm"))"
        remoteLine.title = "\(remoteFlag) Amsterdam: \(format(now, in: remote, "EEE d MMM, HH:mm"))"

        let diff = remote.secondsFromGMT(for: now) - local.secondsFromGMT(for: now)
        let hours = Double(abs(diff)) / 3600
        let unit = hours == 1 ? "hour" : "hours"
        offsetLine.title = diff == 0
            ? "Same time as Amsterdam"
            : "Amsterdam is \(String(format: "%g", hours)) \(unit) \(diff < 0 ? "behind" : "ahead")"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        loginItem.state = loginEnabled ? .on : .off
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
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
