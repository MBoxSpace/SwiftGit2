//
//  Repository+Remote.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/17.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

private func transportMessageCallback(str: UnsafePointer<CChar>?, len: Int32, payload: UnsafeMutableRawPointer?) -> Int32 {
    if let info = str.map(String.init(cString:)) {
        print(info)
    }
    return 1
}

private func transferProgressCallback(stats: UnsafePointer<git_transfer_progress>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    return 0
}

/**
 * If cert verification fails, this will be called to let the
 * user make the final decision of whether to allow the
 * connection to proceed. Returns 1 to allow the connection, 0
 * to disallow it or a negative value to indicate an error.
 */
private func transportCertificateCheckCallback(cert: UnsafeMutablePointer<git_cert>?, valid: Int32, host: UnsafePointer<CChar>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    let hostname = host.map(String.init(cString:))!
    print("host: \(hostname)")
    let gitCert = cert.flatMap({ $0.pointee })!
    if gitCert.cert_type == GIT_CERT_HOSTKEY_LIBSSH2 {
        let hostCert = unsafeBitCast(cert, to: UnsafeMutablePointer<git_cert_hostkey>.self).pointee
        if hostCert.type.rawValue & GIT_CERT_SSH_MD5.rawValue > 0 {
            var hash = hostCert.hash_sha1

            let c_str = withUnsafeBytes(of: &hash) { ptr -> UnsafePointer<UInt8> in
                let c_str = ptr.bindMemory(to: UInt8.self)
                let limit_c_str = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 16)
                c_str.copyBytes(to: limit_c_str)
                return UnsafeBufferPointer(limit_c_str).baseAddress!
            }
            print("md5: \(String(cString: c_str))")
        }
        if hostCert.type.rawValue & GIT_CERT_SSH_SHA1.rawValue > 0 {
            let hash = hostCert.hash_sha1
            let sha1 = withUnsafeBytes(of: hash) { $0.baseAddress!.assumingMemoryBound(to: CChar.self) }

            print("sha1: \(String(cString: sha1))")
        }
    }
    let a = Credentials.fromPointer(payload!)
    print(a)
    return 0
}

private func fetchOptions(credentials: Credentials,
                          tags: Bool = false,
                          prune: Bool = false) -> git_fetch_options {
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

    options.callbacks.credentials = credentialsCallback
    options.callbacks.certificate_check = transportCertificateCheckCallback
    options.callbacks.sideband_progress = transportMessageCallback
    options.callbacks.transfer_progress = transferProgressCallback
    options.callbacks.payload = credentials.toPointer()

    return options
}

//internal func credentialsCallback(
//    cred: UnsafeMutablePointer<UnsafeMutablePointer<git_cred>?>?,
//    url: UnsafePointer<CChar>?,
//    username: UnsafePointer<CChar>?,
//    _: UInt32,
//    payload: UnsafeMutableRawPointer? ) -> Int32 {
//}
private func cloneOptions(bare: Bool = false,
                          localClone: Bool = false,
                          fetchOptions: git_fetch_options? = nil,
                          checkoutBranch: String? = nil,
                          checkoutOptions: git_checkout_options? = nil) -> git_clone_options {
    let pointer = UnsafeMutablePointer<git_clone_options>.allocate(capacity: 1)
    git_clone_init_options(pointer, UInt32(GIT_CLONE_OPTIONS_VERSION))

    var options = pointer.move()

    pointer.deallocate()

    options.bare = bare ? 1 : 0

    if localClone {
        options.local = GIT_CLONE_NO_LOCAL
    }

    if let branch = checkoutBranch {
        branch.withCString { options.checkout_branch = $0 }
    }

    if let checkoutOptions = checkoutOptions {
        options.checkout_opts = checkoutOptions
    }

    if let fetchOptions = fetchOptions {
        options.fetch_opts = fetchOptions
    }

    return options
}

extension Repository {
    // MARK: - Remote Lookups

    /// Loads all the remotes in the repository.
    ///
    /// Returns an array of remotes, or an error.
    public func allRemotes() -> Result<[Remote], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        let result = git_remote_list(pointer, self.pointer)

        guard result == GIT_OK.rawValue else {
            pointer.deallocate()
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_remote_list"))
        }

        let strarray = pointer.pointee
        let remotes: [Result<Remote, NSError>] = strarray.map {
            return self.remote(named: $0)
        }
        git_strarray_free(pointer)
        pointer.deallocate()

        return remotes.aggregateResult()
    }

    private func remoteLookup<A>(named name: String, _ callback: (Result<OpaquePointer, NSError>) -> A) -> A {
        var pointer: OpaquePointer? = nil
        defer { git_remote_free(pointer) }

        let result = git_remote_lookup(&pointer, self.pointer, name)

        guard result == GIT_OK.rawValue else {
            return callback(.failure(NSError(gitError: result, pointOfFailure: "git_remote_lookup")))
        }

        return callback(.success(pointer!))
    }

    /// Load a remote from the repository.
    ///
    /// name - The name of the remote.
    ///
    /// Returns the remote if it exists, or an error.
    public func remote(named name: String) -> Result<Remote, NSError> {
        return remoteLookup(named: name) { $0.map(Remote.init) }
    }

    /// Download new data and update tips
    ///
    /// remote          - The name of the remote repository, default to the upstream name (maybe is not the `origin`)
    /// credentials     - Credentials to be used when connecting to the remote.
    /// tags            - Download all tags.
    /// prune           - Prune nonexist remote branch.
    ///
    /// Returns a `Result` with void or an error.
    public func fetch(_ remote: String? = nil,
                      credentials: Credentials = .default,
                      tags: Bool = false,
                      prune: Bool = false)
        -> Result<(), NSError> {
        let remoteName = remote ?? (try? self.trackBranch().get().remoteName) ?? "origin"
        return remoteLookup(named: remoteName) { remote in
            remote.flatMap { pointer in
                var opts = fetchOptions(credentials: credentials, tags: tags, prune: prune)
                let result = git_remote_fetch(pointer, nil, &opts, nil)
                guard result == GIT_OK.rawValue else {
                    let err = NSError(gitError: result, pointOfFailure: "git_remote_fetch")
                    return .failure(err)
                }
                return .success(())
            }
        }
    }

    /// Clone the repository from a given URL.
    ///
    /// remoteURL        - The URL of the remote repository
    /// localURL         - The URL to clone the remote repository into
    /// localClone       - Will not bypass the git-aware transport, even if remote is local.
    /// bare             - Clone remote as a bare repository.
    /// credentials      - Credentials to be used when connecting to the remote.
    /// checkoutStrategy - The checkout strategy to use, if being checked out.
    /// checkoutProgress - A block that's called with the progress of the checkout.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public class func clone(from remoteURL: URL,
                            to localURL: URL,
                            localClone: Bool = false,
                            bare: Bool = false,
                            credentials: Credentials = .default,
                            checkoutBranch: String? = nil,
                            checkoutStrategy: CheckoutStrategy = .Safe,
                            checkoutProgress: CheckoutProgressBlock? = nil) -> Result<Repository, NSError> {
        var options = cloneOptions(
            bare: bare,
            localClone: localClone,
            fetchOptions: fetchOptions(credentials: credentials),
            checkoutBranch: checkoutBranch,
            checkoutOptions: checkoutOptions(strategy: checkoutStrategy, progress: checkoutProgress))

        var pointer: OpaquePointer? = nil
        let remoteURLString = (remoteURL as NSURL).isFileReferenceURL() ? remoteURL.path : remoteURL.absoluteString
        let result = localURL.withUnsafeFileSystemRepresentation { localPath in
            git_clone(&pointer, remoteURLString, localPath, &options)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_clone"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }
}
