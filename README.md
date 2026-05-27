# 📸 Screenshooter

[![macOS](https://img.shields.io/badge/platform-macOS%2011.0%2B-blue.svg?logo=apple&style=flat-square)](https://developer.apple.com/macos/)
[![Language](https://img.shields.io/badge/language-Swift%205-orange.svg?style=flat-square)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

**Screenshooter** is a lightweight, fast, and elegant native macOS application for capturing and managing screenshots. Built entirely in Swift, it leverages **SwiftUI** for a modern interface and low-level macOS APIs (**Carbon & AppKit**) for global shortcut monitoring and interactive screen overlay selection.

The application rests in the macOS Menu Bar and also displays in the Dock for quick, seamless access.

---

## ✨ Features

*   **🎧 Global System-wide Shortcuts**: Dynamically configure your own custom hotkey from the app's settings via Carbon HotKey API (works system-wide, from any active application).
*   **🎯 Interactive Area Selection**: Drag-and-select area capture with a crosshair cursor, custom selection borders, and a dimmed screen overlay.
*   **🖼 Elegant Popover Gallery**: View your latest captures directly from the Menu Bar, including date, time, and file size information.
*   **📋 Copy to Clipboard**: Automatically copies newly taken screenshots to your clipboard for instant sharing.
*   **📂 Finder & File Actions**: Reveal captures in Finder, copy files back to the clipboard, or delete them directly from the gallery row.
*   **⚡ Visual & Audio Feedback**: Configurable camera flash effect (`Flash Effect`) and sound cues (`Sound Effect`) upon successful capture.
*   **🎨 Premium Dark Design**: Implements native acrylic/vibrant dark popover design with fluid spring animations.

---

## 🛠 Project Architecture

The application is structured into the following key components:

1.  **`main.swift`** — The entry point of the app. It configures the shared `NSApplication` instance, sets the activation policy, and delegates to the AppDelegate.
2.  **`AppDelegate.swift`** — Manages the lifecycle of the application. It initializes the Popover view, status bar item (camera viewfinder icon), and manages the initial registration of saved shortcuts.
3.  **`ContentView.swift`** — SwiftUI layout defining the user interface. It contains two main tabs:
    *   **Settings**: Capture shortcut recording, toggle feedback effects, and the quit application trigger.
    *   **Gallery**: An interactive list of files in the screenshooter directory with context actions (copy, show in Finder, delete).
4.  **`GlobalShortcutManager.swift`** — The engine behind hotkey handling and selection capturing:
    *   `GlobalShortcutManager`: Binds keyboard shortcuts to the system using the Carbon framework.
    *   `CursorTrackingView` & `OverlayWindow`: A transparent fullscreen overlay window tracking mouse drag actions to highlight the selection with a dashed blue border.
    *   `CursorToggleManager`: Coordinates screen capturing via `CGDisplayCreateImage` and handles directory creation under `~/Pictures/Screenshooter`.

---

## 🚀 Build & Installation

The project uses a simple `Makefile` for quick compilation.

### Requirements
*   macOS 11.0 or newer
*   Xcode or Command Line Tools installed (`swiftc`)
*   Target Architecture: Apple Silicon (arm64). *For Intel Macs, update the `-target` flag in the `Makefile`.*

### Building the Application
To compile the project and build the standalone app bundle, run:

```bash
make
```

Upon successful compilation, a **`Screenshooter.app`** bundle will be generated in the root of the project directory. You can launch it directly or drag it into your `/Applications` directory.

### Cleaning Build Artifacts
```bash
make clean
```

---

## ⚙️ How to Use

1.  **Launch**: Run `Screenshooter.app`. The camera viewfinder icon `📷` will appear in your macOS Menu Bar.
2.  **Set Hotkey**: Click on the Menu Bar icon, navigate to **Settings**, and click on the **Screenshot Shortcut** field. Press your preferred key combination (defaults to `⇧ ⌘ S` / Shift + Cmd + S).
3.  **Capture**:
    *   Press your configured shortcut. A dimmed overlay will cover all screens, and the cursor will change to a crosshair.
    *   Click and drag to select the capture area.
    *   Release the mouse button to capture. The screenshot will flash, play a sound (if enabled), copy to your clipboard, and save as a PNG under `Pictures/Screenshooter`.
    *   To exit selection mode without capturing, press `Esc`.
4.  **Manage**: Open the Popover and switch to the **Gallery** tab to view your screenshots, copy them, show them in Finder, or delete files.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
