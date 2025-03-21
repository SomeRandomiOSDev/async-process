//
//  AsyncProcess.swift
//  AsyncProcess
//
//  Copyright © 2023 SomeRandomiOSDev. All rights reserved.
//

import Foundation

// MARK: - AsyncProcess Extension

extension AsyncProcess {

    // MARK: AsyncProcess.OutputDataAccumulator Definition

    internal actor OutputDataAccumulator {

        // MARK: Internal Properties

        internal private(set) var data = Data()

        internal var string: String {
            let string: String
            if let decodedString = String(data: data, encoding: .utf8) {
                string = decodedString
            } else {
                let data = data + Data([0]) // null terminator, just in case it didn't have one

                string = data.withUnsafeBytes { buffer in
                    buffer.baseAddress.map { address in
                        String(cString: address.assumingMemoryBound(to: UInt8.self))
                    } ?? ""
                }
            }

            if string.hasSuffix("\n") {
                return String(string.dropLast())
            } else {
                return string
            }
        }

        // MARK: Internal Methods

        @inlinable
        internal func append(_ data: Data) {
            self.data.append(data)
        }
    }
}
