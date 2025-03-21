//
//  UncaughtSignalHandler.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

import Atomics
@preconcurrency import Dispatch
import Foundation

// MARK: UncaughtSignalHandler Definition

@usableFromInline
internal final class UncaughtSignalHandler: @unchecked Sendable {

    // MARK: Private Constants

    private static let knownSignals: Set<Int32> = {
        var knownSignals: Set<Int32> = [
            SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGTRAP, SIGABRT,
            SIGIOT,
            SIGFPE, /*SIGKILL, this signal cannot be caught */ SIGBUS, SIGSEGV, SIGSYS, SIGPIPE, SIGALRM, SIGTERM, SIGURG, SIGSTOP, SIGTSTP, SIGCONT, SIGCHLD, SIGTTIN, SIGTTOU,
            SIGIO,
            SIGXCPU, SIGXFSZ, SIGVTALRM, SIGPROF,
            SIGWINCH,
        ]

        #if os(macOS)
        // `SIGEMT` and `SIGINFO` are not known in Linux
        knownSignals.formUnion([SIGEMT, SIGINFO])
        #endif

        return knownSignals
    }()

    // MARK: Private Properties

    private let signalsToCatch: Set<Int32>
    private let processingQueue: DispatchQueue
    private let dispatchSources: [DispatchSourceSignal]
    private let _isCancelled = ManagedAtomic(false)

    // MARK: Internal Properties

    @usableFromInline
    internal final var isCancelled: Bool {
        _isCancelled.load(ordering: .acquiring)
    }

    // MARK: Initialization

    @usableFromInline
    internal init<S>(signalsToCatch: S,
                     callbackQueue: DispatchQueue? = nil,
                     qos: DispatchQoS = .unspecified,
                     flags: DispatchWorkItemFlags = [],
                     signalHandler: @escaping @Sendable (Int32) -> Void) where S: Sequence, S.Element == Int32 {
        let processingQueue = DispatchQueue(label: "com.somerandomiosdev.asyncprocess.uncaughtsignalhandler", qos: qos, target: callbackQueue)
        let signalsToCatch = Self.knownSignals.intersection(signalsToCatch)

        precondition(!signalsToCatch.isEmpty, "Must provide a non-empty set of signals to catch")

        self.signalsToCatch = signalsToCatch
        self.processingQueue = processingQueue
        self.dispatchSources = signalsToCatch.map { sig in
            // Setup dispatch source to listen for this signal
            let source = DispatchSource.makeSignalSource(signal: sig, queue: processingQueue)
            var previousSignalHandler: sig_t?

            // Setup the handlers for processing this signal
            source.setRegistrationHandler(qos: qos, flags: flags) {
                // Ignore invocations of this signal since we setup a handler for it.
                previousSignalHandler = signal(sig, SIG_IGN)
            }
            source.setCancelHandler(qos: qos, flags: flags) {
                // Restore the previous signal handler since we aren't processing it anymore.
                signal(sig, previousSignalHandler ?? SIG_DFL)
            }
            source.setEventHandler(qos: qos, flags: flags) {
                // Call the handler with the caught signal.
                signalHandler(sig)
            }

            return source
        }
    }

    deinit {
        cancel(asynchronous: false)
    }

    // MARK: Internal Methods

    @usableFromInline
    internal final func activate(asynchronous: Bool = true) {
        performOnSources(asynchronous: asynchronous) { $0.activate() }
    }

    @usableFromInline
    internal final func cancel(asynchronous: Bool = true) {
        performOnSources(
            asynchronous: asynchronous,
            condition: _isCancelled.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing).exchanged,
            work: { $0.cancel() }
        )
    }

    @usableFromInline
    internal final func resume(asynchronous: Bool = true) {
        performOnSources(asynchronous: asynchronous) { $0.resume() }
    }

    @usableFromInline
    internal final func suspend(asynchronous: Bool = true) {
        performOnSources(asynchronous: asynchronous) { $0.suspend() }
    }

    // MARK: Private Methods

    private final func performOnSources(asynchronous: Bool, condition: @autoclosure @Sendable () -> Bool = true, work: @escaping @Sendable (DispatchSourceSignal) -> Void) {
        guard condition() else { return }
        let work = { @Sendable [dispatchSources] in dispatchSources.forEach(work) }

        if asynchronous {
            processingQueue.async(flags: .barrier, execute: work)
        } else {
            processingQueue.sync(flags: .barrier, execute: work)
        }
    }
}
