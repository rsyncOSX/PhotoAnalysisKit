import Foundation
import PhotoAnalysisKit
import Testing

@Suite("PhotoAnalyzer batch analysis")
struct PhotoAnalysisBatchTests {
    @Test("Batch results preserve request order and report every completion")
    func preservesRequestOrder() async throws {
        let image = try #require(makeCheckerboardImage())
        let progress = BatchProgressProbe()
        var configuration = SharpnessConfiguration.birdsInFlight
        configuration.enableSubjectClassification = false
        let requests = [0, 1, 2].map { id in
            PhotoAnalysisBatchRequest(id: id) {
                try? await Task.sleep(
                    for: .milliseconds((3 - id) * 10)
                )
                return PhotoAnalysisInput(image: image, iso: 400 + id * 100)
            }
        }

        let results = await PhotoAnalyzer().analyzeBatch(
            requests,
            configuration: configuration,
            maximumConcurrentTasks: 3
        ) { update in
            await progress.record(update.result.id)
        }

        let completed = try #require(results)
        #expect(completed.map(\.id) == [0, 1, 2])
        #expect(completed.allSatisfy { $0.analysis?.score != nil })
        #expect(Set(await progress.identifiers) == Set([0, 1, 2]))
    }

    @Test("Batch input loading respects the concurrency limit")
    func boundedConcurrency() async throws {
        let image = try #require(makeCheckerboardImage())
        let probe = BatchConcurrencyProbe()
        var configuration = SharpnessConfiguration.birdsInFlight
        configuration.enableSubjectClassification = false
        let requests = (0 ..< 6).map { id in
            PhotoAnalysisBatchRequest(id: id) {
                await probe.enter()
                try? await Task.sleep(for: .milliseconds(20))
                await probe.leave()
                return PhotoAnalysisInput(image: image)
            }
        }

        let results = await PhotoAnalyzer().analyzeBatch(
            requests,
            configuration: configuration,
            maximumConcurrentTasks: 2
        )

        #expect(try #require(results).count == 6)
        #expect(await probe.maximumActive == 2)
    }

    @Test("Decode failures retain their request identity")
    func decodeFailure() async throws {
        let image = try #require(makeCheckerboardImage())
        var configuration = SharpnessConfiguration.birdsInFlight
        configuration.enableSubjectClassification = false
        let requests = [
            PhotoAnalysisBatchRequest(id: "decoded") {
                PhotoAnalysisInput(image: image)
            },
            PhotoAnalysisBatchRequest(id: "missing") {
                nil
            },
        ]

        let results = try #require(
            await PhotoAnalyzer().analyzeBatch(
                requests,
                configuration: configuration
            )
        )

        #expect(results.map(\.id) == ["decoded", "missing"])
        #expect(results[0].analysis?.score != nil)
        #expect(results[1].analysis == nil)
    }

    @Test("Cancelling the parent discards partial batch results")
    func cancellation() async throws {
        let image = try #require(makeCheckerboardImage())
        let gate = BatchCancellationGate()
        let request = PhotoAnalysisBatchRequest(id: 1) {
            await gate.markStarted()
            await gate.waitUntilReleased()
            return PhotoAnalysisInput(image: image)
        }
        let task = Task {
            await PhotoAnalyzer().analyzeBatch([request])
        }

        await gate.waitForStart()
        task.cancel()
        await gate.release()

        #expect(await task.value == nil)
    }

    @Test("Calibration accepts asynchronous input providers")
    func calibrationRequests() async throws {
        let image = try #require(makeCheckerboardImage())
        let requests = (0 ..< 3).map { id in
            PhotoAnalysisBatchRequest(id: id) {
                PhotoAnalysisInput(
                    image: image,
                    iso: 400 + id * 400,
                    aperture: 4 + Double(id)
                )
            }
        }

        let result = await PhotoAnalyzer().calibrate(
            from: requests,
            minimumSuccessfulImages: 3,
            maximumConcurrentTasks: 2
        )

        #expect(try #require(result).sampleCount > 0)
    }
}

private actor BatchProgressProbe {
    private var recordedIdentifiers = [Int]()

    var identifiers: [Int] {
        recordedIdentifiers
    }

    func record(_ identifier: Int) {
        recordedIdentifiers.append(identifier)
    }
}

private actor BatchConcurrencyProbe {
    private var active = 0
    private var observedMaximum = 0

    var maximumActive: Int {
        observedMaximum
    }

    func enter() {
        active += 1
        observedMaximum = max(observedMaximum, active)
    }

    func leave() {
        active -= 1
    }
}

private actor BatchCancellationGate {
    private var started = false
    private var released = false
    private var startWaiters = [CheckedContinuation<Void, Never>]()
    private var releaseWaiters = [CheckedContinuation<Void, Never>]()

    func markStarted() {
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitForStart() async {
        if started {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func waitUntilReleased() async {
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
