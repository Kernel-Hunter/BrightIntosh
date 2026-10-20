//
//  BrightnessCurve.swift
//  BrightIntosh
//
//  Pure model for the unified brightness scale, in nits. No AppKit, so it can
//  be unit tested with `swift test`.
//
//  The scale has two parts:
//    - native range: 0 ... sdrMaxNits, driven by the system brightness slider
//    - boost range:  sdrMaxNits ... maxNits, driven by the gamma boost
//
//  Nits are a model, not a measurement. SDR white at the full slider is
//  peak / referenceEdr, scaled linearly by the slider. Gamma tables scale the
//  encoded signal, so light output grows as factor^encodingGamma.
//

import Foundation

struct BrightnessCurve: Equatable {
    /// Peak luminance of the panel in nits (small HDR highlights).
    var peakNits: Float
    /// Peak divided by SDR white at the full slider.
    var referenceEdr: Float
    /// Exponent between the gamma-table factor and emitted light.
    var encodingGamma: Float
    /// User cap. Clamped to `peakNits`.
    var maxNits: Float

    static let minNits: Float = 2

    init(peakNits: Float, referenceEdr: Float, encodingGamma: Float, maxNits: Float) {
        self.peakNits = peakNits
        self.referenceEdr = referenceEdr
        self.encodingGamma = encodingGamma
        self.maxNits = min(max(maxNits, Self.minNits), peakNits)
    }

    /// SDR white at the full system slider.
    var sdrMaxNits: Float { peakNits / referenceEdr }

    /// Gamma factor above 1 that reaches the panel peak.
    var bonus: Float { pow(referenceEdr, 1 / encodingGamma) - 1 }

    /// Nits for a system slider level (0...1) and a boost fraction (0...1).
    func nits(level: Float, boost: Float) -> Float {
        let factor = 1 + bonus * min(max(boost, 0), 1)
        return sdrMaxNits * min(max(level, 0), 1) * pow(factor, encodingGamma)
    }

    /// Inverse of `nits(level:boost:)`: the slider level and boost fraction.
    func split(nits: Float) -> (level: Float, boost: Float) {
        if nits <= sdrMaxNits { return (max(nits / sdrMaxNits, 0), 0) }
        let factor = pow(nits / sdrMaxNits, 1 / encodingGamma)
        return (1, min(max((factor - 1) / bonus, 0), 1))
    }

    /// 0...1 share of the user cap, for the bar and the percentage.
    func fraction(nits: Float) -> Float {
        min(max(nits / maxNits, 0), 1)
    }

    /// Next target after one key press.
    ///
    /// - nativeSteps: key presses from 0 to `sdrMaxNits`
    /// - boostStepNits: nits per press above `sdrMaxNits`
    /// - fineDivisor: divides both steps (for the fine-step modifier)
    ///
    /// The boundary at `sdrMaxNits` is always reachable: a native step never
    /// overshoots it and a boost step down never undershoots it.
    func stepped(from nits: Float, up: Bool, nativeSteps: Int, boostStepNits: Float, fineDivisor: Float = 1) -> Float {
        let divisor = max(fineDivisor, 1)
        let native = sdrMaxNits / Float(max(nativeSteps, 1)) / divisor
        let boost = max(boostStepNits, 1) / divisor
        let cap = max(maxNits, Self.minNits)

        if up {
            if nits < sdrMaxNits - 0.5 { return min(nits + native, sdrMaxNits, cap) }
            return min(nits + boost, cap)
        }
        if nits > sdrMaxNits + 0.5 { return max(nits - boost, min(sdrMaxNits, cap)) }
        return max(nits - native, Self.minNits)
    }
}
