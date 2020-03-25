//
//  Repository+WorkDirectory.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

extension Repository {
    public func hasConflicts() -> Result<Bool, NSError> {
        var index: OpaquePointer? = nil
        defer { git_index_free(index) }
        let result = git_repository_index(&index, self.pointer)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_index"))
        }
        let conflicts = git_index_has_conflicts(index) == 1
        return .success(conflicts)
    }

    public func isEmpty() -> Result<Bool, NSError> {
        let result = git_repository_is_empty(self.pointer)
        if result == 1 { return .success(true) }
        if result == 0 { return .success(false) }
        return .failure(NSError(gitError: result, pointOfFailure: "git_repository_is_empty"))
    }

    public func headIsUnborn() -> Result<Bool, NSError> {
        let result = git_repository_head_unborn(self.pointer)
        if result == 1 { return .success(true) }
        if result == 0 { return .success(false) }
        return .failure(NSError(gitError: result, pointOfFailure: "git_repository_head_unborn"))
    }

    public func unbornHEAD() -> Result<UnbornBranch, NSError> {
        var pointer: OpaquePointer? = nil
        defer { git_reference_free(pointer) }
        let result = git_reference_lookup(&pointer, self.pointer, "HEAD")
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_lookup"))
        }
        return .success(UnbornBranch(pointer!)!)
    }

    /// Load the reference pointed at by HEAD.
    ///
    /// When on a branch, this will return the current `Branch`.
    public func HEAD() -> Result<ReferenceType, NSError> {
        var pointer: OpaquePointer? = nil
        defer { git_reference_free(pointer) }
        let result = git_repository_head(&pointer, self.pointer)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_head"))
        }
        let value = referenceWithLibGit2Reference(pointer!)
        return .success(value)
    }

    /// Set HEAD to the given oid (detached).
    ///
    /// :param: oid The OID to set as HEAD.
    /// :returns: Returns a result with void or the error that occurred.
    public func setHEAD(_ oid: OID) -> Result<(), NSError> {
        return longOID(for: oid).flatMap { oid -> Result<(), NSError> in
            var git_oid = oid.oid
            let result = git_repository_set_head_detached(self.pointer, &git_oid)
            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_set_head_detached"))
            }
            return Result.success(())
        }
    }

    /// Set HEAD to the given reference.
    ///
    /// :param: name The name to set as HEAD.
    /// :returns: Returns a result with void or the error that occurred.
    public func setHEAD(_ name: String) -> Result<(), NSError> {
        var longName = name
        if !name.isLongRef {
            do {
                longName = try self.reference(named: name).get().longName
            } catch {
                return .failure(error as NSError)
            }
        }
        let result = git_repository_set_head(self.pointer, longName)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_set_head"))
        }
        return Result.success(())
    }

    /// Check out HEAD.
    ///
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(_ options: CheckoutOptions? = nil) -> Result<(), NSError> {
        var opt = (options ?? CheckoutOptions()).toGit()

        let result = git_checkout_head(self.pointer, &opt)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_checkout_head"))
        }

        return Result.success(())
    }

    /// Check out the given OID.
    ///
    /// :param: oid The OID of the commit to check out.
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(_ oid: OID, _ options: CheckoutOptions? = nil) -> Result<(), NSError> {
        return setHEAD(oid).flatMap { self.checkout(options) }
    }

    /// Check out the given reference.
    ///
    /// :param: longName The long name to check out.
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(_ longName: String, _ options: CheckoutOptions? = nil) -> Result<(), NSError> {
        return setHEAD(longName).flatMap { self.checkout(options) }
    }

    /// Get the index for the repo. The caller is responsible for freeing the index.
    func unsafeIndex() -> Result<OpaquePointer, NSError> {
        var index: OpaquePointer? = nil
        let result = git_repository_index(&index, self.pointer)
        guard result == GIT_OK.rawValue && index != nil else {
            let err = NSError(gitError: result, pointOfFailure: "git_repository_index")
            return .failure(err)
        }
        return .success(index!)
    }

    /// Stage the file(s) under the specified path.
    public func add(path: String) -> Result<(), NSError> {
        var dirPointer = UnsafeMutablePointer<Int8>(mutating: (path as NSString).utf8String)
        return withUnsafeMutablePointer(to: &dirPointer) { pointer in
            var paths = git_strarray(strings: pointer, count: 1)
            return unsafeIndex().flatMap { index in
                defer { git_index_free(index) }
                let addResult = git_index_add_all(index, &paths, 0, nil, nil)
                guard addResult == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: addResult, pointOfFailure: "git_index_add_all"))
                }
                // write index to disk
                let writeResult = git_index_write(index)
                guard writeResult == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: writeResult, pointOfFailure: "git_index_write"))
                }
                return .success(())
            }
        }
    }
}
