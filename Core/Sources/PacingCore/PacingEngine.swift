import Foundation
public enum Guidance: String, Codable { case complete, expired, waiting, faster, ease, hold }
public struct PaceResult {
    public let state: Guidance
    public let requiredSecondsPerKM: Double?
    public let projectedSeconds: Double?
    public let bufferSeconds: Double?
}
public enum PacingEngine {
    public static func evaluate(goalMeters: Double, goalSeconds: Double, distance: Double, elapsed: Double, speed: Double, valid: Bool = true) -> PaceResult {
        guard [goalMeters, goalSeconds, distance, elapsed, speed].allSatisfy({ $0.isFinite }), goalMeters > 0, goalSeconds > 0, distance >= 0, elapsed >= 0, speed >= 0 else {
            return PaceResult(state: .waiting, requiredSecondsPerKM: nil, projectedSeconds: nil, bufferSeconds: nil)
        }
        let remaining = max(0, goalMeters - distance), left = goalSeconds - elapsed
        if remaining == 0 { return PaceResult(state: .complete, requiredSecondsPerKM: nil, projectedSeconds: elapsed, bufferSeconds: goalSeconds - elapsed) }
        let predicted = speed > 0 ? elapsed + remaining / speed : nil
        if left <= 0 { return PaceResult(state: .expired, requiredSecondsPerKM: nil, projectedSeconds: predicted, bufferSeconds: nil) }
        let required = left / remaining * 1000
        guard valid, let predicted else { return PaceResult(state: .waiting, requiredSecondsPerKM: required, projectedSeconds: nil, bufferSeconds: nil) }
        let buffer = goalSeconds - predicted
        let tolerance = max(8, min(25, left * 0.015))
        return PaceResult(state: buffer < -tolerance ? .faster : buffer > tolerance ? .ease : .hold, requiredSecondsPerKM: required, projectedSeconds: predicted, bufferSeconds: buffer)
    }
}
