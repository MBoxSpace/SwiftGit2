//
//  CloneOptions.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/28.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public class CloneOptions {
    public var bare: Bool
    public var localClone: Bool
    public var fetchOptions: FetchOptions
    public var checkoutBranch: String?
    public var checkoutOptions: CheckoutOptions

    public init(fetchOptions: FetchOptions,
                bare: Bool = false,
                localClone: Bool = false,
                checkoutBranch: String? = nil,
                checkoutOptions: CheckoutOptions? = nil) {
        self.bare = bare
        self.localClone = localClone
        self.fetchOptions = fetchOptions
        self.fetchOptions.remoteCallback.mode = .Clone
        self.checkoutBranch = checkoutBranch
        self.checkoutOptions = checkoutOptions ?? CheckoutOptions()
    }

    func toGitOptions() -> git_clone_options {
        let pointer = UnsafeMutablePointer<git_clone_options>.allocate(capacity: 1)
        git_clone_init_options(pointer, UInt32(GIT_CLONE_OPTIONS_VERSION))

        var options = pointer.move()

        pointer.deallocate()

        options.bare = bare ? 1 : 0

        if localClone {
            options.local = GIT_CLONE_NO_LOCAL
        }

        if let branch = checkoutBranch {
            options.checkout_branch = branch.toUnsafePointer()
        }

        options.checkout_opts = checkoutOptions.toGit()
        options.fetch_opts = fetchOptions.toGit()

        return options
    }
}
