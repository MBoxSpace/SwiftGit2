//
//  Repository+Branch.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import libgit2

extension Repository {
    /// Load the local/remote branch with the given name (e.g., "master").
    public func branch(named name: String) -> Result<Branch, NSError> {
        let result = localBranch(named: name)
        if result.isSuccess {
            return result
        }
        return remoteBranch(named: name)
    }

    private func createBranch(_ name: String, oid: OID, force: Bool = false) -> Result<Branch, NSError> {
        var oid = oid.oid
        var commit: OpaquePointer? = nil
        var result = git_commit_lookup(&commit, self.pointer, &oid)
        defer { git_commit_free(commit) }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_commit_lookup"))
        }

        var newBranch: OpaquePointer? = nil
        result = git_branch_create(&newBranch, self.pointer, name, commit, force ? 1 : 0)
        defer { git_reference_free(newBranch) }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_branch_create"))
        }
        guard let r = Branch(newBranch!) else {
            return .failure(NSError(gitError: -1, pointOfFailure: "git_branch_create"))
        }
        return .success(r)
    }

    @discardableResult
    public func createBranch(_ name: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name) {
            return .failure(NSError(gitError: -1, pointOfFailure: "Branch name `\(name)` is invalid."))
        }
        return HEAD().flatMap { reference -> Result<Branch, NSError> in
            createBranch(name, oid: reference.oid, force: force)
        }
    }

    @discardableResult
    public func createBranch(_ name: String, baseBranch: String, baseLocal: Bool = true, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name) {
            return .failure(NSError(gitError: -1, pointOfFailure: "Branch name `\(name)` is invalid."))
        }
        let result = baseLocal ? localBranch(named: baseBranch) : remoteBranch(named: baseBranch)
        return result.flatMap { branch -> Result<Branch, NSError> in
            createBranch(name, oid: branch.oid, force: force)
        }
    }

    @discardableResult
    public func createBranch(_ name: String, baseTag: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name) {
            return .failure(NSError(gitError: -1, pointOfFailure: "Branch name `\(name)` is invalid."))
        }
        return tag(named: baseTag).flatMap { tag -> Result<Branch, NSError> in
            createBranch(name, oid: tag.oid, force: force)
        }
    }

    @discardableResult
    public func createBranch(_ name: String, baseCommit: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name) {
            return .failure(NSError(gitError: -1, pointOfFailure: "Branch name `\(name)` is invalid."))
        }
        return reference(named: baseCommit).flatMap { commit -> Result<Branch, NSError> in
            createBranch(name, oid: commit.oid, force: force)
        }
    }

    public func deleteBranch(_ name: String) -> Result<(), NSError> {
        let name = name.hasPrefix("refs/heads/") ? name : "refs/heads/\(name)"
        var pointer: OpaquePointer? = nil
        var result = git_reference_lookup(&pointer, self.pointer, name)

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_lookup"))
        }

        result = git_branch_delete(pointer)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_branch_delete"))
        }

        git_reference_free(pointer)
        return .success(())
    }

    public func setTrackBranch(local: String, remote: String? = nil) -> Result<(), NSError> {
        var pointer: OpaquePointer? = nil
        var result = git_branch_lookup(&pointer, self.pointer, local, GIT_BRANCH_LOCAL)
        defer { git_reference_free(pointer) }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_branch_lookup"))
        }

        result = git_branch_set_upstream(pointer, remote)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_branch_set_upstream"))
        }

        return .success(())
    }

    public func trackBranch() -> Result<Branch, NSError> {
        return HEAD().flatMap({ ref -> Result<Branch, NSError> in
            guard let branch = ref as? Branch else {
                return .failure(NSError(gitError: -1, pointOfFailure: "git_branch_lookup"))
            }
            return self.trackBranch(local: branch.name)
        })
    }

    public func trackBranch(local: String) -> Result<Branch, NSError> {
        var pointer: OpaquePointer? = nil
        var result = git_branch_lookup(&pointer, self.pointer, local, GIT_BRANCH_LOCAL)
        defer { git_reference_free(pointer) }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_branch_lookup"))
        }

        var track: OpaquePointer? = nil
        result = git_branch_upstream(&track, pointer)
        defer { git_reference_free(track) }
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_branch_upstream"))
        }

        if let track = track, let branch = Branch(track) {
            return Result.success(branch)
        } else {
            return .failure(NSError(gitError: -1, pointOfFailure: "git_branch_name or git_reference_resolve"))
        }
    }

}
