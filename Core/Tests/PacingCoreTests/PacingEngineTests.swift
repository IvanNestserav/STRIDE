import XCTest
@testable import PacingCore
final class PacingEngineTests: XCTestCase {
 func testBehind() {
  let r = PacingEngine.evaluate(goalMeters:5000, goalSeconds:1800, distance:2000, elapsed:780, speed:1000/370)
  XCTAssertEqual(r.state,.faster); XCTAssertEqual(r.requiredSecondsPerKM!,340,accuracy:0.001)
 }
 func testAheadButFading() {
  XCTAssertEqual(PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:2000,elapsed:660,speed:1000/420).state,.faster)
 }
 func testAheadCanEase() {
  let r = PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:2000,elapsed:660,speed:1000/330)
  XCTAssertEqual(r.state,.ease); XCTAssertEqual(r.requiredSecondsPerKM!,380,accuracy:0.001)
 }
 func testHold() { XCTAssertEqual(PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:2000,elapsed:720,speed:1000/360).state,.hold) }
 func testFinishAndExpiry() {
  XCTAssertEqual(PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:5000,elapsed:1805,speed:3).state,.complete)
  XCTAssertEqual(PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:4000,elapsed:1800,speed:3).state,.expired)
 }
 func testNoReliableSpeed() { XCTAssertEqual(PacingEngine.evaluate(goalMeters:5000,goalSeconds:1800,distance:500,elapsed:180,speed:3,valid:false).state,.waiting) }
}
