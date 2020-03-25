//
//  Repository+Remote.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/17.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

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
                let url = String(cString: git_remote_url(pointer))
                var opts = (options ?? FetchOptions(url: url)).toGit()
                let result = git_remote_fetch(pointer, nil, &opts, nil)
                guard result == GIT_OK.rawValue else {
                    let err = NSError(gitError: result, pointOfFailure: "git_remote_fetch")
                    return .failure(err)
                }
                return .success(())
            }
        }
    }

    public func pull(remote: String? = nil,
                     branch: String? = nil,
                     options: FetchOptions? = nil) -> Result<(), NSError> {
        return self.fetch(remote, options: options).flatMap {_ in
            do {
                var remoteBranch: Branch
                if let remote = remote, let branch = branch {
                    remoteBranch = try self.remoteBranch(named: "\(remote)/\(branch)").get()
                } else {
                    remoteBranch = try self.trackBranch().get()
                    if let remote = remote {
                        remoteBranch = try self.remoteBranch(named: "\(remote)/\(remoteBranch.shortName!)").get()
                    } else if let branch = branch {
                        remoteBranch = try self.remoteBranch(named: "\(remoteBranch.remoteName!)/\(branch)").get()
                    }
                }
                return self.merge(with: remoteBranch.oid, message: "Merge \(remoteBranch)").flatMap { _ in .success(()) }
            } catch {
                return .failure(error as NSError)
            }
        }
    }

    // source and target reference must be a long name.
    // if source is empty, means delete a reference.
    public func push(_ remote: String, sourceRef: String, targetRef: String, force: Bool = false, options: PushOptions? = nil) -> Result<(), NSError> {
        var remoteServer: OpaquePointer? = nil
        var result = git_remote_lookup(&remoteServer, self.pointer, remote)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_lookup"))
        }
        let url = String(cString: git_remote_url(remoteServer))

        var opts = (options ?? PushOptions(url: url)).toGit()

        let refname = "\(force ? "+":"")\(sourceRef):\(targetRef)"
        var charName = UnsafeMutablePointer<Int8>(mutating: (refname as NSString).utf8String)
        result = withUnsafeMutablePointer(to: &charName) { pointer in
            var refs = git_strarray(strings: pointer, count: 1)
            return git_remote_push(remoteServer, &refs, &opts)
        }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_push"))
        }

        return .success(())
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
                            options: CloneOptions? = nil,
                            recurseSubmodules: Bool? = nil) -> Result<Repository, NSError> {
        let options = options ?? CloneOptions(fetchOptions: FetchOptions(url: remoteURL.absoluteString))
        var opt = options.toGitOptions()

        var pointer: OpaquePointer? = nil
        let remoteURLString = (remoteURL as NSURL).isFileReferenceURL() ? remoteURL.path : remoteURL.absoluteString
        let result = localURL.withUnsafeFileSystemRepresentation { localPath in
            git_clone(&pointer, remoteURLString, localPath, &opt)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_clone"))
        }

        let repository = Repository(pointer!)
        if recurseSubmodules != false {
            let submoduleOptions = Submodule.UpdateOptions(fetchOptions: options.fetchOptions, checkoutOptions: options.checkoutOptions)
            repository.eachSubmodule { (submodule) -> Int32 in
                if recurseSubmodules == true || submodule.recurseFetch != .no {
                    submodule.update(options: submoduleOptions, init: true, rescurse: recurseSubmodules)
                }
                return GIT_OK.rawValue
            }
        }
        return Result.success(repository)
    }

    public class func lsRemote(at url: URL, callback: RemoteCallback? = nil) -> Result<[String], NSError> {
        var remote: OpaquePointer? = nil

        let remoteURLString = (url as NSURL).isFileReferenceURL() ? url.path : url.absoluteString
        var result = git_remote_create_detached(&remote, remoteURLString)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_remote_create_detached"))
        }
        var callback = (callback ?? RemoteCallback(url: url.absoluteString)).toGit()

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

    public class func remoteBranches(at url: URL, callback: RemoteCallback? = nil) -> Result<[String], NSError> {
        let prefix = String.branchPrefix
        return lsRemote(at: url, callback: callback).flatMap {
            .success($0.compactMap {
                $0.starts(with: prefix) ? String($0.dropFirst(prefix.count)) : nil
            })
        }
    }

    public class func remoteTags(at url: URL, callback: RemoteCallback? = nil) -> Result<[String], NSError> {
        let prefix = String.tagPrefix
        let subffix = "^{}"
        return lsRemote(at: url, callback: callback).flatMap {
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
