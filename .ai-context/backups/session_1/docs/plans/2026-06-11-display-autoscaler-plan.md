# display-autoscaler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-UI Swift utility that runs as a LaunchAgent to automatically detect external displays and set optimal/preferred HiDPI resolutions using private SkyLight APIs.

**Architecture:** A standalone background Swift command-line tool registering display reconfiguration callbacks, scanning all hardware display profiles via bridged SkyLight functions, and applying the matching scaling modes based on a JSON config.

**Tech Stack:** Swift, CoreGraphics, private SkyLight framework, LaunchAgents.

---

### Task 1: Setup Configuration Files

**Files:**
- Create: `/Users/sparsh/.gemini/projects/display-autoscaler/config.json.template`
- Create: `/Users/sparsh/.gemini/projects/display-autoscaler/config.json`

- [ ] **Step 1: Write template configuration**
  Create a default configuration template `config.json.template` to guide users.
  ```json
  {
    "preferredWidth": 2560,
    "preferredHeight": 1440,
    "requireHiDPI": true,
    "preferredRefreshRate": 60
  }
  ```

- [ ] **Step 2: Create local configuration file**
  Copy the template to `config.json` for compilation and local tests.
  ```json
  {
    "preferredWidth": 2560,
    "preferredHeight": 1440,
    "requireHiDPI": true,
    "preferredRefreshRate": 60
  }
  ```

- [ ] **Step 3: Commit files**
  ```bash
  git add config.json.template config.json
  git commit -m "chore: setup baseline config files"
  ```

---

### Task 2: Create Core Swift Application

**Files:**
- Create: `/Users/sparsh/.gemini/projects/display-autoscaler/main.swift`

- [ ] **Step 1: Implement Swift Core with SkyLight bridging**
  Create `main.swift` with the CGS display mode structure layout, private symbol declarations, and configuration model.
  ```swift
  import Foundation
  import CoreGraphics

  // Structural representation of the SkyLight internal Display Mode description
  struct CGSDisplayMode {
      var modeNumber: Int32
      var flags: Int32
      var width: Int32
      var height: Int32
      var depth: Int32
      var unknown1: Int32
      var unknown2: Int32
      var unknown3: Int32
      var density: Int32 // 1 = LoDPI, 2 = HiDPI (Retina)
      var refreshRate: Double
  }

  // Bridging private SkyLight framework symbols
  @_silgen_name("CGSGetNumDisplayModes")
  func CGSGetNumDisplayModes(_ displayID: CGDirectDisplayID, _ count: UnsafeMutablePointer<Int32>) -> CGError

  @_silgen_name("CGSGetDisplayModeDescriptionOfLength")
  func CGSGetDisplayModeDescriptionOfLength(_ displayID: CGDirectDisplayID, _ index: Int32, _ modeDesc: UnsafeMutablePointer<CGSDisplayMode>, _ length: Int32) -> CGError

  @_silgen_name("CGSConfigureDisplayMode")
  func CGSConfigureDisplayMode(_ configRef: CGDisplayConfigRef, _ displayID: CGDirectDisplayID, _ modeNumber: Int32) -> CGError

  // Configuration JSON Model
  struct AppConfig: Codable {
      var preferredWidth: Int32?
      var preferredHeight: Int32?
      var requireHiDPI: Bool?
      var preferredRefreshRate: Double?
  }

  func loadConfig() -> AppConfig {
      let home = FileManager.default.homeDirectoryForCurrentUser
      let configURL = home.appendingPathComponent(".config/display-autoscaler/config.json")
      do {
          let data = try Data(contentsOf: configURL)
          return try JSONDecoder().decode(AppConfig.self, from: data)
      } catch {
          print("[display-autoscaler:warn] Could not load config.json at \(configURL.path), using default fallback logic: \(error)")
          return AppConfig(preferredWidth: nil, preferredHeight: nil, requireHiDPI: true, preferredRefreshRate: 60.0)
      }
  }

  func optimizeDisplaySettings(displayID: CGDirectDisplayID) {
      let config = loadConfig()
      var numModes: Int32 = 0
      let error = CGSGetNumDisplayModes(displayID, &numModes)
      
      guard error == .success, numModes > 0 else {
          print("[display-autoscaler:error] Failed to fetch display modes for ID: \(displayID)")
          return
      }
      
      var bestMode: CGSDisplayMode? = nil
      var bestModeIndex: Int32 = -1
      
      for i in 0..<numModes {
          var mode = CGSDisplayMode(
              modeNumber: 0, flags: 0, width: 0, height: 0, depth: 0,
              unknown1: 0, unknown2: 0, unknown3: 0, density: 0, refreshRate: 0.0
          )
          let modeErr = CGSGetDisplayModeDescriptionOfLength(displayID, i, &mode, MemoryLayout<CGSDisplayMode>.size)
          
          if modeErr == .success {
              let isHiDPI = (mode.density == 2)
              
              // If HiDPI is required/preferred, filter modes accordingly
              if let requireHiDPI = config.requireHiDPI, requireHiDPI, !isHiDPI {
                  continue
              }
              
              // Check if preferred width/height is matching
              if let prefW = config.preferredWidth, let prefH = config.preferredHeight {
                  if mode.width == prefW && mode.height == prefH {
                      if let currentBest = bestMode {
                          // Pick closest refresh rate or highest density
                          if abs(mode.refreshRate - (config.preferredRefreshRate ?? 60.0)) < abs(currentBest.refreshRate - (config.preferredRefreshRate ?? 60.0)) {
                              bestMode = mode
                              bestModeIndex = i
                          }
                      } else {
                          bestMode = mode
                          bestModeIndex = i
                      }
                  }
              } else {
                  // Fallback: Pick highest resolution HiDPI mode
                  if let currentBest = bestMode {
                      if mode.width > currentBest.width || (mode.width == currentBest.width && isHiDPI) {
                          bestMode = mode
                          bestModeIndex = i
                      }
                  } else {
                      bestMode = mode
                      bestModeIndex = i
                  }
              }
          }
      }
      
      if bestModeIndex != -1, let selected = bestMode {
          print("[display-autoscaler:info] Applying Mode \(selected.modeNumber): \(selected.width)x\(selected.height) @ \(selected.refreshRate)Hz (density: \(selected.density))")
          
          var configRef: CGDisplayConfigRef?
          let status = CGBeginDisplayConfiguration(&configRef)
          if status == .success, let cfg = configRef {
              let configErr = CGSConfigureDisplayMode(cfg, displayID, selected.modeNumber)
              if configErr == .success {
                  let commitErr = CGCompleteDisplayConfiguration(cfg, .permanently)
                  if commitErr == .success {
                      print("[display-autoscaler:info] Successfully committed display configuration for ID: \(displayID)")
                  } else {
                      print("[display-autoscaler:error] Failed to commit configuration.")
                  }
              } else {
                  print("[display-autoscaler:error] CGSConfigureDisplayMode failed: \(configErr)")
              }
          } else {
              print("[display-autoscaler:error] CGBeginDisplayConfiguration failed: \(status)")
          }
      } else {
          print("[display-autoscaler:warn] No matching display modes found.")
      }
  }

  let displayCallback: CGDisplayReconfigurationCallBack = { (displayID, flags, userInfo) in
      if flags.contains(.addFlag) {
          if CGDisplayIsBuiltin(displayID) != 0 { return }
          print("[display-autoscaler:info] External display connected. ID: \(displayID)")
          optimizeDisplaySettings(displayID: displayID)
      }
  }

  print("[display-autoscaler:info] Starting display agent. Registering callback...")
  let context = UnsafeMutableRawPointer(bitPattern: 0)
  CGDisplayRegisterReconfigurationCallback(displayCallback, context)

  // Trigger initial optimization for already connected external displays on boot
  let maxDisplays: UInt32 = 16
  var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
  var displayCount: UInt32 = 0
  if CGGetActiveDisplayList(maxDisplays, &activeDisplays, &displayCount) == .success {
      for i in 0..<Int(displayCount) {
          let disp = activeDisplays[i]
          if CGDisplayIsBuiltin(disp) == 0 {
              print("[display-autoscaler:info] Found existing external display. ID: \(disp)")
              optimizeDisplaySettings(displayID: disp)
          }
      }
  }

  RunLoop.current.run()
  ```

- [ ] **Step 2: Compile the Swift file**
  Test compilation manually:
  Run: `swiftc -O /Users/sparsh/.gemini/projects/display-autoscaler/main.swift -o /Users/sparsh/.gemini/projects/display-autoscaler/display-autoscaler`
  Expected: Successful compilation without errors or warnings.

- [ ] **Step 3: Commit code**
  ```bash
  git add main.swift
  git commit -m "feat: implement main Swift application with SkyLight bridging"
  ```

---

### Task 3: Create Installation Script

**Files:**
- Create: `/Users/sparsh/.gemini/projects/display-autoscaler/install.sh`

- [ ] **Step 1: Write install script**
  Provide automation to compile the binary, move it to `/usr/local/bin`, register the LaunchAgent, and write default configurations to `~/.config/display-autoscaler/config.json`.
  ```bash
  #!/bin/bash
  set -e

  echo "[Install] Compiling Swift source..."
  swiftc -O main.swift -o display-autoscaler

  echo "[Install] Copying executable to /usr/local/bin..."
  sudo cp display-autoscaler /usr/local/bin/display-autoscaler

  echo "[Install] Setting up configuration directory..."
  mkdir -p "$HOME/.config/display-autoscaler"
  if [ ! -f "$HOME/.config/display-autoscaler/config.json" ]; then
      cp config.json "$HOME/.config/display-autoscaler/config.json"
      echo "[Install] Default configuration created at $HOME/.config/display-autoscaler/config.json"
  fi

  echo "[Install] Creating LaunchAgent plist..."
  AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"
  cat <<EOF > "$AGENT_PLIST"
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>Label</key>
      <string>com.user.display-autoscaler</string>
      <key>ProgramArguments</key>
      <array>
          <string>/usr/local/bin/display-autoscaler</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <true/>
  </dict>
  </plist>
  EOF

  echo "[Install] Loading LaunchAgent..."
  launchctl bootstrap gui/$(id -u) "$AGENT_PLIST" || true
  launchctl kickstart -k "gui/$(id -u)/com.user.display-autoscaler" || true

  echo "[Install] Installation completed successfully!"
  ```

- [ ] **Step 2: Commit install script**
  ```bash
  git add install.sh
  git commit -m "feat: add installation script and launchagent setup"
  ```

---

### Task 4: Create Uninstallation Script

**Files:**
- Create: `/Users/sparsh/.gemini/projects/display-autoscaler/uninstall.sh`

- [ ] **Step 1: Write uninstall script**
  Provide cleanup automation.
  ```bash
  #!/bin/bash
  set -e

  AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"

  if [ -f "$AGENT_PLIST" ]; then
      echo "[Uninstall] Unloading LaunchAgent..."
      launchctl bootout gui/$(id -u) "$AGENT_PLIST" || true
      rm -f "$AGENT_PLIST"
  fi

  if [ -f "/usr/local/bin/display-autoscaler" ]; then
      echo "[Uninstall] Removing binary..."
      sudo rm -f "/usr/local/bin/display-autoscaler"
  fi

  echo "[Uninstall] Uninstallation completed successfully!"
  ```

- [ ] **Step 2: Commit uninstall script**
  ```bash
  git add uninstall.sh
  git commit -m "feat: add uninstallation script"
  ```
