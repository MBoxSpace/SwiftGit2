//
//  Repository+StashSpec.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/7/5.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import SwiftGit2
import Nimble
import Quick

class RepositoryStashSpec: FixturesSpec {
    override func spec() {
        beforeEach {
            let repo = Fixtures.simpleRepository
            try? FileManager.default.removeItem(at: repo.directoryURL!.appendingPathComponent("untrack.txt"))
            _ = repo.reset(type: .hard)
        }
        describe("Repository.save(stash:keepIndex:includeUntrack:includeIgnored:)") {

            it("should save stash 'stash1' without untracked files") {
                let repo = Fixtures.simpleRepository

                try? "test".write(to: repo.directoryURL!.appendingPathComponent("untrack.txt"),
                                  atomically: true,
                                  encoding: .utf8)

                try? "test".write(to: repo.directoryURL!.appendingPathComponent("added.txt"),
                                  atomically: true,
                                  encoding: .utf8)
                let addResult = repo.add(path: "added.txt")
                expect(addResult.error).to(beNil())

                let stashResult = repo.save(stash: "stash1")
                expect(stashResult.error).to(beNil())

                let statusResult = repo.status()
                expect(statusResult.error).to(beNil())
                expect(statusResult.value?.count).to(equal(1))
            }
            it("should save stash 'stash2' with untracked files") {
                let repo = Fixtures.simpleRepository

                try? "test".write(to: repo.directoryURL!.appendingPathComponent("untrack.txt"),
                                  atomically: true,
                                  encoding: .utf8)

                try? "test".write(to: repo.directoryURL!.appendingPathComponent("added.txt"),
                                  atomically: true,
                                  encoding: .utf8)
                let addResult = repo.add(path: "added.txt")
                expect(addResult.error).to(beNil())

                let stashResult = repo.save(stash: "stash2", includeUntracked: true)
                expect(stashResult.error).to(beNil())

                let statusResult = repo.status()
                expect(statusResult.error).to(beNil())
                expect(statusResult.value?.count).to(equal(0))
            }
        }
        describe("Repository.stashes()") {
            it("Should list all stashes") {
                let repo = Fixtures.simpleRepository
                let stashes = repo.stashes()
                expect(stashes.error).to(beNil())
                expect(stashes.value?.count).to(equal(2))
            }
        }

        describe("Repository.apply(stash:index:)") {
            it("Should apply a stash without index") {
                let repo = Fixtures.simpleRepository
                let result = repo.apply(stash: 0)
                expect(result.error).to(beNil())
            }
            it("Should apply a stash with index") {
                let repo = Fixtures.simpleRepository
                let result = repo.apply(stash: 0, index: true)
                expect(result.error).to(beNil())
            }
        }

        describe("Repository.pop(stash:index:)") {
            it("Should pop a stash") {
                let repo = Fixtures.simpleRepository
                let result = repo.pop(stash: 0)
                expect(result.error).to(beNil())
            }
        }

        describe("Repository.drop(stash:)") {
            it("Should pop a stash") {
                let repo = Fixtures.simpleRepository
                let result = repo.drop(stash: 0)
                expect(result.error).to(beNil())
            }
        }
    }
}
