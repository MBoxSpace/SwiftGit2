//
//  CleanOptions.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/8/13.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public struct CleanOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let force          = CleanOptions(rawValue: 1 << 0)
    public static let directory      = CleanOptions(rawValue: 1 << 1)
    public static let includeIgnored = CleanOptions(rawValue: 1 << 2)
    public static let onlyIgnored    = CleanOptions(rawValue: 1 << 3)

    public static let dryRun         = CleanOptions(rawValue: 1 << 4)
}

