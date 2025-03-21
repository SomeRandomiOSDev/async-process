//
//  InputHandle.swift
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

    // MARK: AsyncProcess.InputHandle Definition

    public enum InputHandle: Equatable, Hashable, Sendable {

        // MARK: Cases

        case pipe(Pipe)
        case fileHandle(FileHandle)

        // MARK: Internal Properties

        @usableFromInline
        internal var rawHandle: Any {
            let rawHandle: Any
            switch self {
            case let .pipe(pipe): rawHandle = pipe
            case let .fileHandle(handle): rawHandle = handle
            }

            return rawHandle
        }
    }
}
