import Foundation

/// An identifier and asynchronous provider for one decoded analysis input.
///
/// Hosts retain ownership of file access, RAW decoding, and source selection.
/// PhotoAnalysisKit invokes providers with bounded concurrency and analyzes the
/// returned `PhotoAnalysisInput` values.
public struct PhotoAnalysisBatchRequest<Identifier: Sendable>: Sendable {
    public let id: Identifier
    private let inputProvider: @Sendable () async -> PhotoAnalysisInput?

    public init(
        id: Identifier,
        inputProvider: @escaping @Sendable () async -> PhotoAnalysisInput?
    ) {
        self.id = id
        self.inputProvider = inputProvider
    }

    fileprivate func loadInput() async -> PhotoAnalysisInput? {
        await inputProvider()
    }
}

/// The analysis associated with one batch request.
///
/// `analysis` is nil when the host input provider could not decode the image.
public struct PhotoAnalysisBatchResult<Identifier: Sendable>: Sendable {
    public let id: Identifier
    public let analysis: PhotoAnalysisResult?

    public init(id: Identifier, analysis: PhotoAnalysisResult?) {
        self.id = id
        self.analysis = analysis
    }
}

/// Completion-order progress emitted while a batch is running.
public struct PhotoAnalysisBatchProgress<Identifier: Sendable>: Sendable {
    public let completedCount: Int
    public let totalCount: Int
    public let result: PhotoAnalysisBatchResult<Identifier>

    public init(
        completedCount: Int,
        totalCount: Int,
        result: PhotoAnalysisBatchResult<Identifier>
    ) {
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.result = result
    }
}

extension PhotoAnalyzer {
    /// Analyzes asynchronously supplied inputs with bounded concurrency.
    ///
    /// Progress is emitted in completion order. Successful completion returns
    /// one result per request in the original request order. A nil return means
    /// the parent task was cancelled and partial results should be discarded.
    public func analyzeBatch<Identifier: Sendable>(
        _ requests: [PhotoAnalysisBatchRequest<Identifier>],
        configuration: SharpnessConfiguration = .birdsInFlight,
        maximumConcurrentTasks: Int = 8,
        progress: (@Sendable (PhotoAnalysisBatchProgress<Identifier>) async -> Void)? = nil
    ) async -> [PhotoAnalysisBatchResult<Identifier>]? {
        guard !requests.isEmpty else { return [] }
        guard !Task.isCancelled else { return nil }

        let concurrency = max(1, min(maximumConcurrentTasks, requests.count))
        return await withTaskGroup(
            of: (index: Int, result: PhotoAnalysisBatchResult<Identifier>).self
        ) { group in
            var nextIndex = 0
            var completedCount = 0
            var orderedResults = [PhotoAnalysisBatchResult<Identifier>?](
                repeating: nil,
                count: requests.count
            )

            func enqueue(_ index: Int) {
                let request = requests[index]
                group.addTask(priority: .userInitiated) {
                    guard !Task.isCancelled,
                          let input = await request.loadInput(),
                          !Task.isCancelled
                    else {
                        return (
                            index,
                            PhotoAnalysisBatchResult(id: request.id, analysis: nil)
                        )
                    }

                    let analysis = await analyze(
                        input,
                        configuration: configuration
                    )
                    return (
                        index,
                        PhotoAnalysisBatchResult(
                            id: request.id,
                            analysis: Task.isCancelled ? nil : analysis
                        )
                    )
                }
            }

            for _ in 0 ..< concurrency {
                enqueue(nextIndex)
                nextIndex += 1
            }

            while let completed = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return nil
                }

                orderedResults[completed.index] = completed.result
                completedCount += 1
                await progress?(
                    PhotoAnalysisBatchProgress(
                        completedCount: completedCount,
                        totalCount: requests.count,
                        result: completed.result
                    )
                )

                guard !Task.isCancelled else {
                    group.cancelAll()
                    return nil
                }

                if nextIndex < requests.count {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }

            guard !Task.isCancelled else { return nil }
            return orderedResults.compactMap { $0 }
        }
    }

    /// Loads host-provided inputs with bounded concurrency before applying the
    /// package calibration pipeline.
    public func calibrate<Identifier: Sendable>(
        from requests: [PhotoAnalysisBatchRequest<Identifier>],
        baseConfiguration: SharpnessConfiguration = .birdsInFlight,
        thresholdPercentile: Float = 0.90,
        minimumSuccessfulImages: Int = 5,
        maximumConcurrentTasks: Int = 8
    ) async -> FocusCalibrationResult? {
        guard let inputs = await loadInputs(
            from: requests,
            maximumConcurrentTasks: maximumConcurrentTasks
        ) else { return nil }

        return await calibrate(
            from: inputs,
            baseConfiguration: baseConfiguration,
            thresholdPercentile: thresholdPercentile,
            minimumSuccessfulImages: minimumSuccessfulImages,
            maximumConcurrentTasks: maximumConcurrentTasks
        )
    }

    private func loadInputs<Identifier: Sendable>(
        from requests: [PhotoAnalysisBatchRequest<Identifier>],
        maximumConcurrentTasks: Int
    ) async -> [PhotoAnalysisInput]? {
        guard !requests.isEmpty else { return [] }
        guard !Task.isCancelled else { return nil }

        let concurrency = max(1, min(maximumConcurrentTasks, requests.count))
        return await withTaskGroup(
            of: (index: Int, input: PhotoAnalysisInput?).self
        ) { group in
            var nextIndex = 0
            var orderedInputs = [PhotoAnalysisInput?](
                repeating: nil,
                count: requests.count
            )

            func enqueue(_ index: Int) {
                let request = requests[index]
                group.addTask {
                    (index, await request.loadInput())
                }
            }

            for _ in 0 ..< concurrency {
                enqueue(nextIndex)
                nextIndex += 1
            }

            while let loaded = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return nil
                }
                orderedInputs[loaded.index] = loaded.input

                if nextIndex < requests.count {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }

            guard !Task.isCancelled else { return nil }
            return orderedInputs.compactMap { $0 }
        }
    }
}
