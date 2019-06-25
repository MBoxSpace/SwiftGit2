//
//  Repositor+Stash.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/17.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

public typealias StashEachBlock = (Int, String, OID) -> Bool

/// Helper function used as the libgit2 progress callback in git_stash_foreach.
/// This is a function with a type signature of git_stash_cb.
/// return 0 to continue iterating or non-zero to stop.
private func stashForEachCallback(index: Int,
                                  message: UnsafePointer<Int8>?,
                                  stash_id: UnsafePointer<git_oid>?,
                                  payload: UnsafeMutableRawPointer?) -> Int32 {
    guard let payload = payload,
        let msg = message.flatMap(String.init(validatingUTF8:)),
        let oid = stash_id.flatMap({ $0.pointee }) else {
        return 1
    }

    let buffer = payload.assumingMemoryBound(to: StashEachBlock.self)
    let block = buffer.pointee
    if !block(index, msg, OID(oid)) {
        return 1
    }
    return 0
}

public extension Repository {

    func forEachStash(block: @escaping StashEachBlock) {
        let blockPointer = UnsafeMutablePointer<StashEachBlock>.allocate(capacity: 1)
        blockPointer.initialize(repeating: block, count: 1)
        git_stash_foreach(self.pointer, stashForEachCallback, UnsafeMutableRawPointer(blockPointer))
        blockPointer.deallocate()
    }

    func save(stash: String, keepIndex: Bool = false, includeUntrack: Bool = false, includeIgnore: Bool = false) -> Result<OID, NSError> {
        var flags: UInt32 = GIT_STASH_DEFAULT.rawValue
        if keepIndex {
            flags += GIT_STASH_KEEP_INDEX.rawValue
        }
        if includeUntrack {
            flags += GIT_STASH_INCLUDE_UNTRACKED.rawValue
        }
        if includeIgnore {
            flags += GIT_STASH_INCLUDE_IGNORED.rawValue
        }
        return Signature.default(self).flatMap { signature -> Result<OID, NSError> in
            signature.makeUnsafeSignature().flatMap { signature -> Result<OID, NSError> in
                var gitOID = git_oid()
                let result = git_stash_save(&gitOID, self.pointer, signature, stash, flags)
                if result != GIT_OK.rawValue {
                    return .failure(NSError(gitError: result, pointOfFailure: "git_stash_save"))
                }
                return .success(OID(gitOID))
            }
        }
    }

    func apply(stash: Int, index: Bool = false) -> Result<(), NSError> {
        // Do this because GIT_STASH_APPLY_OPTIONS_INIT is unavailable in swift
        let applyOptionsPointer = UnsafeMutablePointer<git_stash_apply_options>.allocate(capacity: 1)
        git_stash_apply_init_options(applyOptionsPointer, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))
        var applyOptions = applyOptionsPointer.move()
        applyOptionsPointer.deallocate()

        if index { applyOptions.flags = GIT_STASH_APPLY_REINSTATE_INDEX }

        let result = git_stash_apply(self.pointer, stash, &applyOptions)
        if result != GIT_OK.rawValue {
            return .failure(NSError(gitError: result, pointOfFailure: "git_stash_apply"))
        }
        return .success(())
    }

    func pop(stash: Int, index: Bool = false) -> Result<(), NSError> {
        // Do this because GIT_STASH_APPLY_OPTIONS_INIT is unavailable in swift
        let applyOptionsPointer = UnsafeMutablePointer<git_stash_apply_options>.allocate(capacity: 1)
        git_stash_apply_init_options(applyOptionsPointer, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))
        var applyOptions = applyOptionsPointer.move()
        applyOptionsPointer.deallocate()

        if index { applyOptions.flags = GIT_STASH_APPLY_REINSTATE_INDEX }

        let result = git_stash_pop(self.pointer, stash, &applyOptions)
        if result != GIT_OK.rawValue {
            return .failure(NSError(gitError: result, pointOfFailure: "git_stash_pop"))
        }
        return .success(())

    }

    func drop(stash: Int) -> Result<(), NSError> {
        let result = git_stash_drop(self.pointer, stash)
        if result != GIT_OK.rawValue {
            return .failure(NSError(gitError: result, pointOfFailure: "git_stash_drop"))
        }
        return .success(())
    }

}
