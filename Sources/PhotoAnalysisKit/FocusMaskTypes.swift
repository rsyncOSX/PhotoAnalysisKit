import CoreGraphics
import Foundation

public struct SaliencySummary: Codable, Equatable, Sendable {
    public let subjectLabel: String?
    public let subjectConfidence: Float?

    public init(subjectLabel: String?, subjectConfidence: Float? = nil) {
        self.subjectLabel = subjectLabel
        self.subjectConfidence = subjectConfidence
    }
}

public struct SaliencyCandidate: Equatable, Sendable {
    public nonisolated let normalizedRect: CGRect
    public nonisolated let confidence: Float
}

public struct SaliencyDetection: Sendable {
    public nonisolated let candidates: [SaliencyCandidate]
    public nonisolated let saliencyInfo: SaliencySummary?
}

public struct SaliencySelection: Equatable, Sendable {
    public nonisolated let candidateCount: Int
    public nonisolated let winningRegion: CGRect?
    public nonisolated let reason: String?
}

public enum FocusFailureKind: String, Codable, Equatable, Sendable {
    case none
    case motionBlur
    case missedFocus

}

public enum FocusMaskRegionSource: String, Codable, Equatable, Sendable {
    case none
    case saliency
    case afPoint
    case saliencyAndAF

}

public enum FocusEvidenceRegion: String, Codable, Equatable, Sendable {
    case none
    case afCenter
    case afNeighborhood
    case afPoint
    case saliency
    case global
    case mixed

    public nonisolated var isAFAnchored: Bool {
        switch self {
        case .afCenter, .afNeighborhood, .afPoint:
            true

        case .none, .saliency, .global, .mixed:
            false
        }
    }
}

public enum FocusEvidenceOverlayStyle: String, Codable, Equatable, Sendable {
    case subjectEdges
    case globalEdges

}

public enum FocusEvidenceConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

}

public struct FocusPatchRanking: Equatable, Sendable {
    public nonisolated let normalizedRect: CGRect
    public nonisolated let robustTailScore: Float
    public nonisolated let microContrast: Float
    public nonisolated let coverage: Float
    public nonisolated let distanceToAF: Float?
    public nonisolated let silhouetteFraction: Float
    public nonisolated let ringDetailScore: Float
    public nonisolated let compactDetailScore: Float
    public nonisolated let linearEdgePenalty: Float
    public nonisolated let belowAFPenalty: Float
    public nonisolated let eyeHeadHeuristicAdjustment: Float
    public nonisolated let compositeScore: Float
    public nonisolated let containsAFPoint: Bool

    public nonisolated init(
        normalizedRect: CGRect,
        robustTailScore: Float,
        microContrast: Float,
        coverage: Float,
        distanceToAF: Float?,
        silhouetteFraction: Float,
        ringDetailScore: Float = 0,
        compactDetailScore: Float = 0,
        linearEdgePenalty: Float = 0,
        belowAFPenalty: Float = 0,
        eyeHeadHeuristicAdjustment: Float = 0,
        compositeScore: Float,
        containsAFPoint: Bool,
    ) {
        self.normalizedRect = normalizedRect
        self.robustTailScore = robustTailScore
        self.microContrast = microContrast
        self.coverage = coverage
        self.distanceToAF = distanceToAF
        self.silhouetteFraction = silhouetteFraction
        self.ringDetailScore = ringDetailScore
        self.compactDetailScore = compactDetailScore
        self.linearEdgePenalty = linearEdgePenalty
        self.belowAFPenalty = belowAFPenalty
        self.eyeHeadHeuristicAdjustment = eyeHeadHeuristicAdjustment
        self.compositeScore = compositeScore
        self.containsAFPoint = containsAFPoint
    }

    public nonisolated static func == (lhs: FocusPatchRanking, rhs: FocusPatchRanking) -> Bool {
        lhs.normalizedRect == rhs.normalizedRect
            && lhs.robustTailScore == rhs.robustTailScore
            && lhs.microContrast == rhs.microContrast
            && lhs.coverage == rhs.coverage
            && lhs.distanceToAF == rhs.distanceToAF
            && lhs.silhouetteFraction == rhs.silhouetteFraction
            && lhs.ringDetailScore == rhs.ringDetailScore
            && lhs.compactDetailScore == rhs.compactDetailScore
            && lhs.linearEdgePenalty == rhs.linearEdgePenalty
            && lhs.belowAFPenalty == rhs.belowAFPenalty
            && lhs.eyeHeadHeuristicAdjustment == rhs.eyeHeadHeuristicAdjustment
            && lhs.compositeScore == rhs.compositeScore
            && lhs.containsAFPoint == rhs.containsAFPoint
    }
}

public struct FocusEvidence: Equatable, Sendable {
    public nonisolated let winningRegion: FocusEvidenceRegion
    public nonisolated let afCenterScore: Float?
    public nonisolated let afNeighborhoodScore: Float?
    public nonisolated var effectiveVisualThreshold: Float?
    public nonisolated var maskCoverage: Float?
    public nonisolated var relaxedForVisibility: Bool
    public nonisolated var visualizedRegion: FocusEvidenceRegion?
    public nonisolated var afDistanceFromCentroid: Float?
    public nonisolated var patchRankings: [FocusPatchRanking]
    public nonisolated var overlayStyle: FocusEvidenceOverlayStyle?
    public nonisolated var focusEvidenceConfidence: FocusEvidenceConfidence?
    public nonisolated var focusEvidenceConfidenceReason: String?
    public nonisolated var spatialAlignmentScore: Float?
    public nonisolated var localPatchDominance: Float?
    public nonisolated var silhouettePenaltyApplied: Bool
    public nonisolated var scoringAFLocalPatchScore: Float?
    public nonisolated var scoringSubjectInteriorPatchScore: Float?
    public nonisolated var scoringLocalDetailScore: Float?
    public nonisolated var saliencyCandidateCount: Int
    public nonisolated var winningSaliencyRect: CGRect?
    public nonisolated var saliencySelectionReason: String?

    public nonisolated init(
        winningRegion: FocusEvidenceRegion,
        afCenterScore: Float? = nil,
        afNeighborhoodScore: Float? = nil,
        effectiveVisualThreshold: Float? = nil,
        maskCoverage: Float? = nil,
        relaxedForVisibility: Bool = false,
        visualizedRegion: FocusEvidenceRegion? = nil,
        afDistanceFromCentroid: Float? = nil,
        patchRankings: [FocusPatchRanking] = [],
        overlayStyle: FocusEvidenceOverlayStyle? = nil,
        focusEvidenceConfidence: FocusEvidenceConfidence? = nil,
        focusEvidenceConfidenceReason: String? = nil,
        spatialAlignmentScore: Float? = nil,
        localPatchDominance: Float? = nil,
        silhouettePenaltyApplied: Bool = false,
        scoringAFLocalPatchScore: Float? = nil,
        scoringSubjectInteriorPatchScore: Float? = nil,
        scoringLocalDetailScore: Float? = nil,
        saliencyCandidateCount: Int = 0,
        winningSaliencyRect: CGRect? = nil,
        saliencySelectionReason: String? = nil,
    ) {
        self.winningRegion = winningRegion
        self.afCenterScore = afCenterScore
        self.afNeighborhoodScore = afNeighborhoodScore
        self.effectiveVisualThreshold = effectiveVisualThreshold
        self.maskCoverage = maskCoverage
        self.relaxedForVisibility = relaxedForVisibility
        self.visualizedRegion = visualizedRegion
        self.afDistanceFromCentroid = afDistanceFromCentroid
        self.patchRankings = patchRankings
        self.overlayStyle = overlayStyle
        self.focusEvidenceConfidence = focusEvidenceConfidence
        self.focusEvidenceConfidenceReason = focusEvidenceConfidenceReason
        self.spatialAlignmentScore = spatialAlignmentScore
        self.localPatchDominance = localPatchDominance
        self.silhouettePenaltyApplied = silhouettePenaltyApplied
        self.scoringAFLocalPatchScore = scoringAFLocalPatchScore
        self.scoringSubjectInteriorPatchScore = scoringSubjectInteriorPatchScore
        self.scoringLocalDetailScore = scoringLocalDetailScore
        self.saliencyCandidateCount = saliencyCandidateCount
        self.winningSaliencyRect = winningSaliencyRect
        self.saliencySelectionReason = saliencySelectionReason
    }
}

public struct SharpnessBreakdown: Equatable, Sendable {
    public let finalScore: Float
    public let globalScore: Float?
    public let subjectScore: Float?
    public let afPointScore: Float?
    public let blurGateSigma: Float
    public let subjectLabel: String?
    public let subjectConfidence: Float?
    public let focusFailureKind: FocusFailureKind
    public var focusMaskRegionSource: FocusMaskRegionSource?
    public var focusMaskVisualThreshold: Float?
    public var focusEvidence: FocusEvidence?

    public init(
        finalScore: Float,
        globalScore: Float?,
        subjectScore: Float?,
        afPointScore: Float?,
        blurGateSigma: Float,
        subjectLabel: String?,
        subjectConfidence: Float?,
        focusFailureKind: FocusFailureKind,
        focusMaskRegionSource: FocusMaskRegionSource? = nil,
        focusMaskVisualThreshold: Float? = nil,
        focusEvidence: FocusEvidence? = nil
    ) {
        self.finalScore = finalScore
        self.globalScore = globalScore
        self.subjectScore = subjectScore
        self.afPointScore = afPointScore
        self.blurGateSigma = blurGateSigma
        self.subjectLabel = subjectLabel
        self.subjectConfidence = subjectConfidence
        self.focusFailureKind = focusFailureKind
        self.focusMaskRegionSource = focusMaskRegionSource
        self.focusMaskVisualThreshold = focusMaskVisualThreshold
        self.focusEvidence = focusEvidence
    }
}
