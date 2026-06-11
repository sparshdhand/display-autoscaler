# Project Overview: display-autoscaler

A minimalist, zero-UI background utility for macOS designed to automatically apply high-quality resolution scaling (HiDPI/Retina) configurations when external monitors are hot-plugged via HDMI/DisplayPort.

## Core Value Proposition
macOS often restricts third-party (non-Apple) monitors to low-DPI scaling profiles or generic, blurry resolutions when connected over HDMI or DisplayPort. `display-autoscaler` runs silently in the background, intercepts connection handshakes, bypasses public API filtering by utilizing private SkyLight APIs, and instantly sets optimal or user-preferred HiDPI scaling resolutions.

## Target Audience
Power users, developers, and designers using non-Apple monitors on macOS who want crisp text scaling without paying for premium display management utilities or opening GUI apps every time a monitor is reconnected.

## Core Features
- **Zero-UI Background Daemon:** Runs as a standard LaunchAgent process with near-zero idle CPU and memory utilization.
- **Dynamic Hot-Plug Callback:** Registers a direct hardware handshake callback with `WindowServer` to act immediately upon display additions.
- **Private SkyLight Mode Querying:** Bypasses macOS public filters to enumerate all hardware-supported monitor modes.
- **JSON Configuration Support:** Supports preferred target width, height, refresh rates, and HiDPI requirements.
