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
private func sidebandTransportCallback(str: UnsafePointer<Int8>?, len: Int32, payload: UnsafeMutableRawPointer?) -> Int32 {
    guard let str = str else {
        return 0
    }
    if let info = String(bytes: str, count: Int(len)),
        let payload = payload,
        let block = RemoteCallback.fromPointer(payload).messageBlock {
        block("remote: " + info.replacingOccurrences(of: "([\r\n]+)[^\r\n$]", with: "$1remote: ", options: .regularExpression))
    }
    return 0
}

private func transferProgressCallback(stats: UnsafePointer<git_transfer_progress>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    if let payload = payload, let progress = stats?.pointee {
        let callback = RemoteCallback.fromPointer(payload)

        if let block = callback.messageBlock {
            if (!callback.transferFinish && progress.received_objects <= progress.total_objects) {
                if callback.updateLastTime(force: progress.received_objects >= progress.total_objects) {
                    if progress.received_objects < progress.total_objects {
                        let percent = progress.total_objects > 0 ? Float(100 * progress.received_objects) / Float(progress.total_objects) : 0
                        block("Receiving objects: \(Int(percent))% (\(progress.received_objects)/\(progress.total_objects)), \(callback.fileSizeDescription(Float(progress.received_bytes))) | \(callback.transferSpeed(progress.received_bytes))\r")
                    } else {
                        block("Receiving objects: 100% (\(progress.received_objects)/\(progress.total_objects)), \(callback.fileSizeDescription(Float(progress.received_bytes))) | \(callback.lastTransferSpeed), done.\n")
                        callback.transferFinish = true
                    }
                }
            }
            if (progress.total_objects > 0 && callback.transferFinish) {
                if callback.updateLastTime(force: progress.indexed_objects >= progress.total_objects) {
                    if progress.indexed_objects < progress.total_objects {
                        let percent = progress.total_objects > 0 ? Float((100 * progress.indexed_objects)) / Float(progress.total_objects) : 0
                        block("Resolving deltas: \(Int(percent))% (\(progress.indexed_objects)/\(progress.total_objects))\r")
                    } else {
                        block("Resolving deltas: 100% (\(progress.indexed_objects)/\(progress.total_objects)), done.\n")
                        callback.indexFinish = true
                    }
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

private func pushNegotiationCallback(updates: UnsafeMutablePointer<UnsafePointer<git_push_update>?>?, len: size_t, payload: UnsafeMutableRawPointer?) -> Int32 {
    var status = false
    if let payload = payload, let updates = updates?.pointee {
        let callback = RemoteCallback.fromPointer(payload)
        if let block = callback.messageBlock {
            for i in 0..<len {
                let data = updates[i]
                var dst_refname = String(cString: data.dst_refname)
                if dst_refname.hasPrefix("refs/remotes/") {
                    dst_refname = String(dst_refname.dropFirst("refs/remotes/".count))
                }
                let src_oid = OID(data.src)
                let dst_oid = OID(data.dst)
                var msg = updateDescription(src_oid, dst_oid) + "  "
                msg.append(dst_refname)
                msg.append("\n")
                block(msg)
                status = status || (src_oid != dst_oid)
            }
        }
    }
    return status ? 0 : -1
}

private func pushUpdateReferenceCallback(refname: UnsafePointer<Int8>?, status: UnsafePointer<Int8>?, data: UnsafeMutableRawPointer?) -> Int32 {
    if let refname = refname, let status = status, let payload = data {
        let callback = RemoteCallback.fromPointer(payload)
        if let block = callback.messageBlock {
            let name = String(cString: refname)
            let msg = String(cString: status)
            block("\(name) \(msg)\n")
        }
    }
    return 0
}

private func pushTransferProgress(current: UInt32, total: UInt32, bytes: size_t, payload: UnsafeMutableRawPointer?) -> Int32 {
    if total > 0, let payload = payload {
        let callback = RemoteCallback.fromPointer(payload)
        if let block = callback.messageBlock, callback.updateLastTime(force: current >= total) {
            var msg = "Sending \(current)/\(total) \(callback.fileSizeDescription(Float(bytes)))"
            if current >= total {
                msg.append(", done.\n")
            } else {
                msg.append("\r")
            }
            block(msg)
        }
    }
    return 0
}

private func updateTipsCallback(refname: UnsafePointer<Int8>?, a: UnsafePointer<git_oid>?, b: UnsafePointer<git_oid>?, data: UnsafeMutableRawPointer?) -> Int32 {
    if let refname = refname, let payload = data {
        let callback = RemoteCallback.fromPointer(payload)
        if let block = callback.messageBlock {
            var oldOID: OID? = nil
            if let old_oid = a?.pointee {
               oldOID = OID(old_oid)
            }
            var newOID: OID? = nil
            if let new_oid = b?.pointee {
                newOID = OID(new_oid)
            }
            if oldOID != newOID {
                var name = String(cString: refname)
                if name.hasPrefix("refs/remotes/") {
                    name = String(name.dropFirst("refs/remotes/".count))
                }
                block("\(updateDescription(oldOID, newOID))  \(name)\n")
            }
        }
    }
    return 0
}

private func updateDescription(_ oid1: OID?, _ oid2: OID?) -> String {
    var msg = ""
    if oid1 == oid2 {
        msg.append(" = [up to date]")
    } else if oid1 == nil || oid1!.isZero {
        msg.append(" * [new branch]")
    } else if oid2 == nil || oid2!.isZero {
        msg.append(" - [deleted]")
    } else {
        msg.append("   \(oid1!.desc(length: 10))..\(oid2!.desc(length: 10))")
    }
    msg.append(String(repeating: " ", count: 25 - msg.count))
    return msg
}

var userSSHConfigFile: SSH2.ConfigFile?

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

    public var url: GitURL?
    public var credentials: [Credentials] = []
    public var avaliableCredentials: [Credentials]
    public var messageBlock: MessageBlock?
    public var progressBlock: ProgressBlock?

    public enum Mode {
        case Fetch
        case Pull
        case Clone
        case Push
    }
    public var mode: Mode

    public init(mode: Mode = .Fetch,
                url: String,
                messageBlock: MessageBlock? = nil,
                progressBlock: ProgressBlock? = nil) {
        self.mode = mode
        self.messageBlock = messageBlock
        self.progressBlock = progressBlock

        self.url = GitURL(url)
        if userSSHConfigFile == nil {
            let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config").path
            if FileManager.default.fileExists(atPath: configPath) {
                userSSHConfigFile = SSH2.ConfigFile.parse(configPath)
            }
        }
        if let host = self.url?.host,
            self.url?.scheme == "ssh",
            let user = self.url?.user {
            if let configFile = userSSHConfigFile,
                let config = configFile.config(for: host) {
                for file in config.identityFiles ?? [] {
                    self.credentials.append(.sshFile(username: user, publicKeyPath: file + ".pub", privateKeyPath: file, passphrase: ""))
                }
            }
            let defaultIDs = ["id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "id_xmss"].flatMap { [$0, $0 + "-cert"] }
            for name in defaultIDs {
                let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh").appendingPathComponent(name).path
                if FileManager.default.fileExists(atPath: path) {
                    self.credentials.append(.sshFile(username: user, publicKeyPath: path + ".pub", privateKeyPath: path, passphrase: ""))
                }
            }
        }
        self.credentials.append(.sshAgent)
        self.credentials.append(.default)
        self.avaliableCredentials = self.credentials
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
            callback.sideband_progress = sidebandTransportCallback
            if mode == .Push {
                callback.push_negotiation = pushNegotiationCallback
                callback.push_update_reference = pushUpdateReferenceCallback
                callback.push_transfer_progress = pushTransferProgress
            }
//            if mode == .Fetch || mode == .Pull {
//                callback.update_tips = updateTipsCallback
//            }
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
    internal func updateLastTime(force: Bool) -> Bool {
        let current = CACurrentMediaTime()
        if let lastTime = self.lastTime {
            let timeDelta = current - lastTime
            if !force && timeDelta < 1 { return false }
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
