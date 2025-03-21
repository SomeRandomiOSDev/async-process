//
//  AsyncProcessError.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

// MARK: - AsyncProcessError Definition

public indirect enum AsyncProcessError: Error {

    // MARK: Cases

    case terminated(code: Int)
    case uncaughtSignal(signal: Int)
    case processError(Error)
    case processIsRunning
    case processFinished

    case errorWithOutput(error: AsyncProcessError, output: String)
}
