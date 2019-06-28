//
//  FetchOptions.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/27.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

/**
 * Type for messages delivered by the transport.  Return a negative value
 * to cancel the network operation.
 *
 * @param str The message from the transport
 * @param len The length of the message
 * @param payload Payload provided by the caller
 */
private func transportMessageCallback(str: UnsafePointer<Int8>?, len: Int32, payload: UnsafeMutableRawPointer?) -> Int32 {
    guard let str = str else {
        return 0
    }
    let info = String(bytes: str, count: Int(len))
    if let payload = payload,
        let block = RemoteCallback.fromPointer(payload).messageBlock {
        block(info)
    }
    return 0
}

private func transferProgressCallback(stats: UnsafePointer<git_transfer_progress>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    if let payload = payload,
        let block = RemoteCallback.fromPointer(payload).progressBlock,
        let progress = stats?.pointee {
        block(progress.total_objects,
              progress.indexed_objects,
              progress.received_objects,
              progress.local_objects,
              progress.total_deltas,
              progress.indexed_deltas)
    }

    return 0
}

public class RemoteCallback {
    public typealias MessageBlock = (String?) -> Void
    public typealias ProgressBlock = (
        _ total_objects: UInt32,
        _ indexed_objects: UInt32,
        _ received_objects: UInt32,
        _ local_objects: UInt32,
        _ total_deltas: UInt32,
        _ indexed_deltas: UInt32) -> Void

    public var credentials: Credentials
    public var messageBlock: MessageBlock?
    public var progressBlock: ProgressBlock?

    public init(credentials: Credentials = .default,
                messageBlock: MessageBlock? = nil,
                progressBlock: ProgressBlock? = nil) {
        self.credentials = credentials
        self.messageBlock = messageBlock
        self.progressBlock = progressBlock
    }

    static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> RemoteCallback {
        return Unmanaged<RemoteCallback>.fromOpaque(pointer).takeUnretainedValue()
    }

    func toPointer() -> UnsafeMutableRawPointer {
        return Unmanaged.passRetained(self).toOpaque()
    }

    func toGit() -> git_remote_callbacks {
        let pointer = UnsafeMutablePointer<git_remote_callbacks>.allocate(capacity: 1)
        git_remote_init_callbacks(pointer, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
        var callback = pointer.pointee
        pointer.deallocate()

        callback.credentials = credentialsCallback
        if messageBlock != nil {
            callback.sideband_progress = transportMessageCallback
        }
        if progressBlock != nil {
            callback.transfer_progress = transferProgressCallback
        }
        callback.payload = self.toPointer()
        return callback
    }
}

public class FetchOptions {
    public typealias MessageBlock = RemoteCallback.MessageBlock
    public typealias ProgressBlock = RemoteCallback.ProgressBlock

    public var tags: Bool
    public var prune: Bool
    public var remoteCallback: RemoteCallback

    public init(tags: Bool = true,
                prune: Bool = false,
                credentials: Credentials = .default,
                messageBlock: MessageBlock? = nil,
                progressBlock: ProgressBlock? = nil) {
        self.tags = tags
        self.prune = prune
        self.remoteCallback = RemoteCallback(credentials: credentials,
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
