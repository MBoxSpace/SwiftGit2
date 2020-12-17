//
//  CheckoutOptions.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/28.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

/// Helper function used as the libgit2 progress callback in git_checkout_options.
/// This is a function with a type signature of git_checkout_progress_cb.
private func checkoutProgressCallback(path: UnsafePointer<Int8>?,
                                      completedSteps: Int,
                                      totalSteps: Int,
                                      payload: UnsafeMutableRawPointer?) {
    guard let payload = payload else {
        return
    }
    let buffer = payload.assumingMemoryBound(to: CheckoutOptions.ProgressBlock.self)
    let block: CheckoutOptions.ProgressBlock
    if completedSteps < totalSteps {
        block = buffer.pointee
    } else {
        block = buffer.move()
        buffer.deallocate()
    }
    block(path.flatMap(String.init(validatingUTF8:)), completedSteps, totalSteps)
}

public class CheckoutOptions {
    /// The flags defining how a checkout should be performed.
    /// More detail is available in the libgit2 documentation for `git_checkout_strategy_t`.
    public struct Strategy: OptionSet {
        private let value: UInt

        // MARK: - Initialization

        /// Create an instance initialized with `nil`.
        public init(nilLiteral: ()) {
            self.value = 0
        }

        public init(rawValue value: UInt) {
            self.value = value
        }

        public init(_ strategy: git_checkout_strategy_t) {
            self.value = UInt(strategy.rawValue)
        }

        public static var allZeros: Strategy {
            return self.init(rawValue: 0)
        }

        // MARK: - Properties

        public var rawValue: UInt {
            return value
        }

        public var gitCheckoutStrategy: git_checkout_strategy_t {
            return git_checkout_strategy_t(UInt32(self.value))
        }
    }

    public typealias ProgressBlock = (String?, Int, Int) -> Void

    public var strategy: Strategy
    public var progress: ProgressBlock?

    public init(strategy: Strategy = .Safe,
                progress: ProgressBlock? = nil) {
        self.strategy = strategy
        self.progress = progress
    }

    internal func toGit() -> git_checkout_options {
        // Do this because GIT_CHECKOUT_OPTIONS_INIT is unavailable in swift
        let pointer = UnsafeMutablePointer<git_checkout_options>.allocate(capacity: 1)
        git_checkout_options_init(pointer, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        var options = pointer.move()
        pointer.deallocate()

        options.checkout_strategy = strategy.gitCheckoutStrategy.rawValue

        if progress != nil {
            options.progress_cb = checkoutProgressCallback
            let blockPointer = UnsafeMutablePointer<ProgressBlock>.allocate(capacity: 1)
            blockPointer.initialize(to: progress!)
            options.progress_payload = UnsafeMutableRawPointer(blockPointer)
        }

        return options
    }
}
