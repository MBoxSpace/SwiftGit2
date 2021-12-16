//
//  Items.swift
//  SwiftGit2-MBox
//
//  Created by 詹迟晶 on 2021/4/15.
//

import Foundation
@_implementationOnly import git2

extension Repository {
    public enum Item {
        case gitDir
        case workDir
        case commonDir
        case index
        case objects
        case refs
        case packedRefs
        case remotes
        case config
        case info
        case hooks
        case logs
        case modules
        case worktrees
        case LAST

        internal func toGit() -> git_repository_item_t {
            switch self {
            case .gitDir:
                return GIT_REPOSITORY_ITEM_GITDIR
            case .workDir:
                return GIT_REPOSITORY_ITEM_WORKDIR
            case .commonDir:
                return GIT_REPOSITORY_ITEM_COMMONDIR
            case .index:
                return GIT_REPOSITORY_ITEM_INDEX
            case .objects:
                return GIT_REPOSITORY_ITEM_OBJECTS
            case .refs:
                return GIT_REPOSITORY_ITEM_REFS
            case .packedRefs:
                return GIT_REPOSITORY_ITEM_PACKED_REFS
            case .remotes:
                return GIT_REPOSITORY_ITEM_REMOTES
            case .config:
                return GIT_REPOSITORY_ITEM_CONFIG
            case .info:
                return GIT_REPOSITORY_ITEM_INFO
            case .hooks:
                return GIT_REPOSITORY_ITEM_HOOKS
            case .logs:
                return GIT_REPOSITORY_ITEM_LOGS
            case .modules:
                return GIT_REPOSITORY_ITEM_MODULES
            case .worktrees:
                return GIT_REPOSITORY_ITEM_WORKTREES
            case .LAST:
                return GIT_REPOSITORY_ITEM__LAST
            }
        }
    }

}
