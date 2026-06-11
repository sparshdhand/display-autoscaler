# Architecture & Technical Design

## Tech Stack
* **Language:** Swift (Standalone script, no external framework dependencies)
* **Compiler:** `swiftc` (macOS native command-line Swift compiler, using `-Xlinker -undefined -Xlinker dynamic_lookup` to resolve private SkyLight symbols at runtime)
* **Frameworks:** Foundation, CoreGraphics
* **Private Framework Bridge:** `SkyLight.framework` (WindowServer interface, loaded dynamically by symbols bridging)

## Application Boot and Flow
1. **Startup:** The LaunchAgent loads `/usr/local/bin/display-autoscaler`.
2. **Initialization:**
   * Reads target configuration from `~/.config/display-autoscaler/config.json`.
   * If config is missing, uses default fallback parameters.
3. **Register Hardware Callback:** Registers `displayCallback` using `CGDisplayRegisterReconfigurationCallback`.
4. **Enter Run Loop:** Starts a native thread-safe `RunLoop` to keep the process alive silently.
5. **Callback Trigger (`CGDisplayReconfigurationCallBack`):**
   * Invoked on monitor plugin/unplug.
   * If `flags.contains(.addFlag)` and monitor is external (`CGDisplayIsBuiltin == 0`), runs the configuration injector.
6. **SkyLight Resolution Injection:**
   * Enumerates display modes using private API `CGSGetNumDisplayModes`.
   * Retrieves detail struct per mode index via `CGSGetDisplayModeDescriptionOfLength`.
   * Filters and selects the highest matching HiDPI resolution.
   * Commits using `CGBeginDisplayConfiguration`, `CGSConfigureDisplayMode`, and `CGCompleteDisplayConfiguration`.
