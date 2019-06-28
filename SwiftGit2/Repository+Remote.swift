//
//  Repository+Remote.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/17.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

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
    /// remote      - The name of the remote repository.
    ///               default to the upstream name (maybe is not the `origin`)
    /// options     - The options will be used.
    ///
    /// Returns a `Result` with void or an error.
    public func fetch(_ remote: String? = nil,
                      options: FetchOptions? = nil)
        -> Result<(), NSError> {
        let remoteName = remote ?? (try? self.trackBranch().get().remoteName) ?? "origin"
        return remoteLookup(named: remoteName) { remote in
            remote.flatMap { pointer in
                var opts = (options ?? FetchOptions()).toGit()
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
    /// remoteURL   - The URL of the remote repository
    /// localURL    - The URL to clone the remote repository into
    /// options     - The options will be used
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public class func clone(from remoteURL: URL,
                            to localURL: URL,
                            options: CloneOptions? = nil) -> Result<Repository, NSError> {
        var opt = (options ?? CloneOptions()).toGitOptions()

        var pointer: OpaquePointer? = nil
        let remoteURLString = (remoteURL as NSURL).isFileReferenceURL() ? remoteURL.path : remoteURL.absoluteString
        let result = localURL.withUnsafeFileSystemRepresentation { localPath in
            git_clone(&pointer, remoteURLString, localPath, &opt)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_clone"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    public class func lsRemote(at url: URL, credentials: Credentials = .default) -> Result<[String], NSError> {
        var remote: OpaquePointer? = nil

        var result = git_remote_create_detached(&remote, url.path)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_create_detached"))
        }
        var callback = RemoteCallback().toGit()

        result = git_remote_connect(remote, GIT_DIRECTION_FETCH, &callback, nil, nil)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_connect"))
        }

        var count: Int = 0
        var headsPointer: UnsafeMutablePointer<UnsafePointer<git_remote_head>?>? = nil
        result = git_remote_ls(&headsPointer, &count, remote)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_ls"))
        }
        var names = [String]()
        for i in 0..<count {
            let head = (headsPointer! + i).pointee!.pointee
            names.append(String(cString: head.name))
        }
        return .success(names)
    }

    public class func remoteBranches(at url: URL, credentials: Credentials = .default) -> Result<[String], NSError> {
        let prefix = "refs/heads/"
        return lsRemote(at: url).flatMap {
            .success($0.compactMap {
                $0.starts(with: prefix) ? String($0.dropFirst(prefix.count)) : nil
            })
        }
    }

    public class func remoteTags(at url: URL, credentials: Credentials = .default) -> Result<[String], NSError> {
        let prefix = "refs/tags/"
        let subffix = "^{}"
        return lsRemote(at: url).flatMap {
            .success($0.compactMap {
                if $0.hasPrefix(prefix) && !$0.hasSuffix(subffix) {
                    return String($0.dropFirst(prefix.count))
                } else {
                    return nil
                }
            })
        }
    }
}
