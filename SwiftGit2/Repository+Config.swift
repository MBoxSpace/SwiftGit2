//
//  Repository+Config.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2019/11/28.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public extension Repository {
    private static func openConfig<T>(block: (OpaquePointer) -> Result<T, NSError>) -> Result<T, NSError> {
        var config: OpaquePointer?
        var result = git_config_open_default(&config)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_config_open_default"))
        }
        defer { git_config_free(config!) }

        var snapshot: OpaquePointer?
        result = git_config_snapshot(&snapshot, config!)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_config_snapshot"))
        }
        return block(snapshot!)
    }

    static func getConfig(for path: String) -> Result<String, NSError> {
        openConfig { config -> Result<String, NSError> in
            var value: UnsafePointer<Int8>?
            let result = path.withCString { git_config_get_string(&value, config, $0) }
            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_config_get_string"))
            }
            return .success(String(cString: value!))
        }
    }
}
