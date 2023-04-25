//
//  OID.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/17/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

@_implementationOnly import git2

/// An identifier for a Git object.
public struct OID {

    // MARK: - Initializers

    /// Create an instance from a hex formatted string.
    ///
    /// string - A 40-byte hex formatted string.
    public init?(string: String) {
        self.length = string.lengthOfBytes(using: String.Encoding.utf8)

        let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: length)
        defer { pointer.deallocate() }

        let result = git_oid_fromstrn(pointer, string, length)
        if result < GIT_OK.rawValue {
            return nil
        }

        oid = pointer.pointee
    }

    /// Create an instance from a libgit2 `git_oid`.
    init(_ oid: git_oid) {
        self.oid = oid
        self.length = size_t(GIT_OID_SHA1_HEXSIZE)
    }

    // MARK: - Properties

    let oid: git_oid
    public let length: size_t

    public var isShort: Bool {
        return length < GIT_OID_SHA1_HEXSIZE
    }

    public var isZero: Bool {
        var oid = self.oid
        return git_oid_is_zero(&oid) == 1
    }
}

extension OID: CustomStringConvertible {
    public var description: String {
        return desc(length: Int(GIT_OID_SHA1_HEXSIZE))
    }

    public func desc(length: Int) -> String {
        let string = UnsafeMutablePointer<Int8>.allocate(capacity: length)
        defer { string.deallocate() }
        var oid = self.oid
        git_oid_nfmt(string, length, &oid)
        return String(bytes: string, count: length)!
    }
}

extension OID: Hashable {
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: oid.id) {
            hasher.combine(bytes: $0)
        }
    }

    public static func == (lhs: OID, rhs: OID) -> Bool {
        var left = lhs.oid
        var right = rhs.oid
        return git_oid_cmp(&left, &right) == 0
    }
}
