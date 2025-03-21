//
//  AsyncProcess.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

#if compiler(<6.0)
@preconcurrency
#endif
import Foundation

// MARK: - AsyncProcessRunner Extension

@usableFromInline
internal actor AsyncProcessRunner {

    // MARK: Properties

    @usableFromInline
    nonisolated internal let process: Process

    @usableFromInline
    internal var isRunning: Bool { process.isRunning }

    @usableFromInline
    internal private(set) var terminationStatus: Int?

    @usableFromInline
    internal private(set) var terminationReason: Process.TerminationReason?

    @usableFromInline
    internal private(set) var caughtSignal: Int?

    // MARK: Initialization

    internal init() {
        self.process = Process()
    }

    // MARK: Internal Methods

    #if compiler(>=6.0)
    @usableFromInline
    internal func run() async throws(AsyncProcessError) {
        guard !isRunning else { throw AsyncProcessError.processIsRunning }
        guard terminationStatus == nil else { throw AsyncProcessError.processFinished }

        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AsyncProcessError>, Never>) in
            let signalHandler = UncaughtSignalHandler(signalsToCatch: [SIGINT, SIGTERM], qos: .userInitiated) { [process] signal in
                Task { [weak self] in
                    guard let self else { return }
                    await withIsolation { $0.caughtSignal = Int(signal) }
                }

                // If we received an interrupt (Ctrl + C) we send both the interrupt and terminate
                // signals since some processes don't listen for the interrupt signals.
                if signal == SIGINT {
                    process.interrupt()
                }
                process.terminate()
            }

            // Start listening for the signals
            signalHandler.activate()

            // Setup the termination handler for the process
            process.terminationHandler = { process in
                let terminationStatus = Int(process.terminationStatus)
                signalHandler.cancel()

                Task { [weak self] in
                    guard let self else { return }
                    await withIsolation {
                        $0.terminationStatus = terminationStatus
                        $0.terminationReason = process.terminationReason
                    }

                    if let caughtSignal = await caughtSignal {
                        continuation.resume(returning: .failure(AsyncProcessError.uncaughtSignal(signal: caughtSignal)))
                    } else if terminationStatus != 0 {
                        continuation.resume(returning: .failure(AsyncProcessError.terminated(code: terminationStatus)))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }

            do {
                try process.run()
            } catch let error as AsyncProcessError {
                continuation.resume(returning: .failure(error))
            } catch {
                continuation.resume(returning: .failure(.processError(error)))
            }
        }.get()
    }

    @usableFromInline
    internal nonisolated func withIsolation<R, E>(_ perform: @Sendable (isolated AsyncProcessRunner) async throws(E) -> sending R) async throws(E) -> sending R {
        try await _withIsolation(perform)
    }
    #else
    @usableFromInline
    internal func run() async throws {
        guard !isRunning else { throw AsyncProcessError.processIsRunning }
        guard terminationStatus == nil else { throw AsyncProcessError.processFinished }

        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AsyncProcessError>, Never>) in
            let signalHandler = UncaughtSignalHandler(signalsToCatch: [SIGINT, SIGTERM], qos: .userInitiated) { [process] signal in
                Task { [weak self] in
                    guard let self else { return }
                    await withIsolation { $0.caughtSignal = Int(signal) }
                }

                // If we received an interrupt (Ctrl + C) we send both the interrupt and terminate
                // signals since some processes don't listen for the interrupt signals.
                if signal == SIGINT {
                    process.interrupt()
                }
                process.terminate()
            }

            // Start listening for the signals
            signalHandler.activate()

            // Setup the termination handler for the process
            process.terminationHandler = { process in
                let terminationStatus = Int(process.terminationStatus)
                signalHandler.cancel()

                Task { [weak self] in
                    guard let self else { return }
                    await withIsolation {
                        $0.terminationStatus = terminationStatus
                        $0.terminationReason = process.terminationReason
                    }

                    if let caughtSignal = await caughtSignal {
                        continuation.resume(returning: .failure(AsyncProcessError.uncaughtSignal(signal: caughtSignal)))
                    } else if terminationStatus != 0 {
                        continuation.resume(returning: .failure(AsyncProcessError.terminated(code: terminationStatus)))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }

            do {
                try process.run()
            } catch let error as AsyncProcessError {
                continuation.resume(returning: .failure(error))
            } catch {
                continuation.resume(returning: .failure(.processError(error)))
            }
        }.get()
    }

    @usableFromInline
    internal nonisolated func withIsolation<R>(_ perform: @Sendable (isolated AsyncProcessRunner) async throws -> R) async rethrows -> R where R: Sendable {
        try await _withIsolation(perform)
    }
    #endif

    // MARK: Private Methods

    #if compiler(>=6.0)
    private func _withIsolation<R, E>(_ perform: @Sendable (isolated AsyncProcessRunner) async throws(E) -> sending R) async throws(E) -> sending R {
        try await perform(self)
    }
    #else
    private func _withIsolation<R>(_ perform: @Sendable (isolated AsyncProcessRunner) async throws -> R) async rethrows -> R where R: Sendable {
        try await perform(self)
    }
    #endif
}
