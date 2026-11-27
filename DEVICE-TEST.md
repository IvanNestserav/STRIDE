# Apple Watch Ultra 1 — first device test

Native status: source prepared; build and field validation pending.

## Before running

- Build in Xcode and run PacingCore's Swift tests.
- Confirm the app requests Health/location permissions with understandable explanations.
- With Health reading withheld, it must show unavailable measurements rather than fabricated values. With workout-writing denied, confirm the save error is displayed.
- Deny location: the run should still record Health distance; terrain summary should report unavailable data.
- Select 0.5 km and a generous finish time for the first walk/jog test.
- Confirm Signature, Night, and Daylight presets are readable on the Ultra.

## During the test

- Leave the phone behind only after confirming the app starts correctly; the Watch session should run independently.
- Allow 30 seconds for a stable pace estimate. Compare measured distance with the native Workout app on a separate comparable run, not two concurrent workout sessions.
- Adjust speed gradually. Confirm the instruction changes after persistence and that haptics distinguish faster/ease/hold.
- Pause for 30 seconds in Race mode: countdown should continue.
- Repeat in Training mode: countdown should freeze.
- Lower your wrist: Always On should show a simplified display. Resume the full view by raising your wrist.
- Switch briefly to the watch face and return: the workout should remain active.
- Confirm End run requires confirmation; reaching the measured goal should end automatically.

## After the test

- Check workout time/distance in Apple Health/Fitness. Confirm one workout is saved.
- Compare the app's race elapsed time versus Health workout duration if pauses were used; these can differ by design.
- Check elevation on a flat route and a route with a modest hill. Treat totals as approximate.
- Relaunch: last summary should remain available.
- Note Watch model, watchOS/Xcode versions, battery percentage before/after, run duration, and every incorrect or excessive cue.

## Release gate

Do not label Edition 0.1 as a verified Watch app until native build, permissions, independent operation, pause modes, Health save, Always On, distance completion, and real-run pacing checks pass. Crash recovery and calibrated terrain metrics remain later work.
