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
    if let info = String(bytes: str, count: Int(len)),
        let payload = payload,
        let block = RemoteCallback.fromPointer(payload).messageBlock {
        block("remote: " + info.replacingOccurrences(of: "(\n+)[^\n$]", with: "$1remote: ", options: .regularExpression))
    }
    return 0
}

private func transferProgressCallback(stats: UnsafePointer<git_transfer_progress>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    if let payload = payload, let progress = stats?.pointee {
        let callback = RemoteCallback.fromPointer(payload)

        if let block = callback.messageBlock {
            let perform = callback.updateLastTime()
            if (!callback.transferFinish && progress.received_objects <= progress.total_objects) {
                if progress.received_objects < progress.total_objects {
                    if perform {
                        let percent = progress.total_objects > 0 ? Float(100 * progress.received_objects) / Float(progress.total_objects) : 0
                        block("Receiving objects: \(Int(percent))% (\(progress.received_objects)/\(progress.total_objects)), \(callback.fileSizeDescription(Float(progress.received_bytes))) | \(callback.transferSpeed(progress.received_bytes))\r")
                    }
                } else {
                    block("Receiving objects: 100% (\(progress.received_objects)/\(progress.total_objects)), \(callback.fileSizeDescription(Float(progress.received_bytes))) | \(callback.lastTransferSpeed), done.\n")
                    callback.transferFinish = true
                }
            }
            if (progress.total_objects > 0 && callback.transferFinish) {
                if progress.indexed_objects < progress.total_objects {
                    if perform {
                        let percent = progress.total_objects > 0 ? Float((100 * progress.indexed_objects)) / Float(progress.total_objects) : 0
                        block("Resolving deltas: \(Int(percent))% (\(progress.indexed_objects)/\(progress.total_objects))\r")
                    }
                } else {
                    block("Resolving deltas: 100% (\(progress.indexed_objects)/\(progress.total_objects)), done.\n")
                    callback.indexFinish = true
                }
            }
        }

        if let block = callback.progressBlock {
            block(progress.total_objects,
                  progress.indexed_objects,
                  progress.received_objects,
                  progress.local_objects,
                  progress.total_deltas,
                  progress.indexed_deltas,
                  progress.received_bytes)
        }
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
        _ indexed_deltas: UInt32,
        _ received_bytes: size_t) -> Void

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
        if messageBlock != nil || progressBlock != nil {
            callback.transfer_progress = transferProgressCallback
        }
        callback.payload = self.toPointer()
        return callback
    }

    // MARK: - Internal
    internal var lastTime: CFAbsoluteTime? = nil
    internal var lastTimeInterval: CFTimeInterval = 0
    internal func updateLastTime() -> Bool {
        let current = CACurrentMediaTime()
        if let lastTime = self.lastTime {
            let timeDelta = current - lastTime
            if timeDelta < 1 { return false }
            self.lastTimeInterval = timeDelta
        }
        self.lastTime = current
        return true
    }

    internal var lastTransferBytes: size_t = 0
    internal var lastTransferSpeed: String = "0 Byte/s"
    internal var transferFinish: Bool = false
    internal var indexFinish: Bool = false
    internal func transferSpeed(_ bytes: size_t) -> String {
        let speed: String
        let bytesDelta = bytes - lastTransferBytes
        if lastTimeInterval > 0 {
            speed = fileSizeDescription(Float(bytesDelta) / Float(lastTimeInterval)) + "/s"
        } else {
            speed = fileSizeDescription(Float(bytesDelta)) + "/s"
        }
        lastTransferBytes = bytes
        lastTransferSpeed = speed
        return speed
    }

    internal func fileSizeDescription(_ bytes: Float) -> String {
        if bytes > (1024 * 1024) {
            return String(format: "%.2f MiB", bytes / (1024*1024))
        } else if bytes > 1024 {
            return String(format: "%.2f KiB", bytes / 1024)
        } else {
            return "\(Int(bytes)) Byte"
        }
    }
}
