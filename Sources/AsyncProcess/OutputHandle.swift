//
//  OutputHandle.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

#if compiler(<6.0)
@preconcurrency
#endif
import Foundation

// MARK: - AsyncProcess Extension

extension AsyncProcess {

    // MARK: AsyncProcess.OutputHandle Definition

    public enum OutputHandle: Equatable, Hashable, Sendable {

        // MARK: Cases

        case pipe(Pipe)
        case fileHandle(FileHandle)
        case bytes(AsyncBytes)

        // MARK: Internal Properties

        @usableFromInline
        internal var rawHandle: Any {
            let rawHandle: Any
            switch self {
            case let .pipe(pipe): rawHandle = pipe
            case let .fileHandle(handle): rawHandle = handle
            case let .bytes(bytes): rawHandle = bytes.pipe
            }

            return rawHandle
        }
    }
}
