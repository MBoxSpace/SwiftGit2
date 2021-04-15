//
//  Repository+Worktree.swift
//  MBoxGit
//
//  Created by Whirlwind on 2019/6/14.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import git2

public extension Repository {

    var isWorkTree: Bool {
        return git_repository_is_worktree(self.pointer) == 1
    }

    func pruneWorkTree(_ name: String, force: Bool = false) -> Result<String?, NSError> {
        var wtPointer: OpaquePointer? = nil

        let result = git_worktree_lookup(&wtPointer, self.pointer, name)
        guard result == GIT_OK.rawValue else {
            return .success(nil)
        }

        let path = String(cString: git_worktree_path(wtPointer))

        let options = UnsafeMutablePointer<git_worktree_prune_options>.allocate(capacity: 1)
        defer { options.deallocate() }
        let optionsResult = git_worktree_prune_options_init(options, UInt32(GIT_WORKTREE_PRUNE_OPTIONS_VERSION))
        guard optionsResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: optionsResult, pointOfFailure: "git_worktree_prune_options_init"))
        }

        if force {
            options.pointee.flags = GIT_WORKTREE_PRUNE_VALID.rawValue | GIT_WORKTREE_PRUNE_LOCKED.rawValue
        } else {
            let valid = git_worktree_validate(wtPointer) == 0
            if valid {
                // libgit2 have a bug, it does not check the worktree path exists.
                var isDirectory: ObjCBool = false
                if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                    options.pointee.flags = options.pointee.flags | GIT_WORKTREE_PRUNE_VALID.rawValue
                }
            }
        }

        let prunable = git_worktree_is_prunable(wtPointer, options) > 0
        if prunable {
            let result2 = git_worktree_prune(wtPointer, options)
            guard result2 == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result2, pointOfFailure: "git_worktree_prune"))
            }
            return .success(path)
        }
        return .success(nil)
    }

    func pruneWorkTrees(all: Bool = false) -> Result<[String], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        defer {
            git_strarray_dispose(pointer)
            pointer.deallocate()
        }

        let result = git_worktree_list(pointer, self.pointer)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_worktree_list"))
        }

        var pruned = [String]()

        let strarray = pointer.pointee
        for index in 0..<strarray.count {
            let name = strarray.strings[index]!
            do {
                if let path = try pruneWorkTree(String(cString: name), force: all).get() {
                    pruned.append(path)
                }
            } catch {
                return .failure(error as NSError)
            }
        }
        return .success(pruned)
    }

    func addWorkTree(name: String, path: String, head: String? = nil) -> Result<(), NSError> {
        let options = UnsafeMutablePointer<git_worktree_add_options>.allocate(capacity: 1)
        defer { options.deallocate() }
        var result = git_worktree_add_options_init(options, UInt32(GIT_WORKTREE_ADD_OPTIONS_VERSION))
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_worktree_add_init_options"))
        }

        var reference: OpaquePointer? = nil
        defer {
            git_reference_free(reference)
        }
        if let head = head {
            if head.isLongRef || head.isHEAD {
                let result = git_reference_lookup(&reference, self.pointer, head)
                guard result == GIT_OK.rawValue else {
                    return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_lookup"))
                }
            } else {
                let result = git_reference_dwim(&reference, self.pointer, head)
                guard result == GIT_OK.rawValue else {
                    return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_dwim"))
                }
            }
        }
        options.pointee.ref = reference

        var worktree: OpaquePointer?
        result = name.withCString { cName -> Int32 in
            path.withCString { cPath -> Int32 in
                git_worktree_add(&worktree, self.pointer, cName, cPath, options)
            }
        }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_worktree_add"))
        }
        if head == nil {
            return Repository.at(URL(fileURLWithPath: path)).flatMap { repo -> Result<(), NSError> in
                repo.HEAD().flatMap { repo.setHEAD($0.oid) }.flatMap { repo.deleteBranch(name) }
            }
        } else {
            return .success(())
        }
    }
}
