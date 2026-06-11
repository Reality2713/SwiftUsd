//===----------------------------------------------------------------------===//
// This source file is part of github.com/apple/SwiftUsd
//
// Copyright © 2025 Apple Inc. and the SwiftUsd project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
//===----------------------------------------------------------------------===//

import Foundation
import CxxStdlib

extension __Overlay {
    public protocol VtArray_Equatable: Equatable {
        associatedtype Element: Equatable
        func size() -> Int
        subscript(_ :Int) -> Element { get }
    }
}
extension __Overlay.VtArray_Equatable {
    static public func ==(lhs: Self, rhs: Self) -> Bool {
        guard lhs.size() == rhs.size() else { return false }
        for i in 0..<lhs.size() {
            guard lhs[i] == rhs[i] else { return false }
        }
        return true
    }
}

extension __Overlay {
    public protocol VtArray_ExpressibleByArrayLiteral: ExpressibleByArrayLiteral {
        associatedtype ElementType
        init()
        init(arrayLiteral elements: ArrayLiteralElement...)
        init<S: Sequence>(_ elements: S) where S.Element == ElementType
        mutating func reserve(_ num: Int)
        mutating func push_back(_ x: ArrayLiteralElement)
    }
}
extension __Overlay.VtArray_ExpressibleByArrayLiteral where ArrayLiteralElement == Self.ElementType {
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(elements)
    }

    public init<S: Sequence>(_ elements: S) where S.Element == ElementType {
        self.init()
        for x in elements {
            self.push_back(x)
        }
    }

    public init<C: Collection>(_ elements: C) where C.Element == ElementType {
        self.init()
        self.reserve(elements.count)
        for x in elements {
            self.push_back(x)
        }
    }
}

extension __Overlay {
    public protocol VtArray_CustomStringConvertible: CustomStringConvertible where Element: CustomStringConvertible {
        associatedtype Element
        func size() -> Int
        subscript(_ :Int) -> Element { get }
    }
}
extension __Overlay.VtArray_CustomStringConvertible {
    public var description: String {
        let elements = (0..<size()).map { self[$0].description }
        return "[" + elements.joined(separator: ", ") + "]"
    }
}

extension __Overlay {
    public struct VtArray_Sequence_Iterator<V: __Overlay.VtArray_Sequence>: IteratorProtocol {
        var begin: UnsafePointer<V.ElementType>?
        var end: UnsafePointer<V.ElementType>?
        var s: V // hold the VtArray alive as long as there's an iterator to it

        init(begin: UnsafePointer<V.ElementType>?, end: UnsafePointer<V.ElementType>?, s: V) {
            self.begin = begin
            self.end = end
            self.s = s
        }

        public mutating func next() -> V.ElementType? {
            if begin == end {
                return nil
            }
            let result = begin?.pointee
            begin = begin?.advanced(by: 1)
            return result
        }
    }
}

extension __Overlay {
    public protocol VtArray_Sequence {
        associatedtype ElementType
        func __beginUnsafe() -> UnsafePointer<ElementType>?
        func __endUnsafe() -> UnsafePointer<ElementType>?
    }
}
extension __Overlay.VtArray_Sequence {
    public func makeIterator() -> __Overlay.VtArray_Sequence_Iterator<Self> {
        .init(begin: __beginUnsafe(), end: __endUnsafe(), s: self)
    }
}

extension __Overlay {
    public protocol VtArray_Codable: Codable where ElementType: Codable {
        associatedtype ElementType
    }
    // Codable implementation for VtArray<T> lives in SwiftUsd/source/SwiftOverlay/Codable.swift
}

extension __Overlay {
    public protocol VtArray_WithoutCodableProtocol: VtArray_Equatable,
                                     VtArray_ExpressibleByArrayLiteral,
                                     VtArray_Sequence,
                                     VtArray_CustomStringConvertible {}

    public protocol VtArrayProtocol: VtArray_WithoutCodableProtocol,
                                     VtArray_Codable {
    }
}

extension pxr.VtBoolArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Bool
    public typealias ArrayLiteralElement = Bool
}
extension pxr.VtDoubleArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Double
    public typealias ArrayLiteralElement = Double
}
extension pxr.VtFloatArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Float
    public typealias ArrayLiteralElement = Float
}
extension pxr.VtHalfArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfHalf
    public typealias ArrayLiteralElement = pxr.GfHalf
}

extension pxr.VtCharArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = CChar
    public typealias ArrayLiteralElement = CChar
}
extension pxr.VtUCharArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = UInt8
    public typealias ArrayLiteralElement = UInt8
}
extension pxr.VtShortArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Int16
    public typealias ArrayLiteralElement = Int16
}
extension pxr.VtUShortArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = UInt16
    public typealias ArrayLiteralElement = UInt16
}
extension pxr.VtIntArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Int32
    public typealias ArrayLiteralElement = Int32
}
extension pxr.VtUIntArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = UInt32
    public typealias ArrayLiteralElement = UInt32
}
extension pxr.VtInt64Array: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = Int64
    public typealias ArrayLiteralElement = Int64
}
extension pxr.VtUInt64Array: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = UInt64
    public typealias ArrayLiteralElement = UInt64
}

extension pxr.VtVec4iArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec4i
    public typealias ArrayLiteralElement = pxr.GfVec4i
}
extension pxr.VtVec3iArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec3i
    public typealias ArrayLiteralElement = pxr.GfVec3i
}
extension pxr.VtVec2iArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec2i
    public typealias ArrayLiteralElement = pxr.GfVec2i
}

extension pxr.VtVec4hArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec4h
    public typealias ArrayLiteralElement = pxr.GfVec4h
}
extension pxr.VtVec3hArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec3h
    public typealias ArrayLiteralElement = pxr.GfVec3h
}
extension pxr.VtVec2hArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec2h
    public typealias ArrayLiteralElement = pxr.GfVec2h
}

extension pxr.VtVec4fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec4f
    public typealias ArrayLiteralElement = pxr.GfVec4f
}
extension pxr.VtVec3fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec3f
    public typealias ArrayLiteralElement = pxr.GfVec3f
}
extension pxr.VtVec2fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec2f
    public typealias ArrayLiteralElement = pxr.GfVec2f
}

extension pxr.VtVec4dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec4d
    public typealias ArrayLiteralElement = pxr.GfVec4d
}
extension pxr.VtVec3dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec3d
    public typealias ArrayLiteralElement = pxr.GfVec3d
}
extension pxr.VtVec2dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfVec2d
    public typealias ArrayLiteralElement = pxr.GfVec2d
}

extension pxr.VtMatrix4fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix4f
    public typealias ArrayLiteralElement = pxr.GfMatrix4f
}
extension pxr.VtMatrix3fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix3f
    public typealias ArrayLiteralElement = pxr.GfMatrix3f
}
extension pxr.VtMatrix2fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix2f
    public typealias ArrayLiteralElement = pxr.GfMatrix2f
}

extension pxr.VtMatrix4dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix4d
    public typealias ArrayLiteralElement = pxr.GfMatrix4d
}
extension pxr.VtMatrix3dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix3d
    public typealias ArrayLiteralElement = pxr.GfMatrix3d
}
extension pxr.VtMatrix2dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfMatrix2d
    public typealias ArrayLiteralElement = pxr.GfMatrix2d
}

extension pxr.VtRange3fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange3f
    public typealias ArrayLiteralElement = pxr.GfRange3f
}
extension pxr.VtRange3dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange3d
    public typealias ArrayLiteralElement = pxr.GfRange3d
}
extension pxr.VtRange2fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange2f
    public typealias ArrayLiteralElement = pxr.GfRange2f
}
extension pxr.VtRange2dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange2d
    public typealias ArrayLiteralElement = pxr.GfRange2d
}
extension pxr.VtRange1fArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange1f
    public typealias ArrayLiteralElement = pxr.GfRange1f
}
extension pxr.VtRange1dArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRange1d
    public typealias ArrayLiteralElement = pxr.GfRange1d
}

extension pxr.VtIntervalArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfInterval
    public typealias ArrayLiteralElement = pxr.GfInterval
}
extension pxr.VtRect2iArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfRect2i
    public typealias ArrayLiteralElement = pxr.GfRect2i
}

// VtStringArray gains Codable conformance in Codable.swift,
// but it can't satisfy the requirements that ElementType is Codable
// because std.string isn't Codable
extension pxr.VtStringArray: __Overlay.VtArray_WithoutCodableProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = std.string
    public typealias ArrayLiteralElement = std.string
}
extension pxr.VtTokenArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.TfToken
    public typealias ArrayLiteralElement = pxr.TfToken
}

extension pxr.VtQuathArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfQuath
    public typealias ArrayLiteralElement = pxr.GfQuath
}
extension pxr.VtQuatfArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfQuatf
    public typealias ArrayLiteralElement = pxr.GfQuatf
}
extension pxr.VtQuatdArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfQuatd
    public typealias ArrayLiteralElement = pxr.GfQuatd
}
extension pxr.VtQuaternionArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.GfQuaternion
    public typealias ArrayLiteralElement = pxr.GfQuaternion
}

extension Overlay.SdfAssetPath_VtArray: __Overlay.VtArrayProtocol {
    // Explicit witnesses: the Swift 6.4 interface printer corrupts
    // inferred associated-type witnesses for C++ specializations.
    public typealias ElementType = pxr.SdfAssetPath
    public typealias ArrayLiteralElement = pxr.SdfAssetPath
}
