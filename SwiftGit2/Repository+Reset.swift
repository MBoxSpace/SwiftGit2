//
//  Repository+Reset.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/20.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

public extension Repository {
    enum ResetType {
        case soft
        case mixed
        case hard

        var git_type: git_reset_t {
            switch self {
            case .soft:
	    	    return GIT_RESET_SOFT
            case .mixed:
	    	    return GIT_RESET_MIXED
            case .hard:
	    	    return GIT_RESET_HARD
            }
        }
    }

    func reset(reference: ReferenceType? = nil,
               type: ResetType = .mixed,
               progress: CheckoutProgressBlock? = nil) -> Result<(), NSError> {
        let ref: ReferenceType
        if let reference = reference {
            ref = reference
        } else {
            do {
                ref = try HEAD().get()
            } catch {
                return .failure(error as NSError)
            }
        }
        var object: OpaquePointer? = nil
        var oid = ref.oid.oid
        var result = git_object_lookup(&object, self.pointer, &oid, GIT_OBJ_ANY)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_object_lookup"))
        }

        var options = checkoutOptions(strategy: .Safe, progress: progress)

        result = git_reset(self.pointer, object, type.git_type, &options)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_reset"))
        }
        git_object_free(object)
        return .success(())
    }
}
