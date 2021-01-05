//
//  Submodule+Status.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2020/3/8.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import git2

extension Submodule {
    struct Status: OptionSet {
        let rawValue: UInt32

        static let inHead = Status(rawValue: GIT_SUBMODULE_STATUS_IN_HEAD.rawValue)
        static let inIndex = Status(rawValue: GIT_SUBMODULE_STATUS_IN_INDEX.rawValue)
        static let inConfig = Status(rawValue: GIT_SUBMODULE_STATUS_IN_CONFIG.rawValue)
        static let inWorkingDirectory = Status(rawValue: GIT_SUBMODULE_STATUS_IN_WD.rawValue)

        static let indexAdded = Status(rawValue: GIT_SUBMODULE_STATUS_INDEX_ADDED.rawValue)
        static let indexDeleted = Status(rawValue: GIT_SUBMODULE_STATUS_INDEX_DELETED.rawValue)
        static let indexModified = Status(rawValue: GIT_SUBMODULE_STATUS_INDEX_MODIFIED.rawValue)

        static let wdUninitialized = Status(rawValue: GIT_SUBMODULE_STATUS_WD_UNINITIALIZED.rawValue)
        static let wdAdded = Status(rawValue: GIT_SUBMODULE_STATUS_WD_ADDED.rawValue)
        static let wdDeleted = Status(rawValue: GIT_SUBMODULE_STATUS_WD_DELETED.rawValue)
        static let wdModified = Status(rawValue: GIT_SUBMODULE_STATUS_WD_MODIFIED.rawValue)
        static let wdIndexModified = Status(rawValue: GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED.rawValue)
        static let wdWDModified = Status(rawValue: GIT_SUBMODULE_STATUS_WD_WD_MODIFIED.rawValue)
        static let wdUntracked = Status(rawValue: GIT_SUBMODULE_STATUS_WD_UNTRACKED.rawValue)

        static let `in`: Status = Status(rawValue: GIT_SUBMODULE_STATUS__IN_FLAGS)
        static let index: Status = Status(rawValue: GIT_SUBMODULE_STATUS__INDEX_FLAGS)
        static let wd: Status = Status(rawValue: GIT_SUBMODULE_STATUS__WD_FLAGS)

        var isUnmodified: Bool {
            return ~(Status.`in`.rawValue) & self.rawValue == 0
        }
        var isIndexUnmodified: Bool {
            return Status.index.rawValue & self.rawValue == 0
        }
        var isWDUnmodified: Bool {
            return self.rawValue & (Status.wd.rawValue &
                ~(Status.wdUninitialized.rawValue)) == 0
        }
        var isWDDirty: Bool {
            return self.rawValue & (Status.wdIndexModified.rawValue | Status.wdWDModified.rawValue | Status.wdUntracked.rawValue) != 0
        }
    }

    public enum Recurse: UInt32 {
        /// do no recurse into submodules
        case no = 0 // GIT_SUBMODULE_RECURSE_NO

        /// recurse into submodules
        case yes = 1 // GIT_SUBMODULE_RECURSE_YES

        /// recurse into submodules only when commit not already in local clone
        case ondemand = 2 // GIT_SUBMODULE_RECURSE_ONDEMAND

        init(git: git_submodule_recurse_t) {
            self.init(rawValue: git.rawValue)!
        }

        func toGit() -> git_submodule_recurse_t {
            return git_submodule_recurse_t(rawValue: self.rawValue)
        }
    }
}
