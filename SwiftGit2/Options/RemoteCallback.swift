//
//  RemoteCallback.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Cocoa
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
