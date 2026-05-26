import SwiftUI
import AppKit

enum AppTab: String, CaseIterable {
    case settings = "Settings"
    case gallery = "Gallery"
}

struct ContentView: View {
    @State private var selectedTab: AppTab = {
        if let saved = UserDefaults.standard.string(forKey: "selectedTab"), let tab = AppTab(rawValue: saved) {
            return tab
        }
        return .settings
    }()
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // Beautiful Tab Switcher
            HStack(spacing: 12) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                            .background(
                                ZStack {
                                    if selectedTab == tab {
                                        Color.white.opacity(0.15)
                                            .cornerRadius(8)
                                            .matchedGeometryEffect(id: "TabBackground", in: animation)
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Content area
            ZStack {
                if selectedTab == .settings {
                    SettingsView()
                        .transition(.opacity)
                } else {
                    GalleryView()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 250, height: 350)
        .background(Color.clear)
        .onChange(of: selectedTab) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedTab")
        }
    }
}

struct SettingsView: View {
    @AppStorage("showFlashEffect") private var showFlashEffect = true
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            
            KeyRecorderView()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flash Effect")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Flash the screen white when taking a screenshot")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Toggle("", isOn: $showFlashEffect)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                    Text("Quit Application")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 24)
        }
    }
}

struct KeyRecorderView: View {
    @State private var isRecording = false
    @State private var recordedShortcuts: [Shortcut] = .loadFromUserDefaults()
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopMonitoring()
            } else {
                recordedShortcuts.removeAll()
                startMonitoring()
            }
            isRecording.toggle()
        }) {
            HStack {
                Text("Screenshot Shortcut")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if isRecording && recordedShortcuts.isEmpty {
                    Text("Listening...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(recordedShortcuts.enumerated()), id: \.offset) { index, shortcut in
                            Text(shortcut.displayString)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isRecording ? .blue : .white)
                                .tracking(1.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isRecording ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(isRecording ? 0.12 : 0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1) // subtle border to look like a field
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .onDisappear {
            stopMonitoring()
            isRecording = false
        }
        .onChange(of: recordedShortcuts) { newValue in
            newValue.saveToUserDefaults()
            if !isRecording {
                GlobalShortcutManager.shared.registerShortcuts(newValue)
            }
        }
        .onChange(of: isRecording) { recording in
            if !recording {
                GlobalShortcutManager.shared.registerShortcuts(recordedShortcuts)
            } else {
                GlobalShortcutManager.shared.unregisterAll()
            }
        }
    }
    
    private func startMonitoring() {
        if eventMonitor != nil { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.isARepeat { return nil } // Prevent spamming when holding a key
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var keys = [String]()
            
            if modifiers.contains(.control) { keys.append("⌃") }
            if modifiers.contains(.option) { keys.append("⌥") }
            if modifiers.contains(.shift) { keys.append("⇧") }
            if modifiers.contains(.command) { keys.append("⌘") }
            
            if let characters = event.charactersIgnoringModifiers?.uppercased(), !characters.isEmpty {
                // Handle special keys roughly
                let unichars = characters.utf16
                if let first = unichars.first, first >= 0xF700 && first <= 0xF8FF {
                    keys.append("❖") // special key placeholder
                } else {
                    keys.append(characters)
                }
                
                let combo = keys.joined(separator: " ")
                let shortcut = Shortcut(
                    keyCode: event.keyCode,
                    modifierFlags: modifiers.rawValue,
                    displayString: combo
                )
                self.recordedShortcuts.append(shortcut)
                return nil // Consume event
            }
            
            return event
        }
    }
    
    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct GalleryView: View {
    @ObservedObject var store = ScreenshotStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if store.screenshots.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.2))
                    
                    VStack(spacing: 4) {
                        Text("No screenshots yet")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Capture area to see screenshots here.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.screenshots, id: \.self) { url in
                            GalleryRow(url: url)
                                .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

struct GalleryRow: View {
    let url: URL
    @State private var isHovering = false
    
    var body: some View {
        let dateInfo = formatDate(url: url)
        
        HStack(spacing: 10) {
            // Thumbnail Preview
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipped()
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.white.opacity(0.05)
                    .frame(width: 38, height: 38)
                    .cornerRadius(6)
            }
            
            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(dateInfo.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(dateInfo.subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Hover action pill OR size label
            if isHovering {
                HStack(spacing: 0) {
                    Button(action: {
                        copyToClipboard(url)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 26, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy to clipboard")
                    
                    Color.white.opacity(0.15)
                        .frame(width: 1, height: 12)
                    
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 26, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Show in Finder")
                    
                    Color.white.opacity(0.15)
                        .frame(width: 1, height: 12)
                    
                    Button(action: {
                        deleteScreenshot(url)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 26, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete")
                }
                .frame(height: 22)
                .background(Color.black.opacity(0.5))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text(formatSize(url: url))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovering ? 0.06 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isHovering ? 0.08 : 0.04), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatDate(url: URL) -> (title: String, subtitle: String) {
        let filename = url.deletingPathExtension().lastPathComponent
        let parts = filename.components(separatedBy: "_")
        
        guard parts.count >= 3 else {
            return (filename, "")
        }
        
        let dateString = parts[1]
        let timeString = parts[2].replacingOccurrences(of: ".", with: ":")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return ("Today", timeString)
            } else if calendar.isDateInYesterday(date) {
                return ("Yesterday", timeString)
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "MMM d, yyyy"
                return (displayFormatter.string(from: date), timeString)
            }
        }
        
        return (dateString, timeString)
    }
    
    private func formatSize(url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let kb = Double(size) / 1024.0
            if kb > 1024 {
                return String(format: "%.1f MB", kb / 1024.0)
            }
            return String(format: "%.0f KB", kb)
        }
        return "PNG"
    }
    
    private func copyToClipboard(_ url: URL) {
        if let nsImage = NSImage(contentsOf: url) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
        }
    }
    
    private func deleteScreenshot(_ url: URL) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            try? FileManager.default.removeItem(at: url)
            ScreenshotStore.shared.loadScreenshots()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}


