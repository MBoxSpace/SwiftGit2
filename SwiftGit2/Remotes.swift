//
//  Remotes.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 1/2/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

import git2

/// A remote in a git repository.
public struct Remote: Hashable {
    public enum Direction: Int32 {
        case Fetch = 0 // GIT_DIRECTION_FETCH
        case Push  = 1 //GIT_DIRECTION_PUSH
    }

    /// The name of the remote.
    public let name: String

    /// The URL of the remote.
    ///
    /// This may be an SSH URL, which isn't representable using `NSURL`.
    public let URL: String?

    /// The Push URL of the remote.
    ///
    /// This may be an SSH URL, which isn't representable using `NSURL`.
    public let pushURL: String?

    /// Create an instance with a libgit2 `git_remote`.
    public init(_ pointer: OpaquePointer) {
        name = String(validatingUTF8: git_remote_name(pointer))!
        if let url = git_remote_url(pointer) {
            URL = String(validatingUTF8: url)
        } else {
            URL = nil
        }
        if let url = git_remote_pushurl(pointer) {
            pushURL = String(validatingUTF8: url)
        } else {
            pushURL = nil
        }
    }
}
