import Carbon
import AppKit
import SwiftUI

struct Shortcut: Codable, Hashable {
    let keyCode: UInt16
    let modifierFlags: UInt
    let displayString: String
}

extension Array where Element == Shortcut {
    static func loadFromUserDefaults() -> [Shortcut] {
        guard let data = UserDefaults.standard.data(forKey: "recordedShortcutsJSON") else {
            // Default: ⇧ ⌘ S (Cmd + Shift + S) -> keyCode 1, modifierFlags 1179648
            let defaultShortcut = Shortcut(keyCode: 1, modifierFlags: 1179648, displayString: "⇧ ⌘ S")
            return [defaultShortcut]
        }
        do {
            return try JSONDecoder().decode([Shortcut].self, from: data)
        } catch {
            return []
        }
    }
    
    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "recordedShortcutsJSON")
        }
    }
}

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    
    var onShortcutTriggered: (() -> Void)?
    
    init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        
        let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            DispatchQueue.main.async {
                GlobalShortcutManager.shared.onShortcutTriggered?()
            }
            return noErr
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if status != noErr {
            print("Failed to install Carbon event handler: \(status)")
        }
    }
    
    func registerShortcuts(_ shortcuts: [Shortcut]) {
        unregisterAll()
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x73637368) // 'scsh'
        
        for (index, shortcut) in shortcuts.enumerated() {
            hotKeyID.id = UInt32(index + 1)
            
            var carbonModifiers: UInt32 = 0
            let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags)
            if flags.contains(.command) { carbonModifiers |= UInt32(256) }
            if flags.contains(.shift) { carbonModifiers |= UInt32(512) }
            if flags.contains(.option) { carbonModifiers |= UInt32(2048) }
            if flags.contains(.control) { carbonModifiers |= UInt32(4096) }
            
            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode),
                carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            
            if status == noErr, let ref = hotKeyRef {
                hotKeyRefs.append(ref)
            } else {
                print("Failed to register hotkey for \(shortcut.displayString): \(status)")
            }
        }
    }
    
    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
    
    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            CursorToggleManager.shared.deactivate()
        } else {
            super.keyDown(with: event)
        }
    }
}

class FlashWindow: NSWindow {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = NSColor.white
        self.hasShadow = false
        self.level = .screenSaver
        self.ignoresMouseEvents = true
    }
}

class ScreenshotStore: ObservableObject {
    static let shared = ScreenshotStore()
    
    @Published var screenshots: [URL] = []
    
    init() {
        loadScreenshots()
    }
    
    func loadScreenshots() {
        let fileManager = FileManager.default
        guard let picturesDir = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            return
        }
        let screenshotsDir = picturesDir.appendingPathComponent("Screenshooter")
        
        // Scan directory for PNG files
        if let urls = try? fileManager.contentsOfDirectory(at: screenshotsDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) {
            // Sort by creation date descending
            self.screenshots = urls
                .filter { $0.pathExtension.lowercased() == "png" }
                .sorted { (url1, url2) -> Bool in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
        }
    }
    
    func addScreenshot(_ url: URL) {
        DispatchQueue.main.async {
            self.screenshots.insert(url, at: 0)
        }
    }
}

class CursorTrackingView: NSView {
    private var trackingArea: NSTrackingArea?
    
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    
    var selectionRect: NSRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .cursorUpdate,
            .mouseMoved
        ]
        
        let newArea = NSTrackingArea(
            rect: self.bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        addTrackingArea(newArea)
        trackingArea = newArea
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        self.addCursorRect(self.bounds, cursor: NSCursor.crosshair)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            CursorToggleManager.shared.deactivate()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        defer {
            startPoint = nil
            currentPoint = nil
            needsDisplay = true
        }
        
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            // Click without drag: deactivate overlay
            CursorToggleManager.shared.deactivate()
            return
        }
        
        guard let screen = self.window?.screen else {
            CursorToggleManager.shared.deactivate()
            return
        }
        
        // Deactivate overlay window first
        CursorToggleManager.shared.deactivate()
        
        // Take screenshot of the selected rect
        CursorToggleManager.shared.captureRect(rect, on: screen)
    }
    
    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw dark background overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        guard let rect = selectionRect else { return }
        
        // Clear the selected rectangle area (make it transparent)
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSColor.clear.setFill()
        rect.fill()
        
        // Reset blend mode to draw the border
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
        
        // Draw selection border
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1.5
        path.stroke()
        
        // Draw a subtle blue dashed outer border or helper lines
        NSColor.systemBlue.setStroke()
        let dashPath = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
        dashPath.lineWidth = 1.0
        let pattern: [CGFloat] = [4, 4]
        dashPath.setLineDash(pattern, count: 2, phase: 0)
        dashPath.stroke()
    }
}

class CursorToggleManager {
    static let shared = CursorToggleManager()
    
    private var overlayWindows: [NSWindow] = []
    
    var isActive: Bool {
        return !overlayWindows.isEmpty
    }
    
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }
    
    func activate() {
        deactivate()
        
        // Activate our app and bring it to the front so cursor changes apply system-wide immediately
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01) // almost completely transparent
            window.hasShadow = false
            window.level = .statusBar
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            
            // Set the content view frame size to the screen size explicitly so bounds are not zero
            let contentView = CursorTrackingView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.contentView = contentView
            
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(contentView)
            overlayWindows.append(window)
        }
        
        // Force cursor to crosshair immediately
        NSCursor.crosshair.set()
    }
    
    func deactivate() {
        guard !overlayWindows.isEmpty else { return }
        
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        NSCursor.arrow.set()
    }
    
    func captureRect(_ rect: NSRect, on screen: NSScreen) {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return
        }
        
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screen.frame.size.height - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
        
        guard let cgImage = CGDisplayCreateImage(displayID, rect: cgRect) else {
            print("Failed to capture rect")
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        
        // Save to file
        let fileManager = FileManager.default
        guard let picturesDir = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            return
        }
        let screenshotsDir = picturesDir.appendingPathComponent("Screenshooter")
        try? fileManager.createDirectory(at: screenshotsDir, withIntermediateDirectories: true, attributes: nil)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let filename = "Screenshot_\(dateFormatter.string(from: Date())).png"
        let fileURL = screenshotsDir.appendingPathComponent(filename)
        
        if let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                ScreenshotStore.shared.addScreenshot(fileURL)
            } catch {
                print("Failed to save PNG: \(error)")
            }
        }
        
        let showFlash = UserDefaults.standard.object(forKey: "showFlashEffect") as? Bool ?? true
        if showFlash {
            triggerFlash(on: screen)
        }
    }
    
    private func triggerFlash(on screen: NSScreen) {
        DispatchQueue.main.async {
            let flashWindow = FlashWindow(frame: screen.frame)
            flashWindow.alphaValue = 0.8
            flashWindow.makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                flashWindow.animator().alphaValue = 0.0
            }, completionHandler: {
                flashWindow.orderOut(nil)
            })
        }
    }
}
