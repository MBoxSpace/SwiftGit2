//
//  Repository+Tag.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import libgit2

public extension Repository {
    /// Load and return a list of all the `TagReference`s.
    func allTags() -> Result<[TagReference], NSError> {
        return references(withPrefix: "refs/tags/").map { (refs: [ReferenceType]) in
            return refs.map { $0 as! TagReference }
        }
    }

    /// Load the tag with the given OID.
    ///
    /// oid - The OID of the tag to look up.
    ///
    /// Returns the tag if it exists, or an error.
    func tag(_ oid: OID) -> Result<Tag, NSError> {
        return withGitObject(oid, type: GIT_OBJECT_TAG) { Tag($0) }
    }

    /// Load the tag with the given name (e.g., "tag-2").
    func tag(named name: String) -> Result<TagReference, NSError> {
        return reference(named: "refs/tags/" + name).map { $0 as! TagReference }
    }
}
