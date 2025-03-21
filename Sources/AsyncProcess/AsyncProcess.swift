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

// MARK: - AsyncProcess Definition

public final class AsyncProcess: Sendable {

    // MARK: AsyncProcess.State Definition

    private struct State: Sendable {

        // MARK: Properties

        var executable: Executable
        var standardInput: InputHandle?
        var standardOutput: OutputHandle?
        var standardError: OutputHandle?

        // MARK: Initialization

        init(executable: Executable,
             standardInput: InputHandle? = nil,
             standardOutput: OutputHandle? = nil,
             standardError: OutputHandle? = nil) {
            self.executable = executable
            self.standardInput = standardInput
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }

    // MARK: Private Properties

    private let state: Lock<State>

    // MARK: Internal Properties

    @usableFromInline
    internal let runner = AsyncProcessRunner()

    @inline(__always)
    internal var process: Process { runner.process }

    // MARK: Public Properties

    public final var executable: Executable {
        get { state.withLock(\.executable) }
        set {
            process.executableURL = executable.url
            state.withLock { $0.executable = newValue }
        }
    }

    @inline(__always)
    public final var arguments: [String] {
        get { process.arguments ?? [] }
        set { process.arguments = newValue }
    }

    @inline(__always)
    public final var environment: [String: String] {
        get { process.environment ?? [:] }
        set { process.environment = newValue }
    }

    @inline(__always)
    public final var currentDirectory: URL? {
        get { process.currentDirectoryURL }
        set { process.currentDirectoryURL = newValue }
    }

    public final var standardInput: InputHandle? {
        get { state.withLock(\.standardInput) }
        set {
            process.standardInput = newValue?.rawHandle
            state.withLock { $0.standardInput = newValue }
        }
    }

    public final var standardOutput: OutputHandle? {
        get { state.withLock(\.standardOutput) }
        set {
            process.standardOutput = newValue?.rawHandle
            state.withLock { $0.standardOutput = newValue }
        }
    }

    public final var standardError: OutputHandle? {
        get { state.withLock(\.standardError) }
        set {
            process.standardError = newValue?.rawHandle
            state.withLock { $0.standardError = newValue }
        }
    }

    @inline(__always)
    public final var processIdentifier: Int {
        Int(process.processIdentifier)
    }

    @inline(__always)
    public final var qualityOfService: QualityOfService {
        get { process.qualityOfService }
        set { process.qualityOfService = newValue }
    }

    @inline(__always)
    public final var isRunning: Bool {
        get async { await runner.isRunning }
    }

    @inline(__always)
    public final var terminationStatus: Int? {
        get async { await runner.terminationStatus }
    }

    @inline(__always)
    public final var terminationReason: Process.TerminationReason? {
        get async { await runner.terminationReason }
    }

    // MARK: Initialization

    public init(executable: Executable = .default) {
        self.state = Lock(initialState: State(executable: executable))
        self.process.executableURL = executable.url
    }

    // MARK: Public Methods

    #if compiler(>=6.0)
    @inline(__always)
    public final func run() async throws(AsyncProcessError) {
        try await runner.run()
    }
    #else
    @inline(__always)
    public final func run() async throws {
        try await runner.run()
    }
    #endif
}
