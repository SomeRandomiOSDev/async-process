//
//  Executable.swift
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

    // MARK: AsyncProcess.Executable Definition

    public enum Executable: Equatable, Hashable, Sendable {

        // MARK: Cases

        case bash
        case sh
        case zsh

        case csh
        case dash
        case ksh
        case tcsh

        case bin(URL)

        // MARK: Internal Properties

        @usableFromInline
        internal var url: URL {
            switch self {
            case .bash: return URL(fileURLWithPath: "/bin/bash")
            case .sh: return URL(fileURLWithPath: "/bin/sh")
            case .zsh: return URL(fileURLWithPath: "/bin/zsh")
            case .csh: return URL(fileURLWithPath: "/bin/csh")
            case .dash: return URL(fileURLWithPath: "/bin/dash")
            case .ksh: return URL(fileURLWithPath: "/bin/ksh")
            case .tcsh: return URL(fileURLWithPath: "/bin/tcsh")
            case let .bin(url): return url
            }
        }

        // MARK: Public Properties

        #if os(macOS)
        public static let `default`: Executable = .zsh
        #else
        public static let `default`: Executable = .sh
        #endif
    }
}
