//
//  Repository+Commit.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
@_implementationOnly import git2

public extension Repository {

    // MARK: - private functions
    internal func commit(tree: OpaquePointer, // git_tree
                         parentCommits: [OpaquePointer?], // [git_commit]
                         message: String,
                         signature: UnsafeMutablePointer<git_signature>? = nil) -> Result<git_oid, NSError> {
        var msgBuf = git_buf()
        git_message_prettify(&msgBuf, message, 0, /* ascii for # */ 35)
        defer { git_buf_dispose(&msgBuf) }

        let parentsContiguous = ContiguousArray(parentCommits)
        return parentsContiguous.withUnsafeBufferPointer { unsafeBuffer in
            var commitOID = git_oid()
            let parentsPtr = UnsafeMutablePointer(mutating: unsafeBuffer.baseAddress)
            let result = git_commit_create(
                &commitOID,
                self.pointer,
                "HEAD",
                signature,
                signature,
                "UTF-8",
                msgBuf.ptr,
                tree,
                parentCommits.count,
                parentsPtr
            )
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_commit_create"))
            }
            return .success(commitOID)
        }
    }

    internal func commit(oid: git_oid,
                         parentCommits: [OpaquePointer?], // [git_commit]
                         message: String,
                         signature: UnsafeMutablePointer<git_signature>? = nil) -> Result<git_oid, NSError> {
        var tree: OpaquePointer? = nil
        var treeOIDCopy = oid
        let lookupResult = git_tree_lookup(&tree, self.pointer, &treeOIDCopy)
        guard lookupResult == GIT_OK.rawValue else {
            let err = NSError(gitError: lookupResult, pointOfFailure: "git_tree_lookup")
            return .failure(err)
        }
        defer { git_tree_free(tree) }

        return commit(tree: tree!, parentCommits: parentCommits, message: message, signature: signature)
    }

    internal func commit(index: OpaquePointer, // git_index
                         parentCommits: [OpaquePointer?], // [git_commit]
                         message: String,
                         signature: UnsafeMutablePointer<git_signature>? = nil) -> Result<git_oid, NSError> {
        var treeOID = git_oid()
        let result = git_index_write_tree(&treeOID, index)
        guard result == GIT_OK.rawValue else {
            let err = NSError(gitError: result, pointOfFailure: "git_index_write_tree")
            return .failure(err)
        }
        return commit(oid: treeOID, parentCommits: parentCommits, message: message, signature: signature)
    }

    internal func commit(message: String,
                         signature: UnsafeMutablePointer<git_signature>? = nil
        ) -> Result<git_oid, NSError> {

        let unborn: Bool
        let result = git_repository_head_unborn(self.pointer)
        if result == 1 {
            unborn = true
        } else if result == 0 {
            unborn = false
        } else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_head_unborn"))
        }

        var commit: OpaquePointer? = nil
        defer { git_commit_free(commit) }
        if !unborn {
            // get head reference
            var head: OpaquePointer? = nil
            defer { git_reference_free(head) }
            var result = git_repository_head(&head, self.pointer)
            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_head"))
            }

            // get head oid
            var oid = git_reference_target(head).pointee

            // get head commit
            result = git_commit_lookup(&commit, self.pointer, &oid)
            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_commit_lookup"))
            }
        }
        return unsafeIndex().flatMap { index in
            defer { git_index_free(index) }
            return self.commit(index: index, parentCommits: [commit].filter { $0 != nil }, message: message, signature: signature)
        }
    }

    // MARK: - public function

    /// Loads the commit from the HEAD.
    ///
    /// Returns the HEAD commit, or an error.
    func commit() -> Result<Commit, NSError> {
        self.HEAD().flatMap { ref in
            commit(ref.oid)
        }
    }

    /// Loads the commit with the given OID.
    ///
    /// oid - The OID of the commit to look up.
    ///
    /// Returns the commit if it exists, or an error.
    func commit(_ oid: OID) -> Result<Commit, NSError> {
        return withGitObject(oid, type: GIT_OBJECT_COMMIT) { Commit($0) }
    }

    /// Load all commits in the specified branch in topological & time order descending
    ///
    /// :param: branch The branch to get all commits from
    /// :returns: Returns a result with array of branches or the error that occurred
    func commits(in branch: Branch) -> CommitIterator {
        let iterator = CommitIterator(repo: self, root: branch.oid.oid)
        return iterator
    }

    /// Perform a commit with arbitrary numbers of parent commits.
    func commit(tree treeOID: OID,
                parents: [Commit],
                message: String,
                signature: Signature? = nil) -> Result<Commit, NSError> {
        // create commit signature
        let sign: Signature
        do {
            sign = try signature ?? Signature.default(self).get()
        } catch {
            return .failure(error as NSError)
        }
        return sign.makeUnsafeSignature().flatMap { signature in
            defer { git_signature_free(signature) }
            var tree: OpaquePointer? = nil
            var treeOIDCopy = treeOID.oid
            let lookupResult = git_tree_lookup(&tree, self.pointer, &treeOIDCopy)
            guard lookupResult == GIT_OK.rawValue else {
                let err = NSError(gitError: lookupResult, pointOfFailure: "git_tree_lookup")
                return .failure(err)
            }
            defer { git_tree_free(tree) }

            // libgit2 expects a C-like array of parent git_commit pointer
            var parentGitCommits: [OpaquePointer?] = []
            defer {
                for commit in parentGitCommits {
                    git_commit_free(commit)
                }
            }
            for parentCommit in parents {
                var parent: OpaquePointer? = nil
                var oid = parentCommit.oid.oid
                let lookupResult = git_commit_lookup(&parent, self.pointer, &oid)
                guard lookupResult == GIT_OK.rawValue else {
                    let err = NSError(gitError: lookupResult, pointOfFailure: "git_commit_lookup")
                    return .failure(err)
                }
                parentGitCommits.append(parent!)
            }

            return commit(tree: tree!, parentCommits: parentGitCommits, message: message, signature: signature).flatMap { commit(OID($0)) }
        }
    }

    /// Perform a commit of the staged files with the specified message and signature,
    /// assuming we are not doing a merge and using the current tip as the parent.
    func commit(message: String, signature: Signature? = nil) -> Result<Commit, NSError> {
        // create commit signature
        let sign: Signature
        do {
            sign = try signature ?? Signature.default(self).get()
        } catch {
            return .failure(error as NSError)
        }
        return sign.makeUnsafeSignature().flatMap {
            self.commit(message: message, signature: $0).flatMap {
                commit(OID($0))
            }
        }
    }

    func isDescendant(of oid: OID, for base: OID) -> Result<Bool, NSError> {
        var oid1 = oid.oid
        var oid2 = base.oid
        let result = git_graph_descendant_of(self.pointer, &oid1, &oid2)
        switch result {
        case 0:
            return .success(false)
        case 1:
            return .success(true)
        default:
            return .failure(NSError(gitError: result, pointOfFailure: "git_graph_descendant_of"))
        }
    }

    func isDescendant(of oid: OID) -> Result<Bool, NSError> {
        return self.HEAD().flatMap {
            self.isDescendant(of: oid, for: $0.oid)
        }
    }
}
