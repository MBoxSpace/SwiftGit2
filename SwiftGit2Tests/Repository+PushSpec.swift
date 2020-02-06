//
//  Repository+PushSpec.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2020/1/19.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Foundation
import SwiftGit2
import Nimble
import Quick

class RepositoryPushSpec: FixturesSpec {
    lazy var remoteURL = URL(string: "git@code.byted.org:mbox/SwiftGit2TestFixtures.git")!
    lazy var localURL = self.temporaryURL(forPurpose: "RemoteRepo")

    override func spec() {
        describe("Repository.Push(url:)") {
            beforeEach {
                expect { try Repository.clone(from: self.remoteURL, to: self.localURL).get() }.notTo(throwError())
            }

            afterEach {
                try? FileManager.default.removeItem(at: self.localURL)
            }

            it("should return true if the branch non-exists") {
                let repo = try! Repository.at(self.localURL).get()
                let branchName = "non-exists-branch".longBranchRef
                expect { try repo.deleteBranch(branchName, remote: "origin", force: true).get() }.notTo(throwError())
                expect { try repo.createBranch(branchName).get() }.notTo(throwError())
                expect { try repo.push("origin", sourceRef: branchName, targetRef: branchName).get() }.notTo(throwError())
            }

            it("should return true if the branch exists") {
                let repo = try! Repository.at(self.localURL).get()
                let branchName = "master".longBranchRef
                expect { try repo.push("origin", sourceRef: branchName, targetRef: branchName).get() }.notTo(throwError())
            }

            it("should return true if delete a exists branch") {
                let repo = try! Repository.at(self.localURL).get()
                let branchName = "to-delete-branch".longBranchRef
                expect { try repo.createBranch(branchName).get() }.notTo(throwError())
                expect { try repo.push("origin", sourceRef: branchName, targetRef: branchName).get() }.notTo(throwError())
                expect { try repo.deleteBranch(branchName, remote: "origin", force: true).get() }.notTo(throwError())
                _ = repo.fetch()
                expect { try repo.remoteBranches().get().map { $0.name } }.notTo(contain("to-delete-branch"))
            }
        }
    }
}
