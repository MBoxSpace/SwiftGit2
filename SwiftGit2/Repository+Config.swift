//
//  Repository+Config.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/11/28.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
@_implementationOnly import git2

public extension Repository {
    var config: Config {
        return try! Config.open(repository: self).get()
    }

    var configPath: String? {
        var buf = git_buf()
        defer { git_buf_dispose(&buf) }
        guard git_repository_item_path(&buf, self.pointer, GIT_REPOSITORY_ITEM_CONFIG) == 0 else { return nil }
        return String(cString: buf.ptr)
    }

    var worktreeConfigPath: String? {
        var buf = git_buf()
        defer { git_buf_dispose(&buf) }
        guard git_repository_item_path(&buf, self.pointer, GIT_REPOSITORY_ITEM_GITDIR) == 0 else { return nil }
        let path = String(cString: buf.ptr)
        return NSString(string: path).appendingPathComponent("config.worktree")
    }

    func addConfig(path: String, level: Config.Level) -> Result<(), NSError> {
        path.withCString { (value) -> Result<(), NSError> in
            let result = git_config_add_file_ondisk(self.config.config, value,  git_config_level_t(rawValue: level.rawValue), self.pointer, 1)
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_config_add_file_ondisk"))
            }
            return .success(())
        }
    }

}
