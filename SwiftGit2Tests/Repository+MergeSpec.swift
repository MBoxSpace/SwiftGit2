//
//  Repository+MergeSpec.swift
//  SwiftGit2
//
//  Created by Whirlwind on 2019/6/30.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import SwiftGit2
import Nimble
import Quick

class RepositoryMergeSpec: FixturesSpec {
    lazy var repo = Fixtures.detachedHeadRepository
    lazy var branch = try! self.repo.localBranch(named: "another-branch").get()
    override func spec() {
        beforeSuite {
            self.repo.createBranch("forwadBranch")
            _ = self.repo.checkout(OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!)
            try! "test".write(to: self.repo.directoryURL!.appendingPathComponent("touch-new-file"),
                              atomically: true,
                              encoding: .utf8)
            _ = self.repo.add(path: "touch-new-file")
            _ = self.repo.commit(message: "touch-new-file")
            _ = self.repo.createBranch("touch-new-file")
        }
        describe("Repository.mergeAnalyze(sourceBranch:targetBranch:)") {
            it("should analyze status 'upToDate'") {
                let sourceBranch = try! self.repo.localBranch(named: "yet-another-branch").get()
                let result = self.repo.mergeAnalyze(sourceOID: sourceBranch.oid,
                                                    targetBranch: self.branch)
                expect(result.error).to(beNil())
                expect(result.value!).to(equal(GitMergeAnalysisStatus.upToDate))
            }
            it("should analyze status 'upToDate' for merge old commit") {
                let sourceOID = OID(string: "dc220a3f0c22920dab86d4a8d3a3cb7e69d6205a")!
                let result = self.repo.mergeAnalyze(sourceOID: sourceOID,
                                                    targetBranch: self.branch)
                expect(result.error).to(beNil())
                expect(result.value).to(equal(GitMergeAnalysisStatus.upToDate))
            }
            it("should analyze status 'fastForward'") {
                let sourceOID = OID(string: "315b3f344221db91ddc54b269f3c9af422da0f2e")!
                let result = self.repo.mergeAnalyze(sourceOID: sourceOID,
                                                    targetBranch: self.branch)
                expect(result.error).to(beNil())
                expect(result.value?.contains(.fastForward)).to(beTrue())
            }
            it("should analyze status 'normal'") {
                let sourceOID = self.repo.localBranch(named: "touch-new-file").value!.oid
                let result = self.repo.mergeAnalyze(sourceOID: sourceOID,
                                                    targetBranch: self.branch)
                expect(result.error).to(beNil())
                expect(result.value?.contains(.normal)).to(beTrue())
            }
        }
    }
}
