//
//  Repository+Clean.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/8/13.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public extension Repository {
    func clean(_ options: CleanOptions, shouldRemove: ((String) -> Bool)? = nil) -> Result<[String], NSError> {
        return status().flatMap { entries -> Result<[String], NSError> in
            let s = entries.filter({ entry -> Bool in
                if entry.status == .workTreeNew && !options.contains(.onlyIgnored) {
                    return true
                } else if entry.status == .ignored && (options.contains(.includeIgnored) || options.contains(.onlyIgnored)) {
                    return true
                }
                return false
            }).compactMap { $0.indexToWorkDir?.newFile?.path }
            if !options.contains(.dryRun) {
                for path in s {
                    if let block = shouldRemove, !block(path) {
                        continue
                    }
                    guard let url = directoryURL?.appendingPathComponent(path) else { continue }
                    try? FileManager.default.removeItem(at: url)
                }
            }
            return .success(s)
        }
    }
}
