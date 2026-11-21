import Dispatch
import Synchronization

/// Runs Vision work one request at a time, off Swift concurrency's
/// cooperative thread pool.
///
/// `VNImageRequestHandler.perform(_:)` blocks its thread while Vision works,
/// and Vision needs a free pool thread to finish that work. When every pool
/// thread is blocked in Vision, or blocked waiting to start a Vision call, the
/// process stops making progress. The gate avoids both: waiting callers
/// suspend instead of holding a thread, and the Vision work runs on the
/// gate's own serial queue.
///
/// Vision requests and handlers are not `Sendable`, so `body` creates them
/// itself and returns only `Sendable` values. `body` runs outside any task:
/// `Task.isCancelled` is always `false` inside it.
///
/// Never call `run` from inside a body. The inner call would wait for the
/// outer one, which never finishes.
public final class VisionRequestGate: Sendable {
    /// The process-wide gate. Every Vision request in PhotoAnalysisKit uses it.
    public static let shared = VisionRequestGate(label: "PhotoAnalysisKit.VisionRequestGate")

    private let queue: DispatchQueue

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .userInitiated, autoreleaseFrequency: .workItem)
    }

    /// Runs `body` after every earlier body has finished.
    ///
    /// If the calling task is cancelled before `body` starts, `body` is skipped
    /// and this throws `CancellationError`. Once `body` has started it runs to
    /// the end, and its result or error is returned.
    public func run<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        let ticket = Ticket<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard ticket.wait(with: continuation) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                queue.async {
                    guard let continuation = ticket.start() else { return }
                    continuation.resume(with: Result { try body() })
                }
            }
        } onCancel: {
            ticket.cancel()?.resume(throwing: CancellationError())
        }
    }
}

/// One caller's place in the queue. Whoever moves it out of `.waiting`
/// (the queue starting the body, or cancellation) resumes the continuation.
private final class Ticket<T: Sendable>: Sendable {
    private enum State {
        case idle
        case waiting(CheckedContinuation<T, any Error>)
        case started
        case cancelled
    }

    private let state = Mutex(State.idle)

    /// Stores the continuation. Returns `false` if the caller was already cancelled.
    func wait(with continuation: CheckedContinuation<T, any Error>) -> Bool {
        state.withLock { state in
            guard case .idle = state else { return false }
            state = .waiting(continuation)
            return true
        }
    }

    /// Called on the queue. Returns the continuation if the body should run.
    func start() -> CheckedContinuation<T, any Error>? {
        state.withLock { state in
            guard case let .waiting(continuation) = state else { return nil }
            state = .started
            return continuation
        }
    }

    /// Returns the continuation if cancellation won the race with `start()`.
    func cancel() -> CheckedContinuation<T, any Error>? {
        state.withLock { state in
            switch state {
            case .idle:
                state = .cancelled
                return nil
            case let .waiting(continuation):
                state = .cancelled
                return continuation
            case .started, .cancelled:
                return nil
            }
        }
    }
}
