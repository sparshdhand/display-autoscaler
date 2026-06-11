# Architecture & Technical Design

## Tech Stack
* **Language:** Swift (Standalone script, no external framework dependencies)
* **Compiler:** `swiftc` (macOS native command-line Swift compiler, using `-Xlinker -undefined -Xlinker dynamic_lookup` to resolve private SkyLight symbols at runtime)
* **Frameworks:** Foundation, CoreGraphics, IOKit
* **Private Framework Bridge:** `SkyLight.framework` (WindowServer interface, loaded dynamically by symbols bridging)

## Application Boot and Flow
1. **Startup:** The LaunchAgent loads `$HOME/bin/display-autoscaler`.
2. **Initialization:**
   * Reads target configuration from `~/.config/display-autoscaler/config.json`.
   * If config is missing, uses default fallback parameters.
3. **Register Hardware Callback:** Registers `displayCallback` using `CGDisplayRegisterReconfigurationCallback`.
4. **Setup Probing Timer:** Starts a 10-second background polling timer. If no external display is active, it searches for `IOFramebuffer` services via IOKit and calls `IOServiceRequestProbe` to force hardware re-detection.
5. **Enter Run Loop:** Starts a native thread-safe `RunLoop` to keep the process and timers alive silently.
6. **Callback Trigger (`CGDisplayReconfigurationCallBack`):**
   * Invoked on monitor plugin/unplug or configuration change.
   * If external monitor is active, runs the configuration injector.
7. **Resolution Injection & Presenter Mode:**
   * Evaluates aspect ratios dynamically matching target limits (within 5% tolerance) to prevent screen stretching.
   * Matches preferred scaling resolution/refresh rates from configuration.
   * Applies configurations using CoreGraphics transactions.
   * **Graceful Fallback:** If optimized configurations fail, applies safe baseline resolutions (e.g., 1080p, 720p).
   * **Presenter Mirroring:** If `enablePresenterMirroring` is true, configures mirroring layouts (Master/Slave relationship) dynamically using CoreGraphics configuration APIs.
   * **Desktop Diagnostic Logger:** Generates details at `~/Desktop/display-diagnostic-report.txt` containing display diagnostics and troubleshooting tips.
