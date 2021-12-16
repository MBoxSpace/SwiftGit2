//
//  Strategy.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 4/1/15.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

@_implementationOnly import git2

public extension CheckoutOptions.Strategy {

    // MARK: - Values

    /// Default is a dry run, no actual updates.
    static let None = CheckoutOptions.Strategy(GIT_CHECKOUT_NONE)

    /// Allow safe updates that cannot overwrite uncommitted data.
    static let Safe = CheckoutOptions.Strategy(GIT_CHECKOUT_SAFE)

    /// Allow all updates to force working directory to look like index
    static let Force = CheckoutOptions.Strategy(GIT_CHECKOUT_FORCE)

    /// Allow checkout to recreate missing files.
    static let RecreateMissing = CheckoutOptions.Strategy(GIT_CHECKOUT_RECREATE_MISSING)

    /// Allow checkout to make safe updates even if conflicts are found.
    static let AllowConflicts = CheckoutOptions.Strategy(GIT_CHECKOUT_ALLOW_CONFLICTS)

    /// Remove untracked files not in index (that are not ignored).
    static let RemoveUntracked = CheckoutOptions.Strategy(GIT_CHECKOUT_REMOVE_UNTRACKED)

    /// Remove ignored files not in index.
    static let RemoveIgnored = CheckoutOptions.Strategy(GIT_CHECKOUT_REMOVE_IGNORED)

    /// Only update existing files, don't create new ones.
    static let UpdateOnly = CheckoutOptions.Strategy(GIT_CHECKOUT_UPDATE_ONLY)

    /// Normally checkout updates index entries as it goes; this stops that.
    /// Implies `DontWriteIndex`.
    static let DontUpdateIndex = CheckoutOptions.Strategy(GIT_CHECKOUT_DONT_UPDATE_INDEX)

    /// Don't refresh index/config/etc before doing checkout
    static let NoRefresh = CheckoutOptions.Strategy(GIT_CHECKOUT_NO_REFRESH)

    /// Allow checkout to skip unmerged files
    static let SkipUnmerged = CheckoutOptions.Strategy(GIT_CHECKOUT_SKIP_UNMERGED)

    /// For unmerged files, checkout stage 2 from index
    static let UseOurs = CheckoutOptions.Strategy(GIT_CHECKOUT_USE_OURS)

    /// For unmerged files, checkout stage 3 from index
    static let UseTheirs = CheckoutOptions.Strategy(GIT_CHECKOUT_USE_THEIRS)

    /// Treat pathspec as simple list of exact match file paths
    static let DisablePathspecMatch = CheckoutOptions.Strategy(GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH)

    /// Ignore directories in use, they will be left empty
    static let SkipLockedDirectories = CheckoutOptions.Strategy(GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES)

    /// Don't overwrite ignored files that exist in the checkout target
    static let DontOverwriteIgnored = CheckoutOptions.Strategy(GIT_CHECKOUT_DONT_OVERWRITE_IGNORED)

    /// Write normal merge files for conflicts
    static let ConflictStyleMerge = CheckoutOptions.Strategy(GIT_CHECKOUT_CONFLICT_STYLE_MERGE)

    /// Include common ancestor data in diff3 format files for conflicts
    static let ConflictStyleDiff3 = CheckoutOptions.Strategy(GIT_CHECKOUT_CONFLICT_STYLE_DIFF3)

    /// Don't overwrite existing files or folders
    static let DontRemoveExisting = CheckoutOptions.Strategy(GIT_CHECKOUT_DONT_REMOVE_EXISTING)

    /// Normally checkout writes the index upon completion; this prevents that.
    static let DontWriteIndex = CheckoutOptions.Strategy(GIT_CHECKOUT_DONT_WRITE_INDEX)
}
