// 
//  Lock.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

#if os(macOS)
import os
#elseif os(Linux)
import Glibc
#endif

// MARK: - Lock Definition

internal struct Lock<State>: @unchecked Sendable {

    // MARK: Private Properties

    private let state: ManagedBuffer<State, lock_type>

    // MARK: Initialization

    internal init(uncheckedState initialState: State) {
        self.state = .create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointerToElements { lock_init($0) }
            return initialState
        }
    }

    // MARK: Internal Methods

    #if compiler(>=6.0)
    internal func withLock<R, E>(_ body: @Sendable (inout State) throws(E) -> R) throws(E) -> R where R: Sendable {
        try withLockUnchecked(body)
    }

    internal func withLockUnchecked<R, E>(_ body: (inout State) throws(E) -> R) throws(E) -> R {
        try state.withUnsafeMutablePointers { state, lock throws(E) -> R in
            lock_lock(lock)
            defer { lock_unlock(lock) }

            return try body(&state.pointee)
        }
    }

    internal func withLockIfAvailable<R, E>(_ body: @Sendable (inout State) throws(E) -> R) throws(E) -> R? where R: Sendable {
        try withLockIfAvailableUnchecked(body)
    }

    internal func withLockIfAvailableUnchecked<R, E>(_ body: (inout State) throws(E) -> R) throws(E) -> R? {
        try state.withUnsafeMutablePointers { state, lock throws(E) -> R? in
            guard lock_trylock(lock) else { return nil }
            defer { lock_unlock(lock) }

            return try body(&state.pointee)
        }
    }
    #else
    internal func withLock<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R where R: Sendable {
        try withLockUnchecked(body)
    }

    internal func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R {
        try state.withUnsafeMutablePointers { state, lock in
            lock_lock(lock)
            defer { lock_unlock(lock) }

            return try body(&state.pointee)
        }
    }

    internal func withLockIfAvailable<R>(_ body: @Sendable (inout State) throws -> R) rethrows -> R? where R: Sendable {
        try withLockIfAvailableUnchecked(body)
    }

    internal func withLockIfAvailableUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R? {
        try state.withUnsafeMutablePointers { state, lock in
            guard lock_trylock(lock) else { return nil }
            defer { lock_unlock(lock) }

            return try body(&state.pointee)
        }
    }
    #endif
}

// MARK: - Lock Extension

extension Lock where State == Void {

    // MARK: Initialization

    @inline(__always)
    internal init() where State == Void {
        self.init(uncheckedState: Void())
    }

    // MARK: Public Methods

    internal func withLock<R>(_ body: @Sendable () throws -> R) rethrows -> R where R: Sendable, State == Void {
        try withLockUnchecked(body)
    }

    internal func withLockUnchecked<R>(_ body: () throws -> R) rethrows -> R where State == Void {
        try state.withUnsafeMutablePointers { state, lock in
            lock_lock(lock)
            defer { lock_unlock(lock) }

            return try body()
        }
    }

    internal func withLockIfAvailable<R>(_ body: @Sendable () throws -> R) rethrows -> R? where R: Sendable, State == Void {
        try state.withUnsafeMutablePointers { state, lock in
            guard lock_trylock(lock) else { return nil }
            defer { lock_unlock(lock) }

            return try body()
        }
    }

    internal func withLockIfAvailableUnchecked<R>(_ body: () throws -> R) rethrows -> R? where State == Void {
        try state.withUnsafeMutablePointers { state, lock in
            guard lock_trylock(lock) else { return nil }
            defer { lock_unlock(lock) }

            return try body()
        }
    }

    @available(*, noasync, message: "Use withLock(_:) for scoped locking")
    internal func lock() {
        state.withUnsafeMutablePointerToElements { lock in
            lock_lock(lock)
        }
    }

    @available(*, noasync, message: "Use withLock(_:) for scoped locking")
    internal func unlock() {
        state.withUnsafeMutablePointerToElements { lock in
            lock_unlock(lock)
        }
    }

    @available(*, noasync, message: "Use withLockIfAvailable(_:) for scoped locking")
    internal func lockIfAvailable() -> Bool {
        state.withUnsafeMutablePointerToElements { lock in
            lock_trylock(lock)
        }
    }
}

// MARK: - Lock Extension

extension Lock where State: Sendable {

    // MARK: Initialization

    @inline(__always)
    internal init(initialState: State) {
        self.init(uncheckedState: initialState)
    }
}

// MARK: Private Implementation Details

#if os(macOS)
@usableFromInline
internal typealias lock_type = os_unfair_lock

@usableFromInline @inline(__always) internal func lock_init(_ lock: UnsafeMutablePointer<lock_type>) { lock.initialize(to: os_unfair_lock()) }
@usableFromInline @inline(__always) internal func lock_lock(_ lock: UnsafeMutablePointer<lock_type>) { os_unfair_lock_lock(lock) }
@usableFromInline @inline(__always) internal func lock_trylock(_ lock: UnsafeMutablePointer<lock_type>) -> Bool { os_unfair_lock_trylock(lock) }
@usableFromInline @inline(__always) internal func lock_unlock(_ lock: UnsafeMutablePointer<lock_type>) { os_unfair_lock_unlock(lock) }
#else
@usableFromInline
internal typealias lock_type = pthread_mutex_t

@usableFromInline @inline(__always) internal func lock_init(_ lock: UnsafeMutablePointer<lock_type>) {
    lock.initialize(to: pthread_mutex_t())

    let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
    attr.initialize(to: pthread_mutexattr_t())
    pthread_mutexattr_init(attr)

    defer {
        pthread_mutexattr_destroy(attr)
        attr.deinitialize(count: 1)
        attr.deallocate()
    }

    pthread_mutexattr_settype(attr, Int32(PTHREAD_MUTEX_ERRORCHECK))
    pthread_mutex_init(lock, attr)
}
@usableFromInline @inline(__always) internal func lock_lock(_ lock: UnsafeMutablePointer<lock_type>) { pthread_mutex_lock(lock) }
@usableFromInline @inline(__always) internal func lock_trylock(_ lock: UnsafeMutablePointer<lock_type>) -> Bool { pthread_mutex_trylock(lock) == 0 }
@usableFromInline @inline(__always) internal func lock_unlock(_ lock: UnsafeMutablePointer<lock_type>) { pthread_mutex_unlock(lock) }
#endif
