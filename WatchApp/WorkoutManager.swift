import Foundation
import HealthKit
import CoreLocation
import WatchKit
import Combine
import PacingCore

struct RunPoint: Codable { let elapsed: Double; let distance: Double; let altitude: Double? }
struct RunSummary: Codable {
    let date: Date; let goalMeters: Double; let goalSeconds: Double
    let distance: Double; let elapsed: Double; let raceClock: Bool; let points: [RunPoint]
}
// UI mutations are dispatched to the main queue; Swift 5 mode avoids implicit actor isolation.
final class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, CLLocationManagerDelegate {
    @Published var running = false
    @Published var paused = false
    @Published var saving = false
    @Published var distance = 0.0
    @Published var elapsed = 0.0
    @Published var speed = 0.0
    @Published var heartRate = 0.0
    @Published var guidance: Guidance = .waiting
    @Published var required: Double?
    @Published var projected: Double?
    @Published var summary: RunSummary?
    @Published var errorMessage: String?
    @Published var saveMessage: String?
    var goalMeters = 5000.0, goalSeconds = 1800.0
    var raceClock = true, haptics = true
    private let store = HKHealthStore()
    private let location = CLLocationManager()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var started: Date?
    private var lastDistanceUpdate: Date?
    private var window: [(t: Double, d: Double)] = []
    private var points: [RunPoint] = []
    private var altitude: Double?
    private var lastAltitudeDate: Date?
    private var candidate: Guidance = .waiting
    private var candidateSince = 0.0, lastAlert = -30.0
    private var announced: Guidance = .waiting
    private var collecting = false

    override init() {
        super.init(); location.delegate = self
        location.activityType = .fitness
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 5
        if let data = try? Data(contentsOf: summaryURL), let saved = try? JSONDecoder().decode(RunSummary.self, from: data) { summary = saved }
    }
    private var summaryURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("last-run.json") }
    func start(meters: Double, seconds: Double, race: Bool) {
        guard !running, !saving, session == nil, meters > 0, seconds > 0 else { return }
        goalMeters = meters; goalSeconds = seconds; raceClock = race; errorMessage = nil; saveMessage = nil
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), distanceType, energy]
        let read: Set<HKObjectType> = [distanceType, heartType, energy]
        saving = true
        store.requestAuthorization(toShare: share, read: read) { [weak self] ok, error in
            DispatchQueue.main.async {
                guard let self else { return }; self.saving = false
                guard ok else { self.errorMessage = error?.localizedDescription ?? "Health permission setup failed."; return }
                self.begin()
            }
        }
    }
    private func begin() {
        let config = HKWorkoutConfiguration(); config.activityType = .running; config.locationType = .outdoor
        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: config)
            session = s; let b = s.associatedWorkoutBuilder(); builder = b
            s.delegate = self; b.delegate = self
            b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            distance = 0; elapsed = 0; speed = 0; heartRate = 0; summary = nil; points = []; window = []
            altitude = nil; lastAltitudeDate = nil; lastDistanceUpdate = nil
            guidance = .waiting; required = nil; projected = nil; announced = .waiting; candidate = .waiting; candidateSince = 0; lastAlert = -30
            let now = Date(); started = now; running = true; paused = false; collecting = false
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { [weak self] ok, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if ok {
                        self.collecting = true
                        self.location.requestWhenInUseAuthorization(); self.location.startUpdatingLocation()
                        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Could not collect workout data."
                        self.session?.end(); self.cleanup()
                    }
                }
            }
        } catch { errorMessage = error.localizedDescription; cleanup() }
    }
    private func tick() {
        guard running, let started, let builder else { return }
        elapsed = raceClock ? Date().timeIntervalSince(started) : builder.elapsedTime
        if !paused {
            window.append((elapsed, distance)); window.removeAll { $0.t < elapsed - 30 }
            if let first = window.first, elapsed - first.t >= 10 { speed = max(0, (distance - first.d) / (elapsed - first.t)) } else { speed = 0 }
            let altitudeValid = lastAltitudeDate.map { Date().timeIntervalSince($0) < 15 } ?? false
            points.append(RunPoint(elapsed: elapsed, distance: distance, altitude: altitudeValid ? altitude : nil))
            let fresh = lastDistanceUpdate.map { Date().timeIntervalSince($0) < 15 } ?? false
            let result = PacingEngine.evaluate(goalMeters: goalMeters, goalSeconds: goalSeconds, distance: distance, elapsed: elapsed, speed: speed, valid: fresh)
            guidance = result.state; required = result.requiredSecondsPerKM; projected = result.projectedSeconds
            if candidate != guidance { candidate = guidance; candidateSince = elapsed }
            if haptics, fresh, guidance != .waiting, guidance != .expired, elapsed - candidateSince >= 10, elapsed - lastAlert >= 30, announced != guidance {
                WKInterfaceDevice.current().play(guidance == .faster ? .directionUp : guidance == .ease ? .directionDown : .success)
                announced = guidance; lastAlert = elapsed
            }
            if distance >= goalMeters { end() }
        } else { required = nil; projected = nil }
    }
    func togglePause() {
        guard running, collecting, let session else { return }
        if paused { session.resume() } else { session.pause() }
    }
    func end() {
        guard running, collecting, let s = session else { return }
        timer?.invalidate(); timer = nil; location.stopUpdatingLocation()
        running = false; saving = true
        if let started, let builder { elapsed = raceClock ? Date().timeIntervalSince(started) : builder.elapsedTime }
        let record = RunSummary(date: Date(), goalMeters: goalMeters, goalSeconds: goalSeconds, distance: distance, elapsed: elapsed, raceClock: raceClock, points: points)
        summary = record
        do { try JSONEncoder().encode(record).write(to: summaryURL, options: .atomic) } catch { errorMessage = "Could not save local summary: \(error.localizedDescription)" }
        s.end()
    }
    private func finish(at date: Date) {
        guard saving, let builder else { cleanup(); return }
        builder.endCollection(withEnd: date) { [weak self] ok, error in
            guard ok else { DispatchQueue.main.async { self?.errorMessage = error?.localizedDescription ?? "Could not end workout collection."; self?.cleanup() }; return }
            builder.finishWorkout { _, error in
                DispatchQueue.main.async {
                    self?.saveMessage = error == nil ? "Workout saved to Apple Health." : "Local summary saved; Health save failed."
                    if let error { self?.errorMessage = error.localizedDescription }
                    self?.cleanup()
                }
            }
        }
    }
    private func cleanup() { timer?.invalidate(); timer = nil; location.stopUpdatingLocation(); session = nil; builder = nil; running = false; paused = false; saving = false; collecting = false }
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.session === workoutSession else { return }
            if toState == .ended { self.finish(at: date) }
            else if toState == .paused { self.paused = true; self.window = []; self.speed = 0 }
            else if toState == .running { self.paused = false; self.window = []; self.candidateSince = self.elapsed }
        }
    }
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.errorMessage = error.localizedDescription; self?.cleanup() }
    }
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let meters = collectedTypes.contains(distanceType) ? workoutBuilder.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()) : nil
        let bpm = collectedTypes.contains(heartType) ? workoutBuilder.statistics(for: heartType)?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) : nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.builder === workoutBuilder else { return }
            if let meters { self.distance = max(self.distance, meters); self.lastDistanceUpdate = Date() }
            if let bpm { self.heartRate = bpm }
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let point = locations.last, point.verticalAccuracy >= 0, point.verticalAccuracy <= 15, abs(point.timestamp.timeIntervalSinceNow) < 15 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.running, !self.paused else { return }
            self.altitude = self.altitude.map { $0 * 0.8 + point.altitude * 0.2 } ?? point.altitude
            self.lastAltitudeDate = point.timestamp
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Distance still comes from HealthKit. Missing altitude is reported as unavailable in the summary.
        DispatchQueue.main.async { [weak self] in self?.altitude = nil; self?.lastAltitudeDate = nil }
    }
}
