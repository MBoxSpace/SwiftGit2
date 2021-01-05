//
//  StatusOptions.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2020/3/9.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public struct StatusOptions: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let includeUntracked              = StatusOptions(rawValue: 1 << 0)
    public static let includeIgnored                = StatusOptions(rawValue: 1 << 1)
    public static let includeUnmodified             = StatusOptions(rawValue: 1 << 2)
    public static let excludeSubmodules             = StatusOptions(rawValue: 1 << 3)
    public static let recurseUntrackedDirs          = StatusOptions(rawValue: 1 << 4)
    public static let disablePathspecMatch          = StatusOptions(rawValue: 1 << 5)
    public static let recurseIgnoredDirs            = StatusOptions(rawValue: 1 << 6)
    public static let renamesHeadToIndex            = StatusOptions(rawValue: 1 << 7)
    public static let renamesIndexToWorkdir         = StatusOptions(rawValue: 1 << 8)
    public static let sortCaseSensitively           = StatusOptions(rawValue: 1 << 9)
    public static let sortCaseInsensitively         = StatusOptions(rawValue: 1 << 10)
    public static let renamesFromRewrites           = StatusOptions(rawValue: 1 << 11)
    public static let noRefresh                     = StatusOptions(rawValue: 1 << 12)
    public static let updateIndex                   = StatusOptions(rawValue: 1 << 13)
    public static let includeUnreadable             = StatusOptions(rawValue: 1 << 14)
    public static let includeUnreadableAsUntracked  = StatusOptions(rawValue: 1 << 15)
}
