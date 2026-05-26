import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 350)
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.contentViewController = NSHostingController(rootView: ContentView())

        // Setup Menu Bar Icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screenshooter")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Setup Global Shortcut callback
        GlobalShortcutManager.shared.onShortcutTriggered = {
            CursorToggleManager.shared.toggle()
        }
        
        // Register saved shortcuts initially
        let shortcuts = [Shortcut].loadFromUserDefaults()
        GlobalShortcutManager.shared.registerShortcuts(shortcuts)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                NSApp.activate(ignoringOtherApps: true) // Bring app to foreground
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    // Triggered when the Dock icon is clicked
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown {
            togglePopover(nil)
        }
        return true
    }
}
