//
//  Repository+Branch.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import libgit2

public extension Repository {
    /// Load and return a list of all local branches.
    func localBranches() -> Result<[Branch], NSError> {
        return references(withPrefix: "refs/heads/").map { (refs: [ReferenceType]) in
            return refs.map { $0 as! Branch }
        }
    }

    /// Load and return a list of all remote branches.
    func remoteBranches() -> Result<[Branch], NSError> {
        return references(withPrefix: "refs/remotes/").map { (refs: [ReferenceType]) in
            return refs.map { $0 as! Branch }
        }
    }

    /// Load the local branch with the given name (e.g., "master").
    func localBranch(named name: String) -> Result<Branch, NSError> {
        return reference(named: "refs/heads/" + name).map { $0 as! Branch }
    }

    /// Load the remote branch with the given name (e.g., "origin/master").
    func remoteBranch(named name: String) -> Result<Branch, NSError> {
        return reference(named: "refs/remotes/" + name).map { $0 as! Branch }
    }

    /// Load the local/remote branch with the given name (e.g., "master").
    func branch(named name: String) -> Result<Branch, NSError> {
        if name.hasPrefix("refs/") {
            return reference(named: name).map { $0 as! Branch }
        }
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
    func createBranch(_ name: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid("refs/heads/\(name)") {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        return HEAD().flatMap { reference -> Result<Branch, NSError> in
            createBranch(name, oid: reference.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseBranch: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid("refs/heads/\(name)") {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        let result = branch(named: baseBranch)
        return result.flatMap { branch -> Result<Branch, NSError> in
            createBranch(name, oid: branch.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseTag: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid("refs/heads/\(name)") {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        return tag(named: baseTag).flatMap { tag -> Result<Branch, NSError> in
            createBranch(name, oid: tag.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseCommit: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid("refs/heads/\(name)") {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        return reference(named: baseCommit).flatMap { commit -> Result<Branch, NSError> in
            createBranch(name, oid: commit.oid, force: force)
        }
    }

    func deleteBranch(_ name: String) -> Result<(), NSError> {
        let name = name.hasPrefix("refs/heads/") ? name : "refs/heads/\(name)"
        var pointer: OpaquePointer? = nil
        var result = git_reference_lookup(&pointer, self.pointer, name)

        if result == GIT_ENOTFOUND.rawValue {
            return .success(())
        }

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

    func setTrackBranch(local: String, remote: String? = nil) -> Result<(), NSError> {
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

    func trackBranch() -> Result<Branch, NSError> {
        return HEAD().flatMap({ ref -> Result<Branch, NSError> in
            guard let branch = ref as? Branch else {
                return .failure(NSError(gitError: -1, pointOfFailure: "git_branch_lookup"))
            }
            return self.trackBranch(local: branch.name)
        })
    }

    func trackBranch(local: String) -> Result<Branch, NSError> {
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
