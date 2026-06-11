import Foundation
import CoreGraphics
import IOKit

// --- Bridging Private / Hardware APIs ---
@_silgen_name("IOServiceRequestProbe")
func IOServiceRequestProbe(_ service: io_service_t, _ options: UInt32) -> kern_return_t

// Configuration JSON Model
struct AppConfig: Codable {
    var preferredWidth: Int32?
    var preferredHeight: Int32?
    var requireHiDPI: Bool?
    var preferredRefreshRate: Double?
    var enablePresenterMirroring: Bool?
}

func log(_ message: String) {
    print(message)
    fflush(stdout)
}

func loadConfig() -> AppConfig {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let configURL = home.appendingPathComponent(".config/display-autoscaler/config.json")
    do {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    } catch {
        log("[display-autoscaler:warn] Could not load config.json, using defaults: \(error)")
        return AppConfig(preferredWidth: nil, preferredHeight: nil, requireHiDPI: true, preferredRefreshRate: 60.0, enablePresenterMirroring: true)
    }
}

// Helper to query detailed text descriptions of a display mode
func getDisplayDetailsString(displayID: CGDirectDisplayID) -> String {
    guard let mode = CGDisplayCopyDisplayMode(displayID) else {
        return "Unknown Mode"
    }
    let w = mode.width
    let h = mode.height
    let pw = mode.pixelWidth
    let ph = mode.pixelHeight
    let refresh = mode.refreshRate
    let isHiDPI = pw > w
    let aspect = Double(w) / Double(h)
    let aspectStr = String(format: "%.2f", aspect)
    
    return "\(w)x\(h) (Physical: \(pw)x\(ph)) | Refresh: \(refresh)Hz | Aspect: \(aspectStr) | HiDPI: \(isHiDPI)"
}

// --- Feature 1: Force Hardware Probing (Auto-Scanner) ---
func forceHardwareProbe() {
    let mainDisplay = CGMainDisplayID()
    let service = CGDisplayIOServicePort(mainDisplay)
    if service != 0 {
        // Option 1 = Force hardware re-probe
        let kr = IOServiceRequestProbe(service, 1)
        if kr == 0 {
            log("[display-autoscaler:info] Triggered background hardware display probe.")
        } else {
            log("[display-autoscaler:error] IOServiceRequestProbe failed: \(kr)")
        }
    }
}

// --- Feature 5: Diagnostic Desktop Logger ---
func writeDesktopDiagnosticReport() {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let reportURL = home.appendingPathComponent("Desktop/display-diagnostic-report.txt")
    
    var report = "=== Display Autoscaler Diagnostics ===\n"
    report += "Generated: \(Date().description)\n\n"
    
    var onlineCount: UInt32 = 0
    CGGetOnlineDisplayList(16, nil, &onlineCount)
    report += "Online Displays Detected: \(onlineCount)\n"
    
    var list = [CGDirectDisplayID](repeating: 0, count: Int(onlineCount))
    CGGetOnlineDisplayList(16, &list, &onlineCount)
    
    for (i, id) in list.enumerated() {
        let isBuiltin = CGDisplayIsBuiltin(id) != 0
        let isActive = CGDisplayIsActive(id) != 0
        let isMirrored = CGDisplayIsInMirrorSet(id) != 0
        let details = getDisplayDetailsString(displayID: id)
        
        report += "Display [\(i)]: ID \(id)\n"
        report += "  - Built-in: \(isBuiltin)\n"
        report += "  - Active: \(isActive)\n"
        report += "  - Mirrored: \(isMirrored)\n"
        report += "  - Mode: \(details)\n\n"
    }
    
    report += "=== Troubleshooting Tips ===\n"
    report += "1. If TV is blank: Wait up to 10 seconds. The background auto-prober triggers port scans automatically.\n"
    report += "2. Mirroring: If sharing slides, enable mirroring in macOS Settings or configure 'enablePresenterMirroring' in your config.json.\n"
    report += "3. Hardware limit: Apple Silicon chips may limit standard models to 1 external display.\n"
    
    do {
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        log("[display-autoscaler:info] Wrote diagnostic report to desktop.")
    } catch {
        log("[display-autoscaler:error] Failed to write diagnostic report: \(error)")
    }
}

func optimizeDisplaySettings(displayID: CGDirectDisplayID) {
    let beforeDetails = getDisplayDetailsString(displayID: displayID)
    log("[display-autoscaler:info] [BEFORE] Display ID \(displayID): \(beforeDetails)")

    let config = loadConfig()
    
    // Pass options to get all hidden and duplicate display modes
    let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    guard let modes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
        log("[display-autoscaler:error] Failed to fetch display modes for ID: \(displayID)")
        return
    }
    
    // --- Feature 2: Dynamic Aspect-Ratio Matching ---
    // Get current aspect ratio of the connected display
    guard let currentMode = CGDisplayCopyDisplayMode(displayID) else { return }
    let targetAspect = Double(currentMode.width) / Double(currentMode.height)
    let aspectTolerance = 0.05
    
    var bestMode: CGDisplayMode? = nil
    var fallbackModes = [CGDisplayMode]()
    
    for mode in modes {
        let w = Int32(mode.width)
        let h = Int32(mode.height)
        let pw = Int32(mode.pixelWidth)
        let isHiDPI = pw > w
        let refresh = mode.refreshRate
        let aspect = Double(w) / Double(h)
        
        // Collect safe fallbacks (e.g. 1080p, 720p)
        if (w == 1920 && h == 1080) || (w == 1280 && h == 720) {
            fallbackModes.append(mode)
        }
        
        // Filters
        if let requireHiDPI = config.requireHiDPI, requireHiDPI, !isHiDPI {
            continue
        }
        
        // Force aspect ratio alignment to prevent stretched classroom projections
        if abs(aspect - targetAspect) > aspectTolerance {
            continue
        }
        
        // Match preferred resolution settings
        if let prefW = config.preferredWidth, let prefH = config.preferredHeight {
            if w == prefW && h == prefH {
                if let currentBest = bestMode {
                    let targetRefresh = config.preferredRefreshRate ?? 60.0
                    if abs(refresh - targetRefresh) < abs(currentBest.refreshRate - targetRefresh) {
                        bestMode = mode
                    }
                } else {
                    bestMode = mode
                }
            }
        } else {
            // Fallback: Pick highest resolution matching aspect ratio
            if let currentBest = bestMode {
                if w > Int32(currentBest.width) || (w == Int32(currentBest.width) && isHiDPI) {
                    bestMode = mode
                }
            } else {
                bestMode = mode
            }
        }
    }
    
    // If we found a matching optimized mode, apply it
    var appliedSuccess = false
    if let selected = bestMode {
        let isSelectedHiDPI = selected.pixelWidth > selected.width
        log("[display-autoscaler:info] Selecting Mode: \(selected.width)x\(selected.height) (Physical: \(selected.pixelWidth)x\(selected.pixelHeight)) @ \(selected.refreshRate)Hz (HiDPI: \(isSelectedHiDPI))")
        
        appliedSuccess = applyDisplayMode(displayID: displayID, mode: selected)
    }
    
    // --- Feature 3: Graceful Fallbacks ---
    // If the optimized mode fails to apply or no mode was found, apply a standard safe fallback
    if !appliedSuccess {
        log("[display-autoscaler:warn] Applying optimized mode failed or was not found. Attempting safe baseline fallback...")
        for fallback in fallbackModes.sorted(by: { $0.width > $1.width }) {
            if applyDisplayMode(displayID: displayID, mode: fallback) {
                log("[display-autoscaler:info] Graceful fallback successful.")
                appliedSuccess = true
                break
            }
        }
    }
    
    // --- Feature 4: Presenter Mirroring ---
    // Automatically configure mirroring if configured and external display is optimized
    if appliedSuccess && (config.enablePresenterMirroring ?? true) {
        configureMirroring(targetDisplayID: displayID)
    }
}

func applyDisplayMode(displayID: CGDirectDisplayID, mode: CGDisplayMode) -> Bool {
    var configRef: CGDisplayConfigRef?
    let status = CGBeginDisplayConfiguration(&configRef)
    if status == .success, let cfg = configRef {
        let configErr = CGConfigureDisplayWithDisplayMode(cfg, displayID, mode, nil)
        if configErr == .success {
            let commitErr = CGCompleteDisplayConfiguration(cfg, .permanently)
            if commitErr == .success {
                let afterDetails = getDisplayDetailsString(displayID: displayID)
                log("[display-autoscaler:info] [AFTER]  Display ID \(displayID): \(afterDetails)")
                return true
            }
        }
    }
    return false
}

func configureMirroring(targetDisplayID: CGDirectDisplayID) {
    log("[display-autoscaler:info] Reconfiguring presenter mirroring...")
    var configRef: CGDisplayConfigRef?
    let status = CGBeginDisplayConfiguration(&configRef)
    if status == .success, let cfg = configRef {
        // Mirror the built-in display to the external display
        let main = CGMainDisplayID()
        let isMainBuiltin = CGDisplayIsBuiltin(main) != 0
        
        let masterID = isMainBuiltin ? main : targetDisplayID
        let slaveID = isMainBuiltin ? targetDisplayID : main
        
        let mirrorErr = CGConfigureDisplayMirrorOfDisplay(cfg, slaveID, masterID)
        if mirrorErr == .success {
            let commitErr = CGCompleteDisplayConfiguration(cfg, .permanently)
            if commitErr == .success {
                log("[display-autoscaler:info] Presenter Mirroring committed successfully. Master ID \(masterID) -> Slave ID \(slaveID)")
            } else {
                log("[display-autoscaler:error] Mirroring commit failed.")
            }
        } else {
            log("[display-autoscaler:error] CGConfigureDisplayMirrorOfDisplay failed: \(mirrorErr)")
        }
    }
}

func optimizeAllExternalDisplays() {
    var activeCount: UInt32 = 0
    CGGetActiveDisplayList(16, nil, &activeCount)
    
    var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(activeCount))
    if CGGetActiveDisplayList(16, &activeDisplays, &activeCount) == .success {
        log("[display-autoscaler:info] Active display count: \(activeCount)")
        var hasExternal = false
        for i in 0..<Int(activeCount) {
            let disp = activeDisplays[i]
            let isBuiltin = CGDisplayIsBuiltin(disp) != 0
            log("[display-autoscaler:info] Active Display [\(i)]: ID=\(disp), Builtin=\(isBuiltin)")
            if !isBuiltin {
                hasExternal = true
                optimizeDisplaySettings(displayID: disp)
            }
        }
        
        // Write diagnostic report after configuration changes
        writeDesktopDiagnosticReport()
        
        // --- Feature 1: Force Hardware Probing Timer ---
        // If no external display is active, trigger hardware re-probe timer setup
        if !hasExternal {
            log("[display-autoscaler:info] No external screen active. Background auto-scanner active.")
        }
    }
}

let displayCallback: CGDisplayReconfigurationCallBack = { (displayID, flags, userInfo) in
    if !flags.contains(.beginConfigurationFlag) {
        log("[display-autoscaler:info] Reconfiguration complete callback for Display ID \(displayID). Flags rawValue: \(flags.rawValue)")
        optimizeAllExternalDisplays()
    }
}

log("[display-autoscaler:info] Starting display agent. Registering callback...")
let context = UnsafeMutableRawPointer(bitPattern: 0)
CGDisplayRegisterReconfigurationCallback(displayCallback, context)

// Trigger initial optimization
optimizeAllExternalDisplays()

// Setup periodic background probing timer (runs every 10 seconds)
let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
    var activeCount: UInt32 = 0
    CGGetActiveDisplayList(16, nil, &activeCount)
    var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(activeCount))
    if CGGetActiveDisplayList(16, &activeDisplays, &activeCount) == .success {
        var hasExternal = false
        for disp in activeDisplays {
            if CGDisplayIsBuiltin(disp) == 0 {
                hasExternal = true
                break
            }
        }
        // Only trigger hardware scan if no external displays are currently online
        if !hasExternal {
            forceHardwareProbe()
        }
    }
}

// Run the loop to keep the process and timers alive
RunLoop.current.add(timer, forMode: .common)
RunLoop.current.run()
