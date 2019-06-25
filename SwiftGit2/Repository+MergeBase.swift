//
//  Repository+MergeBase.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/20.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

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

}
