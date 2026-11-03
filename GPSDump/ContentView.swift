import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @State private var model = LocationModel()
    @AppStorage("imperial") private var imperial = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Only the fix-age line needs a 1 s tick; keep the timeline scoped to it.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                status(now: context.date)
            }
            speed
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            row("LATITUDE", latitude, horizontalAccuracy)
            row("LONGITUDE", longitude, horizontalAccuracy)
            row("ALTITUDE", altitude, verticalAccuracy)
            row("COURSE", course, courseAccuracy)
            Spacer()
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .foregroundStyle(.white)
        .fontDesign(.monospaced)
        .contentShape(Rectangle())
        .onTapGesture { imperial.toggle() }
        .onAppear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            model.start()
        }
    }

    // MARK: - Sections

    private func status(now: Date) -> some View {
        let (text, color): (String, Color) = {
            if model.authorization == .denied || model.authorization == .restricted {
                return ("LOCATION ACCESS DENIED", .red)
            }
            guard let location = model.location else { return ("WAITING FOR FIX…", .orange) }
            let age = max(0, Int(now.timeIntervalSince(location.timestamp)))
            let suffix = model.isStationary ? " · STATIONARY" : ""
            let color: Color = age < 3 ? .green : age < 10 ? .yellow : .red
            return ("FIX \(age)s AGO\(suffix)", color)
        }()
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var speed: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SPEED").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(speedValue)
                    .font(.system(size: 96, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(imperial ? "mph" : "km/h").font(.title3).foregroundStyle(.secondary)
            }
            Text(speedNote).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func row(_ label: String, _ value: String, _ accuracy: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.title2).monospacedDigit()
                Spacer()
                Text(accuracy).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private var footer: some View {
        Text("tap anywhere: units")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Formatting

    private var loc: CLLocation? { model.location }
    private let dash = "—"

    private var speedFactor: Double { imperial ? 2.236936 : 3.6 }

    private var speedValue: String {
        guard let s = model.speed else { return dash }
        let converted = s.metersPerSecond * speedFactor
        return String(format: converted < 100 ? "%.1f" : "%.0f", converted)
    }

    private var speedNote: String {
        guard let s = model.speed else {
            return loc == nil ? " " : "no reliable reading (weak signal)"
        }
        let accuracy = "± " + String(format: "%.1f", s.accuracy * speedFactor)
        return s.source == .derived ? "≈ from position change, \(accuracy)" : accuracy
    }

    private var latitude: String {
        guard let loc, loc.horizontalAccuracy >= 0 else { return dash }
        let v = loc.coordinate.latitude
        return String(format: "%.6f° %@", abs(v), v >= 0 ? "N" : "S")
    }

    private var longitude: String {
        guard let loc, loc.horizontalAccuracy >= 0 else { return dash }
        let v = loc.coordinate.longitude
        return String(format: "%.6f° %@", abs(v), v >= 0 ? "E" : "W")
    }

    private var horizontalAccuracy: String {
        guard let loc, loc.horizontalAccuracy >= 0 else { return "" }
        return "± " + distance(loc.horizontalAccuracy)
    }

    private var altitude: String {
        guard let loc, loc.verticalAccuracy > 0 else { return dash }
        return distance(loc.altitude)
    }

    private var verticalAccuracy: String {
        guard let loc, loc.verticalAccuracy > 0 else { return "" }
        return "± " + distance(loc.verticalAccuracy)
    }

    private var course: String {
        guard let loc, loc.course >= 0 else { return dash }
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let cardinal = points[Int((loc.course + 22.5) / 45) % 8]
        return String(format: "%.0f° %@", loc.course, cardinal)
    }

    private var courseAccuracy: String {
        guard let loc, loc.course >= 0, loc.courseAccuracy >= 0 else { return "" }
        return String(format: "± %.0f°", loc.courseAccuracy)
    }

    private func distance(_ meters: Double) -> String {
        imperial ? String(format: "%.0f ft", meters * 3.28084) : String(format: "%.0f m", meters)
    }
}
