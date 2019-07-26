//
//  Repository+Reference.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

public extension Repository {
    /// Load all the references with the given prefix (e.g. "refs/heads/")
    func references(withPrefix prefix: String) -> Result<[ReferenceType], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        let result = git_reference_list(pointer, self.pointer)

        guard result == GIT_OK.rawValue else {
            pointer.deallocate()
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_list"))
        }

        let strarray = pointer.pointee
        let references = strarray.filter { $0.hasPrefix(prefix) }.map { self.reference(named: $0) }
        git_strarray_free(pointer)
        pointer.deallocate()

        return references.aggregateResult()
    }

    internal func reference<T>(longName: String, block: (OpaquePointer) -> Result<T, NSError>) -> Result<T, NSError> {
        var pointer: OpaquePointer? = nil
        let result = git_reference_lookup(&pointer, self.pointer, longName)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_lookup"))
        }
        let value = block(pointer!)
        git_reference_free(pointer)
        return value
    }

    internal func reference<T>(shortName: String, block: (OpaquePointer) -> Result<T, NSError>) -> Result<T, NSError> {
        var pointer: OpaquePointer? = nil
        let result = git_reference_dwim(&pointer, self.pointer, shortName)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_dwim"))
        }
        let value = block(pointer!)
        git_reference_free(pointer)
        return value
    }

    internal func reference<T>(named name: String, block: (OpaquePointer) -> Result<T, NSError>) -> Result<T, NSError> {
        if name.hasPrefix("refs/") || name == "HEAD" {
            return self.reference(longName: name) { pointer -> Result<T, NSError> in
                return block(pointer)
            }
        } else {
            return self.reference(shortName: name) { pointer -> Result<T, NSError> in
                return block(pointer)
            }
        }
    }

    /// Load the reference with the given name (e.g. "refs/heads/master", "master")
    ///
    /// If the reference is a branch, a `Branch` will be returned. If the
    /// reference is a tag, a `TagReference` will be returned. Otherwise, a
    /// `Reference` will be returned.
    func reference(named name: String) -> Result<ReferenceType, NSError> {
        return self.reference(named: name) { pointer -> Result<ReferenceType, NSError> in
            let value = referenceWithLibGit2Reference(pointer)
            return Result.success(value)
        }
    }

    func update(reference name: String, to oid: OID) -> Result<(), NSError> {
        return self.reference(named: name) { pointer -> Result<(), NSError> in
            var newRef: OpaquePointer? = nil
            var oid = oid.oid
            let result = git_reference_set_target(&newRef, pointer, &oid, nil)
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_reference_set_target"))
            }
            return .success(())
        }
    }
}
