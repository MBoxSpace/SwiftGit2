//
//  Repository+RemoteSpec.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/6/25.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation
import SwiftGit2
import Nimble
import Quick

// swiftlint:disable cyclomatic_complexity

class RepositoryRemoteSpec: FixturesSpec {
    override func spec() {
        describe("Repository.Type.isValid(url:)") {
            it("should return true if the repo exists") {
                guard let repositoryURL = Fixtures.simpleRepository.directoryURL else {
                    fail("Fixture setup broken: Repository does not exist"); return
                }

                let result = Repository.isValid(url: repositoryURL)

                expect(result.error).to(beNil())

                if case .success(let isValid) = result {
                    expect(isValid).to(beTruthy())
                }
            }

            it("should return false if the directory does not contain a repo") {
                let tmpURL = URL(fileURLWithPath: "/dev/null")
                let result = Repository.isValid(url: tmpURL)

                expect(result.error).to(beNil())

                if case .success(let isValid) = result {
                    expect(isValid).to(beFalsy())
                }
            }

            it("should return error if .git is not readable") {
                let localURL = self.temporaryURL(forPurpose: "git-isValid-unreadable").appendingPathComponent(".git")
                let nonReadablePermissions: [FileAttributeKey: Any] = [.posixPermissions: 0o077]
                try! FileManager.default.createDirectory(
                    at: localURL,
                    withIntermediateDirectories: true,
                    attributes: nonReadablePermissions)
                let result = Repository.isValid(url: localURL)

                expect(result.value).to(beNil())
                expect(result.error).notTo(beNil())
            }
        }

        describe("Repository.Type.create(at:)") {
            it("should create a new repo at the specified location") {
                let localURL = self.temporaryURL(forPurpose: "local-create")
                let result = Repository.create(at: localURL)

                expect(result.error).to(beNil())

                if case .success(let clonedRepo) = result {
                    expect(clonedRepo.directoryURL).notTo(beNil())
                }
            }
        }

        describe("Repository.Type.lsRemote(at:)") {
            it("should list all reference from remote repo") {
                let result = Repository.lsRemote(at: URL(string: "git@github.com:CocoaPods/Xcodeproj.git")!)
                expect(result.error).to(beNil())

                if case .success(let names) = result {
                    expect(names.contains("refs/heads/1-0-stable")).to(beTrue())
                    expect(names.contains("refs/tags/1.0.0")).to(beTrue())
                }
            }
            it("should list all branches from remote repo") {
                let result = Repository.remoteBranches(at: URL(string: "git@github.com:CocoaPods/Xcodeproj.git")!)
                expect(result.error).to(beNil())

                if case .success(let names) = result {
                    expect(names.contains("1-0-stable")).to(beTrue())
                    expect(names.contains("1.0.0")).to(beFalse())
                }
            }
            it("should list all tags from remote repo") {
                let result = Repository.remoteTags(at: URL(string: "git@github.com:CocoaPods/Xcodeproj.git")!)
                expect(result.error).to(beNil())

                if case .success(let names) = result {
                    expect(names.contains("1-0-stable")).to(beFalse())
                    expect(names.contains("1.0.0")).to(beTrue())
                }
            }
        }

        describe("Repository.pull(remote:options:)") {
            beforeEach {
                Fixtures.sharedInstance.tearDown()
                Fixtures.sharedInstance.setUp()
            }
            afterEach {
                Fixtures.sharedInstance.tearDown()
                Fixtures.sharedInstance.setUp()
            }
            it("should pull from default remote") {
                let repo = Fixtures.mantleRepository
                let pullResult = repo.pull()
                expect(pullResult.error).to(beNil())

                let currentHEAD = repo.HEAD()
                let remoteHEAD = repo.remoteBranch(named: "origin/master")
                expect(currentHEAD.value?.oid).to(equal(remoteHEAD.value?.oid))
            }

            it("should pull from custom remote") {
                let repo = Fixtures.mantleRepository
                let pullResult = repo.pull(remote: "upstream")
                expect(pullResult.error).to(beNil())

                let currentHEAD = repo.HEAD()
                let remoteHEAD = repo.remoteBranch(named: "upstream/master")
                expect(currentHEAD.value?.oid).to(equal(remoteHEAD.value?.oid))
            }

            it("should pull from custom remote and custom branch") {
                let repo = Fixtures.mantleRepository
                let pullResult = repo.pull(remote: "upstream", branch: "master")
                expect(pullResult.error).to(beNil())

                let currentHEAD = repo.HEAD()
                let remoteHEAD = repo.remoteBranch(named: "upstream/master")
                expect(currentHEAD.value?.oid).to(equal(remoteHEAD.value?.oid))
            }
        }

        describe("Repository.Type.clone(from:to:)") {
            it("should handle local clones") {
                let remoteRepo = Fixtures.simpleRepository
                let localURL = self.temporaryURL(forPurpose: "local-clone")
                let result = Repository.clone(from: remoteRepo.directoryURL!,
                                              to: localURL,
                                              options: CloneOptions(localClone: true))

                expect(result.error).to(beNil())

                if case .success(let clonedRepo) = result {
                    expect(clonedRepo.directoryURL).notTo(beNil())
                }
            }

            it("should handle bare clones") {
                let remoteRepo = Fixtures.simpleRepository
                let localURL = self.temporaryURL(forPurpose: "bare-clone")
                let result = Repository.clone(from: remoteRepo.directoryURL!,
                                              to: localURL,
                                              options: CloneOptions(bare: true, localClone: true))

                expect(result.error).to(beNil())

                if case .success(let clonedRepo) = result {
                    expect(clonedRepo.directoryURL).to(beNil())
                }
            }

            it("should have set a valid remote url") {
                let remoteRepo = Fixtures.simpleRepository
                let localURL = self.temporaryURL(forPurpose: "valid-remote-clone")
                let cloneResult = Repository.clone(from: remoteRepo.directoryURL!,
                                                   to: localURL,
                                                   options: CloneOptions(localClone: true))

                expect(cloneResult.error).to(beNil())

                if case .success(let clonedRepo) = cloneResult {
                    let remoteResult = clonedRepo.remote(named: "origin")
                    expect(remoteResult.error).to(beNil())

                    if case .success(let remote) = remoteResult {
                        expect(remote.URL).to(equal(remoteRepo.directoryURL?.absoluteString))
                    }
                }
            }

            it("should be able to clone a remote HTTPS repository") {
                let remoteRepoURL = URL(string: "https://github.com/libgit2/libgit2.github.com.git")
                let localURL = self.temporaryURL(forPurpose: "public-remote-https-clone")
                let cloneResult = Repository.clone(from: remoteRepoURL!, to: localURL)

                expect(cloneResult.error).to(beNil())

                if case .success(let clonedRepo) = cloneResult {
                    let remoteResult = clonedRepo.remote(named: "origin")
                    expect(remoteResult.error).to(beNil())

                    if case .success(let remote) = remoteResult {
                        expect(remote.URL).to(equal(remoteRepoURL?.absoluteString))
                    }
                }
            }

            it("should be able to clone a remote SSH repository") {
                let remoteRepoURL = URL(string: "git@github.com:CocoaPods/Xcodeproj.git")
                let localURL = self.temporaryURL(forPurpose: "public-remote-ssh-clone")
                let cloneResult = Repository.clone(from: remoteRepoURL!,
                                                   to: localURL,
                                                   options: CloneOptions(checkoutBranch: "1-0-stable"))

                expect(cloneResult.error).to(beNil())

                if case .success(let clonedRepo) = cloneResult {
                    let remoteResult = clonedRepo.remote(named: "origin")
                    expect(remoteResult.error).to(beNil())

                    if case .success(let remote) = remoteResult {
                        expect(remote.URL).to(equal(remoteRepoURL?.absoluteString))
                    }

                    let head = clonedRepo.HEAD()
                    expect(head.error).to(beNil())
                    if case .success(let ref) = head {
                        if let ref = ref as? Branch {
                            expect(ref.name).to(equal("1-0-stable"))
                        } else {
                            fail("HEAD should is a branch! Now it is \(ref)")
                        }
                    }
                }

            }

            let env = ProcessInfo.processInfo.environment

            if let privateRepo = env["SG2TestPrivateRepo"],
                let gitUsername = env["SG2TestUsername"],
                let publicKey = env["SG2TestPublicKey"],
                let privateKey = env["SG2TestPrivateKey"],
                let passphrase = env["SG2TestPassphrase"] {

                it("should be able to clone a remote repository requiring credentials") {
                    let remoteRepoURL = URL(string: privateRepo)
                    let localURL = self.temporaryURL(forPurpose: "private-remote-clone")
                    let credentials = Credentials.sshMemory(username: gitUsername,
                                                            publicKey: publicKey,
                                                            privateKey: privateKey,
                                                            passphrase: passphrase)
                    let fetchOptions = FetchOptions(credentials: credentials)
                    let cloneResult = Repository.clone(from: remoteRepoURL!,
                                                       to: localURL,
                                                       options: CloneOptions(fetchOptions: fetchOptions))

                    expect(cloneResult.error).to(beNil())

                    if case .success(let clonedRepo) = cloneResult {
                        let remoteResult = clonedRepo.remote(named: "origin")
                        expect(remoteResult.error).to(beNil())

                        if case .success(let remote) = remoteResult {
                            expect(remote.URL).to(equal(remoteRepoURL?.absoluteString))
                        }
                    }
                }
            }
        }
    }
}
