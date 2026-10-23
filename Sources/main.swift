import AppKit
import ApplicationServices
import ServiceManagement

// Menu bar app that installs one keyboard event tap and drops key chatter.
// Nothing runs between keystrokes: no timers, no polling (except while
// waiting for the Accessibility permission on first launch).

private let thresholds = [20, 30, 40, 50, 60, 80, 100]
private let defaults = UserDefaults.standard

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var debouncer = Debouncer(thresholdMs: 40)
    private var tap: CFMachPort?
    private var permissionTimer: Timer?
    private var toNs: (UInt64) -> UInt64 = { $0 }
    private var clockChecked = false

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let countItem = NSMenuItem()
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let thresholdMenu = NSMenu()

    private var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    private var thresholdMs: Int {
        get { defaults.object(forKey: "thresholdMs") as? Int ?? 40 }
        set { defaults.set(newValue, forKey: "thresholdMs") }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        debouncer.thresholdNs = UInt64(thresholdMs) * 1_000_000
        buildMenu()

        // Register as a login item once; after that the menu toggle owns it.
        if !defaults.bool(forKey: "loginRegistered") {
            try? SMAppService.mainApp.register()
            defaults.set(true, forKey: "loginRegistered")
        }

        if AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
            installTap()
        } else {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard AXIsProcessTrusted() else { return }
                t.invalidate()
                self?.installTap()
            }
        }
        updateIcon()
    }

    // MARK: Event tap

    private func installTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, ctx in
                let me = Unmanaged<AppDelegate>.fromOpaque(ctx!).takeUnretainedValue()
                return me.handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: enabled)
        updateIcon()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap, enabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .keyDown, .keyUp:
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return pass }
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let t = timestamp(event)
            let keep = type == .keyDown ? debouncer.keyDown(code, at: t) : debouncer.keyUp(code, at: t)
            return keep ? pass : nil
        default:
            return pass
        }
    }

    /// Event time in nanoseconds. Depending on the Mac, CGEvent timestamps are
    /// either nanoseconds or mach ticks, so the unit is detected on first use.
    private func timestamp(_ event: CGEvent) -> UInt64 {
        let ts = event.timestamp
        guard ts != 0 else { return clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }
        if !clockChecked {
            clockChecked = true
            let ticks = mach_absolute_time()
            let ns = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
            let dTicks = ts > ticks ? ts - ticks : ticks - ts
            let dNs = ts > ns ? ts - ns : ns - ts
            if dTicks < dNs {
                var tb = mach_timebase_info_data_t()
                mach_timebase_info(&tb)
                let (n, d) = (UInt64(tb.numer), UInt64(tb.denom))
                toNs = { $0 / d * n + $0 % d * n / d }
            }
        }
        return toNs(ts)
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())

        enabledItem.target = self
        menu.addItem(enabledItem)

        for ms in thresholds {
            let item = NSMenuItem(title: "\(ms) ms", action: #selector(pickThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.tag = ms
            thresholdMenu.addItem(item)
        }
        let thresholdItem = NSMenuItem(title: "Threshold", action: nil, keyEquivalent: "")
        thresholdItem.submenu = thresholdMenu
        menu.addItem(thresholdItem)

        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DoubleKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if tap == nil {
            countItem.title = "Waiting for Accessibility permission…"
        } else {
            let n = debouncer.blocked
            countItem.title = "Blocked \(n) double press\(n == 1 ? "" : "es")"
        }
        enabledItem.state = enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        for item in thresholdMenu.items { item.state = item.tag == thresholdMs ? .on : .off }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        if let tap { CGEvent.tapEnable(tap: tap, enable: enabled) }
        updateIcon()
    }

    @objc private func pickThreshold(_ sender: NSMenuItem) {
        thresholdMs = sender.tag
        debouncer.thresholdNs = UInt64(sender.tag) * 1_000_000
    }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        if svc.status == .enabled { try? svc.unregister() } else { try? svc.register() }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "DoubleKey")
        img?.isTemplate = true
        button.image = img
        button.appearsDisabled = !enabled || tap == nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
