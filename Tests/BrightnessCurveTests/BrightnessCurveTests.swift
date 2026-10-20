import XCTest
@testable import BrightnessCurve

final class BrightnessCurveTests: XCTestCase {
    /// MacBook Pro XDR: 1600 nits peak, SDR white 600 nits at the full slider.
    private let curve = BrightnessCurve(peakNits: 1600, referenceEdr: 2.66, encodingGamma: 2.2, maxNits: 1600)

    func testSdrMaxIsPeakOverReferenceEdr() {
        XCTAssertEqual(curve.sdrMaxNits, 1600 / 2.66, accuracy: 0.01)
    }

    func testFullBoostReachesPeak() {
        XCTAssertEqual(curve.nits(level: 1, boost: 1), 1600, accuracy: 1)
    }

    func testNoBoostEqualsNativeRange() {
        XCTAssertEqual(curve.nits(level: 0.5, boost: 0), curve.sdrMaxNits * 0.5, accuracy: 0.01)
    }

    func testSplitRoundTripsAcrossTheWholeScale() {
        for nits in stride(from: Float(10), through: 1600, by: 37) {
            let parts = curve.split(nits: nits)
            XCTAssertEqual(curve.nits(level: parts.level, boost: parts.boost), nits, accuracy: 0.5, "at \(nits)")
        }
    }

    func testSplitBelowBoundaryUsesNoBoost() {
        let parts = curve.split(nits: 300)
        XCTAssertEqual(parts.boost, 0)
        XCTAssertLessThan(parts.level, 1)
    }

    func testSplitAboveBoundaryPinsSliderAtMax() {
        let parts = curve.split(nits: 900)
        XCTAssertEqual(parts.level, 1)
        XCTAssertGreaterThan(parts.boost, 0)
        XCTAssertLessThanOrEqual(parts.boost, 1)
    }

    func testScaleIsMonotonic() {
        var last: Float = -1
        for nits in stride(from: Float(2), through: 1600, by: 5) {
            let parts = curve.split(nits: nits)
            let value = curve.nits(level: parts.level, boost: parts.boost)
            XCTAssertGreaterThanOrEqual(value, last)
            last = value
        }
    }

    func testNativeStepDoesNotOvershootBoundary() {
        let next = curve.stepped(from: curve.sdrMaxNits - 10, up: true, nativeSteps: 16, boostStepNits: 100)
        XCTAssertEqual(next, curve.sdrMaxNits, accuracy: 0.001)
    }

    func testBoostStepIsConfigurable() {
        let from = curve.sdrMaxNits
        XCTAssertEqual(curve.stepped(from: from, up: true, nativeSteps: 16, boostStepNits: 100), from + 100, accuracy: 0.001)
        XCTAssertEqual(curve.stepped(from: from, up: true, nativeSteps: 16, boostStepNits: 10), from + 10, accuracy: 0.001)
    }

    func testBoostStepDownStopsAtBoundary() {
        let next = curve.stepped(from: curve.sdrMaxNits + 30, up: false, nativeSteps: 16, boostStepNits: 100)
        XCTAssertEqual(next, curve.sdrMaxNits, accuracy: 0.001)
    }

    func testFineDivisorShrinksBothSteps() {
        let coarse = curve.stepped(from: 300, up: true, nativeSteps: 16, boostStepNits: 100)
        let fine = curve.stepped(from: 300, up: true, nativeSteps: 16, boostStepNits: 100, fineDivisor: 4)
        XCTAssertEqual(fine - 300, (coarse - 300) / 4, accuracy: 0.001)

        let coarseBoost = curve.stepped(from: 800, up: true, nativeSteps: 16, boostStepNits: 100)
        let fineBoost = curve.stepped(from: 800, up: true, nativeSteps: 16, boostStepNits: 100, fineDivisor: 4)
        XCTAssertEqual(fineBoost - 800, (coarseBoost - 800) / 4, accuracy: 0.001)
    }

    func testStepsNeverExceedTheCap() {
        let capped = BrightnessCurve(peakNits: 1600, referenceEdr: 2.66, encodingGamma: 2.2, maxNits: 1000)
        XCTAssertEqual(capped.stepped(from: 950, up: true, nativeSteps: 16, boostStepNits: 100), 1000, accuracy: 0.001)
        XCTAssertEqual(capped.stepped(from: 1000, up: true, nativeSteps: 16, boostStepNits: 100), 1000, accuracy: 0.001)
    }

    func testStepsNeverGoBelowTheMinimum() {
        let next = curve.stepped(from: 3, up: false, nativeSteps: 16, boostStepNits: 100)
        XCTAssertEqual(next, BrightnessCurve.minNits, accuracy: 0.001)
    }

    func testCapIsClampedToPeak() {
        let over = BrightnessCurve(peakNits: 1600, referenceEdr: 2.66, encodingGamma: 2.2, maxNits: 5000)
        XCTAssertEqual(over.maxNits, 1600)
    }

    func testFractionIsRelativeToTheCap() {
        let capped = BrightnessCurve(peakNits: 1600, referenceEdr: 2.66, encodingGamma: 2.2, maxNits: 1000)
        XCTAssertEqual(capped.fraction(nits: 500), 0.5, accuracy: 0.001)
        XCTAssertEqual(capped.fraction(nits: 1200), 1)
    }

    func testPressingUpFromZeroEventuallyReachesTheCapAndStops() {
        var nits: Float = BrightnessCurve.minNits
        for _ in 0..<500 { nits = curve.stepped(from: nits, up: true, nativeSteps: 16, boostStepNits: 100) }
        XCTAssertEqual(nits, 1600, accuracy: 0.001)
    }
}
