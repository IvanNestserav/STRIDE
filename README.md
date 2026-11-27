# STRIDE — First Edition 0.1

Working title; no name-availability or trademark check has been performed.
Target device: first-generation Apple Watch Ultra, watchOS 10 or newer.

## What is ready

- A self-contained browser simulator: open `Stride-Test.html` in Safari or another browser.
- Swift watchOS source and an XcodeGen project specification.
- A reusable Swift pacing engine with XCTest cases.
- A JavaScript implementation of the same pacing rules and browser interaction checks.

The simulator uses synthetic distance, pace, and elevation. It does not connect to Apple Watch, read Health data, or measure GPS. It is for testing product behavior and appearance.
The native app has NOT been compiled in Xcode, installed on a Watch, or tested outdoors in this environment. Treat it as a development build, not a verified exercise product.

## Try the simulator

1. Open `Stride-Test.html` (no server, internet, or account required).
2. Enter distance and finish time, then Start simulation.
3. Adjust Runner pace or choose Faster/Slower. Choose 60× speed for a fast complete run.
4. Use “Run another 60 seconds” to advance one minute immediately.
5. Test Race versus Training clocks, unreliable data, and the appearance presets.
6. End the run to see splits and synthetic elevation. Export the JSON if desired.

Vibration in the browser is optional and browser-dependent; Safari may not support it. The native version uses WatchKit haptics.

## Native setup on a Mac

Install Xcode from Apple and finish its first-launch setup. Pair your Ultra with the development Mac through Xcode's device interface and enable Developer Mode if Xcode requests it.

### Option A — project generation

Install XcodeGen using its official instructions: https://github.com/yonaskolb/XcodeGen
From this folder run:

    xcodegen generate
    open Stride.xcodeproj

Select the Stride target and your own development team under Signing & Capabilities. Replace the bundle identifier if needed. Verify the target is a standalone watchOS application, HealthKit is enabled, and Workout Processing appears in Background Modes.
Select your paired Apple Watch Ultra as the run destination, then Build and Run.

### Option B — use Xcode directly

Create a new watchOS App named Stride, choosing a Watch-only application and SwiftUI. Delete the generated app entry point and ContentView files. Add all Swift files from WatchApp. Add the local Swift package in `Core`, linking its PacingCore product to the Watch app target.
Set deployment target watchOS 10.0+, Swift language version 5, HealthKit capability, and Workout Processing background capability.
Add these target Info properties:

- Privacy — Health Share Usage Description: Stride reads running distance and heart rate to guide your pace.
- Privacy — Health Update Usage Description: Stride saves your completed running workout to Apple Health.
- Privacy — Location When In Use Usage Description: Stride collects elevation during your run for the post-run terrain summary.

Set a unique bundle identifier and development team. Build, fix any SDK compatibility issues, and run on the paired Ultra.
A release through TestFlight/App Store requires the corresponding Apple Developer distribution setup; this package does not publish or install anything automatically.

## Native behavior

Start outdoor run requests Health permissions and creates a running workout. Distance and heart rate come from HKLiveWorkoutBuilder; Core Location altitude supplies post-run elevation. The app can continue processing through an active workout session with the appropriate capability.

- Internally stores meters and seconds. Required remaining pace = remaining seconds / remaining meters.
- Uses a roughly 30-second recent-distance window, with a 10-second warmup.
- Holds a tolerance band around the finish-time prediction rather than reacting to every minor deviation.
- A changed instruction must persist 10 seconds before a haptic; successive cues are separated by 30 seconds.
- Missing/stale distance updates suppress pace advice. “Goal time passed” replaces catch-up advice after the deadline.
- “You can ease” means the runner is projected to finish before the deadline at their recent speed. It is optional, not an instruction to slow in a personal-best attempt.
- Race clock includes pauses. Training clock excludes pauses.
- Ends and saves the workout when the measured distance reaches the goal, or when the runner confirms End run.
- HealthKit may report distance in batches, so measured completion can overshoot the target. This edition does not interpolate a certified finish time.
- Always On mode simplifies the screen when luminance is reduced.
- Last run summary is stored locally as JSON and survives normal app relaunch.

## Terrain

Terrain does not change live guidance in Edition 0.1. The native summary reports approximate ascent/descent from filtered altitude samples, requiring at least 30 meters between summary anchors and ignoring elevation changes below 2 meters.
It is a conservative prototype estimate, not a surveyed elevation total. Missing elevation is explicitly reported. The simulator uses a deliberately synthetic elevation profile and also shows split times.
No flat-equivalent pace, terrain-caused time-loss attribution, route map, or physiological inference is presented.

## Scope and known limits

Implemented: distance/time goal, recent-speed prediction, required remaining pace, hold/speed-up/ease states, persistence and cooldown, pause modes, haptics, Health workout save, simple elevation summary, appearance presets, last-run summary persistence.

Not yet implemented: race-marker distance correction, adaptive negative splits, bounded catch-up plans, multiple finish goals, configurable effort limits, voice coaching, interval sessions, workout recovery after crash/reboot, iPhone companion app, app icon artwork, route storage/export, production release.
The native summary is intentionally simpler than the browser summary; native lap/split analysis remains a follow-up.
The first Watch build must pass the device checklist before relying on it for a target run.

## Checks

JavaScript:

    node Simulator/test.cjs

Actual HTML scripts, using a minimal DOM event harness:

    node Simulator/interaction-test.cjs

Browser UI (requires Playwright and Chromium installed):

    node Simulator/ui-test.cjs

Native engine on a Mac:

    cd Core
    swift test

Native app build after project generation:

    xcodebuild -project Stride.xcodeproj -scheme Stride -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build

Swift and Xcode are not available in the development container used to produce this package. No native build or XCTest pass is claimed.

## Apple implementation references

- Running workout sessions: https://developer.apple.com/documentation/healthkit/running-workout-sessions
- Live workout builder: https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder
- Always On design: https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state/

## Ownership

Prototype prepared for Ivan Nestserav. No external fonts, assets, analytics, accounts, or paid dependencies are included in the simulator.

## Verification performed for this delivery

JavaScript pacing checks and actual standalone HTML-script interaction checks passed. Browser rendering was not verified: Chromium was unavailable and the download failed. Swift/XCTest and native watchOS compilation could not run because Swift/Xcode are unavailable here. The included device checklist is the next validation step.
