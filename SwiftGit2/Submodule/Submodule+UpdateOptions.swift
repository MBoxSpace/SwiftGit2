//
//  Submodule+UpdateOptions.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2020/3/8.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

extension Submodule {
    public class UpdateOptions {
        public var fetchOptions: FetchOptions
        public var checkoutOptions: CheckoutOptions

        public init(fetchOptions: FetchOptions,
                    checkoutOptions: CheckoutOptions? = nil) {
            self.fetchOptions = fetchOptions
            self.checkoutOptions = checkoutOptions ?? CheckoutOptions()
        }

        func toGitOptions() -> git_submodule_update_options {
            let pointer = UnsafeMutablePointer<git_submodule_update_options>.allocate(capacity: 1)
            git_submodule_update_options_init(pointer, UInt32(GIT_SUBMODULE_UPDATE_OPTIONS_VERSION))

            var options = pointer.move()

            pointer.deallocate()

            options.checkout_opts = checkoutOptions.toGit()
            options.fetch_opts = fetchOptions.toGit()

            return options
        }
    }

}
