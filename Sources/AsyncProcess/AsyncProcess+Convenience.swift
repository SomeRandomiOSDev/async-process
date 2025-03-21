//
//  AsyncProcess+Convenience.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

import Foundation

// MARK: - AsyncProcess Extension

extension AsyncProcess {

    // MARK: AsyncProcess.CaptureOutputOptions Definition

    public struct CaptureOutputOptions: OptionSet, Sendable {

        // MARK: RawRepresentable Protocol Requirements

        public var rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        // MARK: Options

        public static let stdout = CaptureOutputOptions(rawValue: 1 << 0)
        public static let stderr = CaptureOutputOptions(rawValue: 1 << 1)

        public static let splitOutput = CaptureOutputOptions(rawValue: 1 << 8)
        public static let stderrInThrownErrors = CaptureOutputOptions(rawValue: 1 << 9)

        // MARK: Masks

        fileprivate static let outputCapturesMask = CaptureOutputOptions(rawValue: 0xF)
        fileprivate static let miscOptionsMask = CaptureOutputOptions(rawValue: 0xF0)
    }

    // MARK: Constants

    @_transparent public static var _argumentsDefault: [String]? { nil }
    @_transparent public static var _environmentDefault: [String: String]? { nil }
    @_transparent public static var _currentDirectoryDefault: URL? { nil }
    @_transparent public static var _qualityOfServiceDefault: QualityOfService? { nil }
    @_transparent public static var _captureOutputDefault: Bool { false }
    @_transparent public static var _captureOutputOptionsDefault: CaptureOutputOptions { [.splitOutput, .stderrInThrownErrors] }

    // MARK: Public Methods

    #if compiler(>=6.0)
    @discardableResult
    public final class func run(executable: Executable,
                                arguments: [String]? = _argumentsDefault,
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        let process = AsyncProcess(executable: executable)

        arguments.map { process.arguments = $0 }
        environment.map { process.environment = $0 }
        currentDirectory.map { process.currentDirectory = $0 }
        qualityOfService.map { process.qualityOfService = $0 }

        let splitOutput = captureOutputOptions.contains(.splitOutput)
        let stderrInThrownErrors = captureOutputOptions.contains(.stderrInThrownErrors)
        let captureStandardOutput = captureOutput && (captureOutputOptions.contains(.stdout) || captureOutputOptions.intersection(.outputCapturesMask).isEmpty)
        let captureStandardError = captureOutput && (captureOutputOptions.contains(.stderr) || captureOutputOptions.intersection(.outputCapturesMask).isEmpty)

        let stdoutBytes = captureStandardOutput ? AsyncBytes(alsoForwardingTo: splitOutput ? .standardOutput : nil) : nil
        let stderrBytes = captureStandardError || stderrInThrownErrors ? AsyncBytes(alsoForwardingTo: splitOutput ? .standardError : nil) : nil

        process.standardOutput = stdoutBytes.map { .bytes($0) }
        process.standardError = stderrBytes.map { .bytes($0) }

        return try await withThrowingTaskGroup(of: Void.self, returning: Result<String, AsyncProcessError>.self) { group in
            let combinedOutput = OutputDataAccumulator()
            let stderrOutput = OutputDataAccumulator()

            group.addTask { try await process.run() }

            if let stdoutBytes {
                group.addTask {
                    for await data in stdoutBytes {
                        await combinedOutput.append(data)
                    }
                }
            }

            if let stderrBytes {
                if stderrInThrownErrors && captureStandardError {
                    group.addTask {
                        for await data in stderrBytes {
                            await combinedOutput.append(data)
                            await stderrOutput.append(data)
                        }
                    }
                } else if stderrInThrownErrors {
                    group.addTask {
                        for await data in stderrBytes {
                            await stderrOutput.append(data)
                        }
                    }
                } else /* if captureStandardError */ {
                    group.addTask {
                        for await data in stderrBytes {
                            await combinedOutput.append(data)
                        }
                    }
                }
            }

            func injectOutput(into error: Error) async -> AsyncProcessError {
                var error = (error as? AsyncProcessError) ?? .processError(error)
                let output: String

                if stderrInThrownErrors {
                    output = await stderrOutput.string
                } else {
                    output = await combinedOutput.string
                }

                if !output.isEmpty {
                    error = AsyncProcessError.errorWithOutput(error: error, output: output)
                }

                return error
            }

            do {
                try await group.waitForAll()

                if captureOutput {
                    return await .success(combinedOutput.string)
                } else {
                    return .success("")
                }
            } catch let error {
                return await .failure(injectOutput(into: error))
            }
        }.get()
    }
    #else
    @discardableResult
    public final class func run(executable: Executable,
                                arguments: [String]? = _argumentsDefault,
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        let process = AsyncProcess(executable: executable)

        arguments.map { process.arguments = $0 }
        environment.map { process.environment = $0 }
        currentDirectory.map { process.currentDirectory = $0 }
        qualityOfService.map { process.qualityOfService = $0 }

        let splitOutput = captureOutputOptions.contains(.splitOutput)
        let stderrInThrownErrors = captureOutputOptions.contains(.stderrInThrownErrors)
        let captureStandardOutput = captureOutput && (captureOutputOptions.contains(.stdout) || captureOutputOptions.intersection(.outputCapturesMask).isEmpty)
        let captureStandardError = captureOutput && (captureOutputOptions.contains(.stderr) || captureOutputOptions.intersection(.outputCapturesMask).isEmpty)

        let stdoutBytes = captureStandardOutput ? AsyncBytes(alsoForwardingTo: splitOutput ? .standardOutput : nil) : nil
        let stderrBytes = captureStandardError || stderrInThrownErrors ? AsyncBytes(alsoForwardingTo: splitOutput ? .standardError : nil) : nil

        process.standardOutput = stdoutBytes.map { .bytes($0) }
        process.standardError = stderrBytes.map { .bytes($0) }

        return try await withThrowingTaskGroup(of: Void.self, returning: Result<String, AsyncProcessError>.self) { group in
            let combinedOutput = OutputDataAccumulator()
            let stderrOutput = OutputDataAccumulator()

            group.addTask { try await process.run() }

            if let stdoutBytes {
                group.addTask {
                    for await data in stdoutBytes {
                        await combinedOutput.append(data)
                    }
                }
            }

            if let stderrBytes {
                if stderrInThrownErrors && captureStandardError {
                    group.addTask {
                        for await data in stderrBytes {
                            await combinedOutput.append(data)
                            await stderrOutput.append(data)
                        }
                    }
                } else if stderrInThrownErrors {
                    group.addTask {
                        for await data in stderrBytes {
                            await stderrOutput.append(data)
                        }
                    }
                } else /* if captureStandardError */ {
                    group.addTask {
                        for await data in stderrBytes {
                            await combinedOutput.append(data)
                        }
                    }
                }
            }

            func injectOutput(into error: Error) async -> AsyncProcessError {
                var error = (error as? AsyncProcessError) ?? .processError(error)
                let output: String

                if stderrInThrownErrors {
                    output = await stderrOutput.string
                } else {
                    output = await combinedOutput.string
                }

                if !output.isEmpty {
                    error = AsyncProcessError.errorWithOutput(error: error, output: output)
                }

                return error
            }

            do {
                try await group.waitForAll()

                if captureOutput {
                    return await .success(combinedOutput.string)
                } else {
                    return .success("")
                }
            } catch let error {
                return await .failure(injectOutput(into: error))
            }
        }.get()
    }
    #endif
}

// MARK: - AsyncProcess Extension

extension AsyncProcess {

    // MARK: Shell Convenience Methods

    #if compiler(>=6.0)
    @inlinable
    @discardableResult
    public final class func bash(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .bash,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func sh(command: String,
                               arguments: [String],
                               environment: [String: String]? = _environmentDefault,
                               currentDirectory: URL? = _currentDirectoryDefault,
                               qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                               captureOutput: Bool = _captureOutputDefault,
                               captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .sh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func zsh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .zsh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func csh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .csh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func dash(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .dash,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func ksh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .ksh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func tcsh(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws(AsyncProcessError) -> String {
        try await executeShell(executable: .tcsh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }
    #else
    @inlinable
    @discardableResult
    public final class func bash(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .bash,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func sh(command: String,
                               arguments: [String],
                               environment: [String: String]? = _environmentDefault,
                               currentDirectory: URL? = _currentDirectoryDefault,
                               qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                               captureOutput: Bool = _captureOutputDefault,
                               captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .sh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func zsh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .zsh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func csh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .csh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func dash(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .dash,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func ksh(command: String,
                                arguments: [String],
                                environment: [String: String]? = _environmentDefault,
                                currentDirectory: URL? = _currentDirectoryDefault,
                                qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                captureOutput: Bool = _captureOutputDefault,
                                captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .ksh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }

    @inlinable
    @discardableResult
    public final class func tcsh(command: String,
                                 arguments: [String],
                                 environment: [String: String]? = _environmentDefault,
                                 currentDirectory: URL? = _currentDirectoryDefault,
                                 qualityOfService: QualityOfService? = _qualityOfServiceDefault,
                                 captureOutput: Bool = _captureOutputDefault,
                                 captureOutputOptions: CaptureOutputOptions = _captureOutputOptionsDefault) async throws -> String {
        try await executeShell(executable: .tcsh,
                               command: command,
                               arguments: arguments,
                               environment: environment,
                               currentDirectory: currentDirectory,
                               qualityOfService: qualityOfService,
                               captureOutput: captureOutput,
                               captureOutputOptions: captureOutputOptions)
    }
    #endif
}

// MARK: - AsyncProcess Extension

extension AsyncProcess {

    // MARK: Internal Methods

    #if compiler(>=6.0)
    @usableFromInline
    @discardableResult
    internal final class func executeShell(executable: Executable,
                                           command: String,
                                           arguments: [String],
                                           environment: [String: String]?,
                                           currentDirectory: URL?,
                                           qualityOfService: QualityOfService?,
                                           captureOutput: Bool,
                                           captureOutputOptions: CaptureOutputOptions) async throws(AsyncProcessError) -> String {
        try await run(executable: executable,
                      arguments: ["-c", "\(command) \(arguments.map(\.escapingForShell).joined(separator: " "))"],
                      environment: environment,
                      currentDirectory: currentDirectory,
                      qualityOfService: qualityOfService,
                      captureOutput: captureOutput,
                      captureOutputOptions: captureOutputOptions)
    }
    #else
    @usableFromInline
    @discardableResult
    internal final class func executeShell(executable: Executable,
                                           command: String,
                                           arguments: [String],
                                           environment: [String: String]?,
                                           currentDirectory: URL?,
                                           qualityOfService: QualityOfService?,
                                           captureOutput: Bool,
                                           captureOutputOptions: CaptureOutputOptions) async throws -> String {
        try await run(executable: executable,
                      arguments: ["-c", "\(command) \(arguments.map(\.escapingForShell).joined(separator: " "))"],
                      environment: environment,
                      currentDirectory: currentDirectory,
                      qualityOfService: qualityOfService,
                      captureOutput: captureOutput,
                      captureOutputOptions: captureOutputOptions)
    }
    #endif
}
