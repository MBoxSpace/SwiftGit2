//
//  Credentials.swift
//  SwiftGit2
//
//  Created by Tom Booth on 29/02/2016.
//  Copyright © 2016 GitHub, Inc. All rights reserved.
//

import libgit2

private class Wrapper<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
    deinit {

    }
}

public enum Credentials: Equatable {
    case `default`
    case username(String)
    case plaintext(username: String, password: String)
    case sshAgent
    case sshFile(username: String, publicKeyPath: String, privateKeyPath: String, passphrase: String)
    case sshMemory(username: String, publicKey: String, privateKey: String, passphrase: String)

    /// see `git_credtype_t`
    internal var type: git_credtype_t {
        switch self {
        case .default:
            return GIT_CREDTYPE_DEFAULT
        case .username:
            return GIT_CREDTYPE_USERNAME
        case .plaintext:
            return GIT_CREDTYPE_USERPASS_PLAINTEXT
        case .sshAgent:
            return git_credtype_t(rawValue: GIT_CREDTYPE_SSH_MEMORY.rawValue + GIT_CREDTYPE_SSH_KEY.rawValue)
        case .sshFile:
            return GIT_CREDTYPE_SSH_KEY
        case .sshMemory:
            return GIT_CREDTYPE_SSH_MEMORY
        }
    }

    internal func allowed(by code: UInt32) -> Bool {
        return code & self.type.rawValue > 0
    }

    public static func == (lhs: Credentials, rhs: Credentials) -> Bool {
        switch (lhs, rhs) {
        case (.default, .default),
             (.username, .username),
             (.plaintext, .plaintext),
             (.sshAgent, .sshAgent),
             (.sshFile, .sshFile),
             (.sshMemory, .sshMemory):
            return true
        default:
            return false
        }
    }
}

/// Handle the request of credentials, passing through to a wrapped block after converting the arguments.
/// Converts the result to the correct error code required by libgit2 (0 = success, 1 = rejected setting creds,
/// -1 = error)
internal func credentialsCallback(
    cred: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
    url: UnsafePointer<CChar>?,
    username: UnsafePointer<CChar>?,
    allowTypes: UInt32,
    payload: UnsafeMutableRawPointer? ) -> Int32 {

    let result: Int32

    // Find username_from_url
    let name = username.map(String.init(cString:))

    var credentials = RemoteCallback.fromPointer(payload!).credentials
    if (credentials == .default) && name == "git" {
        // SSH protocol use sshAgent
        credentials = .sshAgent
    }

    if !credentials.allowed(by: allowTypes) {
        return -1
    }

    switch credentials {
    case .default:
        result = git_cred_default_new(cred)
    case .username(let username):
        result = git_cred_username_new(cred, username)
    case .plaintext(let username, let password):
        result = git_cred_userpass_plaintext_new(cred, username, password)
    case .sshAgent:
        result = git_cred_ssh_key_from_agent(cred, name!)
    case .sshFile(let username, let publicKeyPath, let privateKeyPath, _):
        result = git_cred_ssh_key_new(cred, username, publicKeyPath, privateKeyPath, "")
    case .sshMemory(let username, let publicKey, let privateKey, let passphrase):
        result = git_cred_ssh_key_memory_new(cred, username, publicKey, privateKey, passphrase)
    }

    return (result != GIT_OK.rawValue) ? -1 : 0
}
