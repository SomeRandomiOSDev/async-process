//
//  String+ShellEscape.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

import Foundation

// MARK: - String Extensions

extension String {

    // MARK: Private Constants

    #if compiler(>=6.0)
    private static let charactersToEscape = CharacterSet(charactersIn: "\\!|&;<>()$'` \t\n\r*?[]#~=%{},:\"")
    #else
    private nonisolated(unsafe) static let charactersToEscape = CharacterSet(charactersIn: "\\!|&;<>()$'` \t\n\r*?[]#~=%{},:\"")
    #endif

    // MARK: Internal Properties

    internal var escapingForShell: String {
        var result = self
        var range = result.startIndex ..< result.endIndex

        while !range.isEmpty {
            guard let characterRange = result.rangeOfCharacter(from: Self.charactersToEscape,
                                                               options: .literal,
                                                               range: range) else {
                break
            }

            result.insert("\\", at: characterRange.lowerBound)

            if let newRange = result.rangeOfCharacter(from: Self.charactersToEscape,
                                                      options: .literal,
                                                      range: range.lowerBound ..< result.endIndex) {
                range = result.index(after: newRange.upperBound) ..< result.endIndex
            } else {
                range = result.index(range.lowerBound, offsetBy: 2) ..< result.endIndex
            }
        }

        return result
    }
}
