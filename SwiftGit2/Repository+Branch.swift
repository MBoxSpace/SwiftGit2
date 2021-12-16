//
//  Repository+Branch.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/15.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
@_implementationOnly import git2

public extension Repository {
    /// Load and return a list of all local branches.
    func localBranches() -> Result<[Branch], NSError> {
        return references(withPrefix: .branchPrefix).map { (refs: [ReferenceType]) in
            return refs.map { $0 as! Branch }
        }
    }

    /// Load and return a list of all remote branches.
    func remoteBranches() -> Result<[Branch], NSError> {
        return references(withPrefix: .remotePrefix).map { (refs: [ReferenceType]) in
            return refs.map { $0 as! Branch }
        }
    }

    /// Load the local branch with the given name (e.g., "master").
    func localBranch(named name: String) -> Result<Branch, NSError> {
        return reference(named: .branchPrefix + name).map { $0 as! Branch }
    }

    /// Load the remote branch with the given name (e.g., "origin/master").
    func remoteBranch(named name: String) -> Result<Branch, NSError> {
        return reference(named: .remotePrefix + name).map { $0 as! Branch }
    }

    /// Load the local/remote branch with the given name (e.g., "master").
    func branch(named name: String) -> Result<Branch, NSError> {
        if name.isLongRef {
            return reference(named: name).map { $0 as! Branch }
        }
        var result = localBranch(named: name)
        if result.isSuccess {
            return result
        }
        result = remoteBranch(named: name)
        if result.isSuccess {
            return result
        }
        return self.allRemotes().flatMap { remotes -> Result<Branch, NSError> in
            for remote in remotes {
                let branch = remoteBranch(named: "\(remote.name)/\(name)")
                if branch.isSuccess {
                    return branch
                }
            }
            return .failure(NSError(gitError: GIT_ENOTFOUND.rawValue, description: "Remote branch `\(name)` does not exist."))
        }
    }

    private func createBranch(_ name: String, oid: OID, force: Bool = false) -> Result<Branch, NSError> {
        return self.longOID(for: oid).flatMap { oid -> Result<Branch, NSError> in
            var oid = oid.oid
            var commit: OpaquePointer? = nil
            var result = git_commit_lookup(&commit, self.pointer, &oid)
            defer { git_commit_free(commit) }
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_commit_lookup"))
            }

            var newBranch: OpaquePointer? = nil
            result = git_branch_create(&newBranch, self.pointer, name.shortRef, commit, force ? 1 : 0)
            defer { git_reference_free(newBranch) }
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_branch_create"))
            }
            guard let r = Branch(newBranch!) else {
                return .failure(NSError(gitError: -1, pointOfFailure: "git_branch_create"))
            }
            return .success(r)
        }
    }

    @discardableResult
    func createBranch(_ name: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name.longBranchRef) {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        return HEAD().flatMap { reference -> Result<Branch, NSError> in
            createBranch(name, oid: reference.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseBranch: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name.longBranchRef) {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        let result = branch(named: baseBranch)
        return result.flatMap { branch -> Result<Branch, NSError> in
            createBranch(name, oid: branch.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseTag: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name.longBranchRef) {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        return tag(named: baseTag).flatMap { tag -> Result<Branch, NSError> in
            createBranch(name, oid: tag.oid, force: force)
        }
    }

    @discardableResult
    func createBranch(_ name: String, baseCommit: String, force: Bool = false) -> Result<Branch, NSError> {
        if !checkValid(name.longBranchRef) {
            return .failure(NSError(gitError: -1, description: "Branch name `\(name)` is invalid."))
        }
        guard let oid = OID(string: baseCommit) else {
            return .failure(NSError(gitError: -1, description: "The commit `\(baseCommit)` is invalid."))
        }
        return createBranch(name, oid: oid, force: force)
    }

    func deleteBranch(_ name: String, remote: String, force: Bool = false) -> Result<(), NSError> {
        let name = name.longBranchRef
        return self.push(remote, sourceRef: "", targetRef: name, force: force)
    }

    func deleteBranch(_ name: String) -> Result<(), NSError> {
        let name = name.longBranchRef
        var pointer: OpaquePointer? = nil
        defer {
            git_reference_free(pointer)
        }
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
