# GPSDump

A minimal iPhone app that shows the device's raw location data: speed, latitude/longitude, altitude and course, each with its accuracy, and how old the current fix is.

Navigation apps are often useless on a fast train or a plane: they snap your position to roads, and many stop working without a data connection. GPSDump does neither. It shows what the GNSS receiver reports, and it works offline.

## Features

- **Speed**: shown large, in km/h or mph. It comes from the GNSS Doppler measurement (accurate to about ±0.5 km/h even at 900 km/h). When that's unavailable, the app falls back to a speed worked out from the change in position, marked with `≈`.
- **Latitude / longitude** with horizontal accuracy (±).
- **Altitude** above mean sea level, with vertical accuracy (±).
- **Course**: heading in degrees with a compass point, plus accuracy.
- **Fix age**: a status dot that is green when the fix is under 3 s old, yellow under 10 s, red after that.
- **Mode**: *Ground/Rail* (`.otherNavigation`) or *Airborne* (`.airborne`). Neither snaps to roads.
- **Units**: tap anywhere on the screen to switch between metric and imperial. The choice is remembered.
- The screen stays on while the app is open.

## Requirements

- macOS with **Xcode 26** or later, including the iOS platform (`xcodebuild -downloadPlatform iOS`)
- An iPhone running **iOS 17** or later (tested on the iPhone 13 mini and iPhone 17 Pro simulators)

## Run in the Simulator

1. Open `GPSDump.xcodeproj` in Xcode.
2. Pick a simulator and press **Run** (⌘R).
3. Simulate movement: in the Simulator menu, choose **Features → Location → Freeway Drive**. For a chosen speed, run this from a terminal:

   ```bash
   # ~300 km/h (83 m/s) along a route of lat,lon waypoints
   xcrun simctl location booted start --speed=83 47.4979,19.0402 47.6,19.4 47.9,20.4
   ```

The Simulator doesn't provide altitude, so that field shows `—` there.

## Install on your iPhone (free Apple ID)

1. In Xcode, select the **GPSDump** target. Under **Signing & Capabilities**, set **Team** to your Apple ID ("Personal Team").
2. Change the **Bundle Identifier** from `com.example.GPSDump` to something unique, e.g. `com.yourname.GPSDump`.
3. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** and restart when asked.
4. Connect the iPhone, select it as the run destination, and press **Run**.
5. The first time, trust the developer on the phone: **Settings → General → VPN & Device Management**.

With a free Apple ID, the app's signature expires after **7 days**. Reconnect the phone and press Run again to refresh it. A paid Apple Developer Program membership extends this to a year.

## Tips for trains and planes

- **Get a fix while you still have signal**, e.g. at the station or gate. With a data connection, the phone downloads satellite orbit data (assisted GPS) and gets a fix in seconds. Without one, a cold start can take several minutes. The downloaded data stays valid for about 4 hours.
- **Sit by a window.** Train and plane bodies are metal and block much of the signal. Some trains also have metal-coated windows.
- **Airplane mode is fine.** GPS only receives, so it keeps working.
- **Trust the ± values and the fix age**, not just the number.

## Limitations

- iOS doesn't expose raw GNSS data (satellite count, signal strength, NMEA). Values come from Core Location, which fuses GNSS with other sources when they're available.
- Location updates may pause when you're not moving. The status line then shows `STATIONARY`.

## Project layout

```
GPSDump/
├── GPSDump.xcodeproj         Xcode project (open this)
└── GPSDump/                  App sources
    ├── GPSDumpApp.swift      App entry point
    ├── ContentView.swift     The single screen and value formatting
    └── LocationModel.swift   Core Location live updates, mode, derived speed
```
