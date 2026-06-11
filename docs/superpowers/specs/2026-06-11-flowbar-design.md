# FlowBar Design

Date: 2026-06-11

## Summary

FlowBar is a lightweight macOS menu bar app for showing current download speed in the status bar and current battery details in a small popover. The first version targets local developer use on macOS 13 Ventura and newer.

The product should stay low profile: no Dock icon, no Electron, no WebView, no third-party command-line dependency, no history database, and no background daemon.

## Product Scope

The first version is a native menu bar app with a single status item. The status item shows only current download speed, refreshed every 2 seconds.

Example status text:

```text
↓ 1.2M
```

Clicking the status item opens a small popover with current details:

- Download speed
- Battery temperature
- Current charging power
- Battery level
- Charging or discharging state
- A minimal "Launch at Login" toggle

Out of scope for the first version:

- Upload speed display
- Historical charts
- Alerts
- Advanced diagnostics
- Full settings window
- Mac App Store distribution
- Third-party sensor tools

## Technical Architecture

FlowBar will use Swift and AppKit.

### Modules

`FlowBarApp`

Owns application startup, hides the Dock icon, and initializes the status bar controller.

`StatusBarController`

Owns the `NSStatusItem`, schedules status text updates, and opens or closes the details popover.

`MetricsSampler`

Coordinates network and battery sampling. It exposes a small snapshot model to UI code so the UI does not depend on low-level system APIs.

`NetworkSpeedMonitor`

Reads cumulative received bytes from active non-loopback network interfaces and calculates download speed from the delta between samples.

The first version does not expose upload speed.

`BatteryMonitor`

Reads battery state from system APIs, preferring IOKit. It attempts to read temperature, voltage, current, battery level, and charging state. Charging power is calculated from voltage and current when both are available.

`BatteryPopoverViewController`

Renders the lightweight details popover and the launch-at-login toggle.

`LaunchAtLoginController`

Uses `SMAppService` to register or unregister the app as a login item when the user toggles the setting.

## Data Strategy

### Network Speed

Network speed is sampled every 2 seconds. The monitor reads cumulative received bytes, subtracts the previous sample, and divides by elapsed time.

The monitor excludes loopback and inactive interfaces. If multiple active interfaces are present, it sums their received-byte deltas.

Display format uses compact automatic units:

```text
↓ 0K
↓ 860K
↓ 1.2M
↓ 1.1G
```

Units are intentionally short to minimize menu bar width.

### Battery Temperature

Battery temperature is displayed in Celsius. If the system does not expose a usable temperature field, the popover displays `--` for temperature and continues showing other available fields.

### Charging Power

Charging power is calculated from voltage and current when available:

```text
watts = volts * amps
```

Display examples:

```text
+18W
-6W
0W
--
```

Positive values mean the battery is charging. Negative values mean the battery is discharging. Missing voltage or current data produces `--`.

## UI Behavior

FlowBar does not appear in the Dock or app switcher. It only appears as a menu bar status item.

The popover is intentionally simple. It shows current values and one launch-at-login toggle. It does not include a full preferences screen.

Field failures are local to the field. For example, if battery temperature is unavailable, the temperature row shows `--` while download speed, battery level, and charging state continue to update.

## Error Handling

FlowBar should avoid user-facing error alerts during normal operation.

If network data is temporarily unavailable, the status item should show `↓ --` until the next successful sample. It should not keep showing a stale speed as if it were current.

If a battery field is unavailable, the popover should show `--` for that field.

Debug builds may log sampling failures with `os_log`.

## Lightweight Constraints

The implementation should preserve these constraints:

- No Electron
- No WebView
- No third-party command-line sensor dependency
- No background daemon
- No persistent metric history
- No upload-speed calculation or display in version 1
- 2-second sampling interval
- UI work only when needed
- Small, separated modules with clear responsibilities

## Verification Plan

Manual verification for version 1:

- With normal network activity, the menu bar shows a changing download speed.
- With no obvious network activity, the menu bar shows a low or zero download speed.
- While connected to power, the popover shows charging state and charging power when the system exposes the required data.
- While disconnected from power, the popover shows discharging state and negative or unavailable power depending on available system data.
- If battery temperature is unavailable, only that field falls back to `--`.
- The app does not appear in the Dock.
- Clicking the menu bar item opens the popover.
- The launch-at-login toggle can register and unregister the app.

## Open Decisions

There are no open product decisions for version 1.

Implementation may still need to choose the exact low-level IOKit keys and fallback behavior after probing real macOS data on the target machine.
