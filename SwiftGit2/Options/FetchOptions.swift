//
//  FetchOptions.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/27.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public class FetchOptions {
    public typealias MessageBlock = RemoteCallback.MessageBlock
    public typealias ProgressBlock = RemoteCallback.ProgressBlock

    public var tags: Bool
    public var prune: Bool
    public var remoteCallback: RemoteCallback

    public init(url: String,
                tags: Bool = true,
                prune: Bool = false,
                credentials: Credentials = .default,
                messageBlock: MessageBlock? = nil,
                progressBlock: ProgressBlock? = nil) {
        self.tags = tags
        self.prune = prune
        self.remoteCallback = RemoteCallback(url: url,
                                             messageBlock: messageBlock,
                                             progressBlock: progressBlock)
    }

    func toGit() -> git_fetch_options {
        let pointer = UnsafeMutablePointer<git_fetch_options>.allocate(capacity: 1)
        git_fetch_init_options(pointer, UInt32(GIT_FETCH_OPTIONS_VERSION))

        var options = pointer.move()

        pointer.deallocate()

        if tags {
            options.download_tags = GIT_REMOTE_DOWNLOAD_TAGS_ALL
        }
        if prune {
            options.prune = GIT_FETCH_PRUNE
        }

        options.callbacks = remoteCallback.toGit()

        return options
    }
}
