# Design Specification: display-autoscaler

A minimalist, zero-UI background utility written in Swift that detects external display connections and programmatically applies optimal Retina (HiDPI) resolution scaling using macOS private SkyLight APIs.

## 1. Project Directory Structure

```
display-autoscaler/
├── .ai-context/
│   ├── PROJECT_OVERVIEW.md
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT_LOG.md
│   └── DESIGN.md
├── docs/
│   └── specs/
│       └── 2026-06-11-display-autoscaler-design.md
├── config.json.template
├── main.swift
├── install.sh
└── uninstall.sh
```

---

## 2. Core Components

### A. Private SkyLight API Bridge
Since macOS filters out custom Retina scaling resolutions on third-party monitors through public APIs, we bridge private `SkyLight.framework` symbols. We define a robust display mode structure mapping to avoid fragile offset array lookups.

#### Swift Declarations
```swift
struct CGSDisplayMode {
    var modeNumber: Int32
    var flags: Int32
    var width: Int32
    var height: Int32
    var depth: Int32
    var refreshRate: Double
    var density: Int32 // 1 = LoDPI, 2 = HiDPI (Retina)
    // Extra fields to match physical structure padding...
}
```

We link the following system functions using `@_silgen_name`:
* `CGSGetNumDisplayModes`
* `CGSGetDisplayModeDescriptionOfLength`
* `CGSConfigureDisplayMode`

### B. Display Hot-Plug Detection
Instead of CPU-intensive polling, we register a callback with the macOS windowing engine:
```swift
CGDisplayRegisterReconfigurationCallback(displayCallback, nil)
```
When `flags.contains(.addFlag)` fires:
1. Validate it is an external screen (`CGDisplayIsBuiltin(displayID) == 0`).
2. Query and optimize resolution modes for the newly added display.

### C. Resolution Configuration (JSON)
Located at `~/.config/display-autoscaler/config.json`:
* `preferredWidth`: Target width (e.g. `2560`)
* `preferredHeight`: Target height (e.g. `1440`)
* `requireHiDPI`: Boolean to force Retina scaling (defaults to `true`)
* `preferredRefreshRate`: Target refresh rate (defaults to `60.0`)

---

## 3. Installation & LaunchAgent
1. Compile into a standalone binary: `swiftc -O main.swift -o display-autoscaler`
2. Move binary to `/usr/local/bin/`
3. Generate LaunchAgent plist `com.user.display-autoscaler.plist` in `~/Library/LaunchAgents/`
4. Load agent: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.display-autoscaler.plist`
