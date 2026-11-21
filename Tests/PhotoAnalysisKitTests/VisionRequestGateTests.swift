import CoreGraphics
import Dispatch
import Foundation
import Synchronization
import Testing
@testable import PhotoAnalysisKit

@Suite("Vision request gate")
struct VisionRequestGateTests {
    @Test("Concurrent callers never overlap")
    func bodiesNeverOverlap() async throws {
        let gate = VisionRequestGate(label: "test.overlap")
        let counts = Mutex((inFlight: 0, peak: 0))
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<32 {
                group.addTask {
                    try await gate.run {
                        counts.withLock {
                            $0.inFlight += 1
                            $0.peak = max($0.peak, $0.inFlight)
                        }
                        Thread.sleep(forTimeInterval: 0.002)
                        counts.withLock { $0.inFlight -= 1 }
                        return index
                    }
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(results.sorted() == Array(0..<32))
        #expect(counts.withLock { $0.peak } == 1)
    }

    @Test("Errors thrown by a body reach the caller")
    func bodyErrorPropagates() async {
        struct Failure: Error {}
        let gate = VisionRequestGate(label: "test.error")
        await #expect(throws: Failure.self) {
            try await gate.run { throw Failure() }
        }
    }

    @Test("Cancellation before the turn throws CancellationError and skips the body")
    func cancellationBeforeTurn() async throws {
        let gate = VisionRequestGate(label: "test.cancel")
        let release = DispatchSemaphore(value: 0)
        let blockerStarted = DispatchSemaphore(value: 0)
        let skippedBodyRan = Mutex(false)

        let blocker = Task {
            try await gate.run {
                blockerStarted.signal()
                release.wait()
            }
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                blockerStarted.wait()
                continuation.resume()
            }
        }

        let waiter = Task {
            try await gate.run { skippedBodyRan.withLock { $0 = true } }
        }
        waiter.cancel()
        await #expect(throws: CancellationError.self) {
            try await waiter.value
        }

        release.signal()
        try await blocker.value
        // A body queued after the cancelled one runs only after the cancelled
        // ticket was drained, so this proves the cancelled body was skipped.
        try await gate.run {}
        #expect(skippedBodyRan.withLock { $0 } == false)
    }

    @Test("A task cancelled before calling run never runs the body")
    func alreadyCancelled() async {
        let gate = VisionRequestGate(label: "test.precancelled")
        let ran = Mutex(false)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await gate.run { ran.withLock { $0 = true } }
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(ran.withLock { $0 } == false)
    }

    @Test("Many concurrent Vision calls finish without exhausting the thread pool",
          .timeLimit(.minutes(1)))
    func manyConcurrentVisionCallsFinish() async throws {
        let image = try #require(makeCheckerboardImage(size: 256))
        let count = ProcessInfo.processInfo.activeProcessorCount * 3
        let finished = try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<count {
                group.addTask {
                    switch index % 4 {
                    case 0:
                        _ = try await VisionFeaturePrintBackend().featurePrint(for: image)
                    case 1:
                        _ = try await FaceEvidenceAnalyzer().analyze(image)
                    case 2:
                        _ = await FocusMaskEngine.detectSaliencyAndClassify(for: image, classify: true)
                    default:
                        _ = try await AnimalCloseUpDetector.regions(in: image)
                    }
                    return 1
                }
            }
            return try await group.reduce(0, +)
        }
        #expect(finished == count)
    }
}
