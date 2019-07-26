//
//  Repository+MergeBase.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/20.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

public struct GitMergeAnalysisStatus: OptionSet {
    public let rawValue: UInt32

    /**
     * A "normal" merge; both HEAD and the given merge input have diverged
     * from their common ancestor.  The divergent commits must be merged.
     */
    public static let normal = GitMergeAnalysisStatus(rawValue: 1 << 0)
    /**
     * All given merge inputs are reachable from HEAD, meaning the
     * repository is up-to-date and no merge needs to be performed.
     */
    public static let upToDate = GitMergeAnalysisStatus(rawValue: 1 << 1)
    /**
     * The given merge input is a fast-forward from HEAD and no merge
     * needs to be performed.  Instead, the client can check out the
     * given merge input.
     */
    public static let fastForward = GitMergeAnalysisStatus(rawValue: 1 << 2)
    /**
     * The HEAD of the current repository is "unborn" and does not point to
     * a valid commit.  No merge can be performed, but the caller may wish
     * to simply set HEAD to the target commit(s).
     */
    public static let unborn = GitMergeAnalysisStatus(rawValue: 1 << 3)

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

}

public extension Repository {

    func mergeBase(between oid1: OID, and oid2: OID) -> Result<OID, NSError> {
        var baseOID = git_oid()
        var oid1 = oid1.oid
        var oid2 = oid2.oid
        let result = git_merge_base(&baseOID, self.pointer, &oid1, &oid2)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_merge_base"))
        }
        return .success(OID(baseOID))
    }

    func mergeAnalyze(sourceOID: OID, targetBranch: Branch) -> Result<GitMergeAnalysisStatus, NSError> {
        if sourceOID == targetBranch.oid {
            return .success(.upToDate)
        }

        var annotatedCommit: OpaquePointer?
        defer { git_annotated_commit_free(annotatedCommit) }
        var oid = sourceOID.oid
        var result = git_annotated_commit_lookup(&annotatedCommit, self.pointer, &oid)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_annotated_commit_lookup"))
        }

        return reference(longName: targetBranch.longName) { targetRef -> Result<GitMergeAnalysisStatus, NSError> in
            var preference = GIT_MERGE_PREFERENCE_NONE
            var analysisResult: git_merge_analysis_t = GIT_MERGE_ANALYSIS_NONE
            result = git_merge_analysis_for_ref(&analysisResult,
                                                &preference,
                                                self.pointer,
                                                targetRef,
                                                &annotatedCommit,
                                                1)
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_merge_analysis_for_ref"))
            }

            return .success(GitMergeAnalysisStatus(rawValue: analysisResult.rawValue))
        }
    }

    func merge(from oid: OID, message: String) -> Result<GitMergeAnalysisStatus, NSError> {
        guard let targetBranch = try? self.HEAD().get() as? Branch else {
            return .failure(NSError(gitError: GIT_ERROR.rawValue, pointOfFailure: "Current Head is not a branch."))
        }

        do {
            if oid == targetBranch.oid {
                return .success(.upToDate)
            }

            let status = try mergeAnalyze(sourceOID: oid, targetBranch: targetBranch).get()
            if status.contains(.upToDate) {
                // Nothing to do
                return .success(.upToDate)
            } else if status.contains(.fastForward) || status.contains(.unborn) {
                // Fast-forward branch
                return self.update(reference: targetBranch.longName, to: oid).flatMap({
                    self.checkout(targetBranch.longName, CheckoutOptions(strategy: .Force)).flatMap {
                        .success(.fastForward)
                    }
                })
            } else {
                // Do normal merge
                var result: Int32

                var sourceCommit: OpaquePointer? = nil
                var git_oid = oid.oid
                defer { git_commit_free(sourceCommit) }
                result = git_commit_lookup(&sourceCommit, self.pointer, &git_oid)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result, pointOfFailure: "git_commit_lookup"))
                }


                var sourceTree: OpaquePointer? = nil
                result = git_commit_tree(&sourceTree, sourceCommit)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_commit_tree"))
                }

                var targetCommit: OpaquePointer? = nil
                git_oid = targetBranch.oid.oid
                defer { git_commit_free(targetCommit) }
                result = git_commit_lookup(&targetCommit, self.pointer, &git_oid)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result, pointOfFailure: "git_commit_lookup"))
                }

                var targetTree: OpaquePointer? = nil
                result = git_commit_tree(&targetTree, targetCommit)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_commit_tree"))
                }

                // Do a merge
                var mergeOptions = git_merge_options()
                result = git_merge_init_options(&mergeOptions, UInt32(GIT_MERGE_OPTIONS_VERSION))
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_merge_init_options"))
                }

                var checkoutOptions = git_checkout_options()
                result = git_checkout_init_options(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_checkout_init_options"))
                }

                checkoutOptions.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue | GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue

                var annotatedCommit: OpaquePointer?
                git_oid = oid.oid
                defer { git_annotated_commit_free(annotatedCommit) }
                result = git_annotated_commit_lookup(&annotatedCommit, self.pointer, &git_oid)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_annotated_commit_lookup"))
                }

                result = git_merge(self.pointer, &annotatedCommit, 1, &mergeOptions, &checkoutOptions)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_merge"))
                }

                // Check conflicts
                var index: OpaquePointer?
                defer { git_index_free(index) }
                result = git_repository_index(&index, self.pointer)
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result,
                                            pointOfFailure: "git_repository_index"))
                }

                if git_index_has_conflicts(index!) != 0 {
                    // Has Conflicts
                    git_error_set_str(Int32(GIT_ERROR_MERGE.rawValue), "There are some conflicts.")
                    return .failure(NSError(gitError: GIT_EMERGECONFLICT.rawValue, pointOfFailure: "git_merge_trees"))
                }

                // do a commit if no conflicts
                return Signature.default(self).flatMap {
                    $0.makeUnsafeSignature().flatMap {
                        self.commit(index: index!,
                                    parentCommits: [targetCommit, sourceCommit],
                                    message: message,
                                    signature: $0).flatMap { _ in
                                        git_repository_state_cleanup(self.pointer);
                                        return .success(.normal)
                        }
                    }
                }
            }
        } catch {
            return .failure(error as NSError)
        }

    }

}
