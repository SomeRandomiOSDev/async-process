//
//  AsyncBytes.swift
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

    // MARK: AsyncProcess.AsyncBytes Definition

    public struct AsyncBytes: Equatable, Hashable, Sendable, AsyncSequence {

        // MARK: Internal Properties

        @usableFromInline
        internal let pipe: Pipe

        @usableFromInline
        internal let forwardingTarget: FileHandle?

        // MARK: Initialization

        public init(alsoForwardingTo handle: FileHandle? = nil) {
            self.pipe = Pipe()
            self.forwardingTarget = handle
        }

        public init(alsoForwardingTo pipe: Pipe) {
            self.pipe = Pipe()
            self.forwardingTarget = pipe.fileHandleForWriting
        }

        // MARK: AsyncSequence Protocol Requirements

        public typealias Element = Data

        public struct AsyncIterator: AsyncIteratorProtocol {

            // MARK: Internal Properties

            @usableFromInline
            internal var iterator: AsyncStream<Data>.AsyncIterator

            // MARK: Initialization

            @inlinable
            init(iterator: AsyncStream<Data>.AsyncIterator) {
                self.iterator = iterator
            }

            // MARK: AsyncIteratorProtocol Protocol Requirements

            public mutating func next() async -> Data? {
                await iterator.next()
            }
        }

        @inlinable
        public func makeAsyncIterator() -> AsyncIterator {
            let stream = AsyncStream(Data.self) { continuation in
                pipe.fileHandleForReading.readabilityHandler = { @Sendable handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        continuation.finish()
                    } else {
                        continuation.yield(data)
                        forwardingTarget?.write(data)
                    }
                }

                continuation.onTermination = { _ in
                    pipe.fileHandleForReading.readabilityHandler = nil
                }
            }

            return AsyncIterator(iterator: stream.makeAsyncIterator())
        }
    }
}
