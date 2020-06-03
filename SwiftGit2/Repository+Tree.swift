//
//  Repository+Tree.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public extension Repository {
    func aheadBehind(local: OID, upstream: OID) -> Result<(ahead: size_t, behind: size_t), NSError> {
        var ahead: size_t = 0
        var behind: size_t = 0
        var localOID = local.oid
        var upstreamOID = upstream.oid
        let result = git_graph_ahead_behind(&ahead, &behind, self.pointer, &localOID, &upstreamOID)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_graph_ahead_behind"))
        }
        return .success((ahead: ahead, behind: behind))
    }

    func aheadBehind(local: Branch, upstream: Branch) -> Result<(ahead: size_t, behind: size_t), NSError> {
        return aheadBehind(local: local.oid, upstream: upstream.oid)
    }
}
