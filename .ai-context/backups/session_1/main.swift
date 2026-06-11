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
        let modeErr = CGSGetDisplayModeDescriptionOfLength(displayID, i, &mode, Int32(MemoryLayout<CGSDisplayMode>.size))
        
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
