//
//  Repository+Remote.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/17.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
@_implementationOnly import git2

extension Repository {
    // MARK: - Remote Lookups

    /// Loads all the remotes in the repository.
    ///
    /// Returns an array of remotes, or an error.
    public func allRemotes() -> Result<[Remote], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        defer {
            pointer.deallocate()
        }
        let result = git_remote_list(pointer, self.pointer)

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_remote_list"))
        }

        let strarray = pointer.pointee
        let remotes: [Result<Remote, NSError>] = strarray.map {
            return self.remote(named: $0)
        }
        git_strarray_dispose(pointer)

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
        return remoteLookup(named: name) {
            $0.map { pointer in
                let name = String(validatingUTF8: git_remote_name(pointer))!
                let originURL = try? self.config.string(for: "remote.\(name).url").get()
                let originPushURL = try? self.config.string(for: "remote.\(name).pushurl").get()
                return Remote(pointer, originURL: originURL, originPushURL: originPushURL)
            }
        }
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
        let remoteName = remote ?? (try? self.trackBranch().get()?.remote) ?? "origin"
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
                var remoteBranch: Branch? = nil
                if let remote = remote, let branch = branch {
                    remoteBranch = try self.remoteBranch(named: "\(remote)/\(branch)").get()
                } else {
                    let trackBranch = try self.trackBranch().get()
                    if let remote = remote ?? trackBranch?.remote,
                       let branch = branch ?? trackBranch?.merge {
                        remoteBranch = try self.remoteBranch(named: "\(remote)/\(branch)").get()
                    }
                }
                guard let remoteBranch = remoteBranch else {
                    return .failure(NSError(gitError: 1, pointOfFailure: "git_config_get_string", description: "Could not find the upstream branch."))
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

    class func preProcessURL(_ url: URL) -> Result<String, NSError> {
        if (url as NSURL).isFileReferenceURL() {
            return .success(url.path)
        } else {
            return Config.default().flatMap {
                $0.insteadOf(originURL: url.absoluteString, direction: .Fetch)
            }
        }
    }
    public class func lsRemote(at url: URL, callback: RemoteCallback? = nil) -> Result<[String], NSError> {
        return preProcessURL(url).flatMap { remoteURLString in
            let opts = UnsafeMutablePointer<git_remote_create_options>.allocate(capacity: 1)
            defer { opts.deallocate() }
            var result = git_remote_create_options_init(opts, UInt32(GIT_REMOTE_CREATE_OPTIONS_VERSION))
            guard result == GIT_OK.rawValue else {
                return .failure(NSError(gitError: result, pointOfFailure: "git_remote_create_options_init"))
            }

            var remote: OpaquePointer? = nil
            result = git_remote_create_with_opts(&remote, remoteURLString, opts)
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
    }

    public class func lsRemote(at url: URL, showBranch: Bool, showTag: Bool, callback: RemoteCallback? = nil) -> Result<[String], NSError> {
        return self.lsRemote(at: url, callback: callback).flatMap {
            .success($0.compactMap {
                if showBranch && $0.starts(with: String.branchPrefix) {
                    return String($0.dropFirst(String.branchPrefix.count))
                }
                if showTag && $0.hasPrefix(String.tagPrefix) && !$0.hasSuffix("^{}") {
                    return String($0.dropFirst(String.tagPrefix.count))
                }
                return nil
            })
        }
    }
}
