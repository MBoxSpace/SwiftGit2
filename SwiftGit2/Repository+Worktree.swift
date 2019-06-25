//
//  Repository+Worktree.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/14.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import libgit2

public extension Repository {

    func pruneWorkTrees() -> Result<(), NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        defer {
            git_strarray_free(pointer)
            pointer.deallocate()
        }

        let result = git_worktree_list(pointer, self.pointer)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_worktree_list"))
        }
        let strarray = pointer.pointee
        for index in 0..<strarray.count {
            let name = strarray.strings[index]!
            var wtPointer: OpaquePointer? = nil

            let result = git_worktree_lookup(&wtPointer, self.pointer, name)
            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_worktree_lookup"))
            }

            let options = UnsafeMutablePointer<git_worktree_prune_options>.allocate(capacity: 1)
            defer { options.deallocate() }
            let optionsResult = git_worktree_prune_init_options(options, UInt32(GIT_WORKTREE_PRUNE_OPTIONS_VERSION))
            guard optionsResult == GIT_OK.rawValue else {
                return .failure(NSError(gitError: optionsResult, pointOfFailure: "git_worktree_prune_init_options"))
            }

            let result2 = git_worktree_prune(wtPointer, options)
            guard result2 == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result2, pointOfFailure: "git_worktree_prune"))
            }
        }
        return .success(())
    }

}
