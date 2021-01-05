//
//  Submodule.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2020/3/7.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import git2

public class Submodule {
    private var git_submodule: OpaquePointer
    private var autorelease: Bool

    deinit {
        if self.autorelease {
            git_submodule_free(git_submodule)
        }
    }

    init(pointer: OpaquePointer, autorelease: Bool = true) {
        self.git_submodule = pointer
        self.autorelease = autorelease
    }

    public var repository: Repository? {
        var repo: OpaquePointer?
        if git_submodule_open(&repo, git_submodule) != 0 {
            return nil
        }
        return Repository(repo!, submodule: self)
    }

    public lazy var owner: Repository = {
        let r = git_submodule_owner(git_submodule)
        return Repository(r!)
    }()

    public var name: String {
        return String(cString: git_submodule_name(git_submodule))
    }

    public var path: String {
        return String(cString: git_submodule_path(git_submodule))
    }

    public var url: String {
        return String(cString: git_submodule_url(git_submodule))
    }

    public var branch: String {
        return String(cString: git_submodule_branch(git_submodule))
    }

    public var headOID: OID? {
        guard let oid = git_submodule_head_id(git_submodule)?.pointee else {
            return nil
        }
        return OID(oid)
    }

    public var indexOID: OID? {
        guard let oid = git_submodule_index_id(git_submodule)?.pointee else {
            return nil
        }
        return OID(oid)
    }

    public var workingDirectoryOID: OID? {
        guard let oid = git_submodule_wd_id(git_submodule)?.pointee else {
            return nil
        }
        return OID(oid)
    }

    @discardableResult
    public func update(options: UpdateOptions, init: Bool = true, rescurse: Bool? = nil) -> Result<(), NSError> {
        let msgBlock = options.fetchOptions.remoteCallback.messageBlock
        msgBlock?("\nClone submodule `\(self.name)`:\n")
        var gitOptions = options.toGitOptions()
        let result = git_submodule_update(git_submodule, `init` ? 1 : 0, &gitOptions)
        guard result == GIT_OK.rawValue else {
            let error = NSError(gitError: result, pointOfFailure: "git_submodule_update")
            msgBlock?(error.localizedDescription)
            return .failure(error)
        }
        if rescurse != false || self.recurseFetch != .no {
            self.repository?.eachSubmodule {
                $0.update(options: options, init: `init`, rescurse: rescurse)
                return GIT_OK.rawValue
            }
        }
        return .success(())
    }

    public func sync() -> Bool {
        return git_submodule_sync(git_submodule) == 0
    }

    public func reload(force: Bool = false) -> Bool {
        return git_submodule_reload(git_submodule, force ? 1 : 0) == 0
    }

    @discardableResult
    public func clone(options: UpdateOptions) -> Result<Repository, NSError> {
        var repo: OpaquePointer?
        var options = options.toGitOptions()
        let result = git_submodule_clone(&repo, git_submodule, &options)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_submodule_clone"))
        }
        return .success(Repository(repo!))
    }

    public var recurseFetch: Recurse {
        set {
            git_submodule_set_fetch_recurse_submodules(self.owner.pointer, self.name, newValue.toGit())
        }
        get {
            let r = git_submodule_fetch_recurse_submodules(git_submodule)
            return Recurse(git: r)
        }
    }
}
