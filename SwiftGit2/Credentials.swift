//
//  Credentials.swift
//  SwiftGit2
//
//  Created by Tom Booth on 29/02/2016.
//  Copyright © 2016 GitHub, Inc. All rights reserved.
//

import git2

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

    /// see `git_credential_t`
    internal var type: git_credential_t {
        switch self {
        case .default:
            return GIT_CREDENTIAL_DEFAULT
        case .username:
            return GIT_CREDENTIAL_USERNAME
        case .plaintext:
            return GIT_CREDENTIAL_USERPASS_PLAINTEXT
        case .sshAgent:
            return git_credential_t(rawValue: GIT_CREDENTIAL_SSH_MEMORY.rawValue + GIT_CREDENTIAL_SSH_KEY.rawValue)
        case .sshFile:
            return GIT_CREDENTIAL_SSH_KEY
        case .sshMemory:
            return GIT_CREDENTIAL_SSH_MEMORY
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
    cred: UnsafeMutablePointer<OpaquePointer?>?,
    url: UnsafePointer<CChar>?,
    username: UnsafePointer<CChar>?,
    allowTypes: UInt32,
    payload: UnsafeMutableRawPointer? ) -> Int32 {

    let result: Int32

    // Find username_from_url
    let name = username.map(String.init(cString:))

    let remoteCallback = RemoteCallback.fromPointer(payload!)
    if remoteCallback.avaliableCredentials.isEmpty {
        return -1
    }

    var credentials: Credentials?
    while !remoteCallback.avaliableCredentials.isEmpty {
        let cred = remoteCallback.avaliableCredentials.removeFirst()
        if cred.allowed(by: allowTypes) {
            credentials = cred
            break
        }
    }

    if credentials == nil { return -1 }

    switch credentials! {
    case .default:
        result = git_credential_default_new(cred)
    case .username(let username):
        result = git_credential_username_new(cred, username)
    case .plaintext(let username, let password):
        result = git_credential_userpass_plaintext_new(cred, username, password)
    case .sshAgent:
        result = git_credential_ssh_key_from_agent(cred, name!)
    case .sshFile(let username, let publicKeyPath, let privateKeyPath, _):
        result = git_credential_ssh_key_new(cred, username, publicKeyPath, privateKeyPath, "")
    case .sshMemory(let username, let publicKey, let privateKey, let passphrase):
        result = git_credential_ssh_key_memory_new(cred, username, publicKey, privateKey, passphrase)
    }

    return (result != GIT_OK.rawValue) ? -1 : 0
}
