# FlowBar

FlowBar is a lightweight macOS 13+ menu bar app that shows current download speed in the status bar and current battery details in a small popover.

## Build

Requires macOS 13+ and a working SwiftPM/Xcode Command Line Tools installation for Swift 5.9 or newer. If `swift` fails before compiling with a missing `BuildServerProtocol.framework`, repair or reinstall Xcode Command Line Tools.

```bash
swift test
Scripts/build-app.sh
```

The app bundle is created at:

```text
.build/FlowBar.app
```

## Run

```bash
open .build/FlowBar.app
```

FlowBar is menu-bar-only and should not appear in the Dock.

## Version 1 Scope

- Shows download speed in the status bar.
- Refreshes every 2 seconds.
- Shows battery temperature, charging power, battery level, and charging state in the popover.
- Includes a minimal Launch at Login toggle.
- Does not show upload speed.
- Does not store metric history.
- Does not use third-party sensor tools.

## Manual Verification

- Start FlowBar and confirm a `↓` speed appears in the menu bar.
- Generate network download activity and confirm the menu bar value changes.
- Stop network activity and confirm the value returns to a low or zero speed.
- Click the menu bar item and confirm the popover opens.
- Confirm unavailable battery fields show `--` without breaking other fields.
- Connect and disconnect power and confirm charging state changes if macOS exposes it.
- Toggle Launch at Login on and off.
- Confirm FlowBar does not appear in the Dock.
