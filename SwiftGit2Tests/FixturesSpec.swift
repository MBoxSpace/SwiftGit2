//
//  FixturesSpec.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/16/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Quick

class FixturesSpec: QuickSpec {

    func temporaryURL(forPurpose purpose: String) -> URL {
        let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
        let path = "\(NSTemporaryDirectory())\(globallyUniqueString)_\(purpose)"
        return URL(fileURLWithPath: path)
    }

    override func spec() {
        beforeSuite {
            Fixtures.sharedInstance.setUp()
        }

        afterSuite {
            Fixtures.sharedInstance.tearDown()
        }
    }
}
