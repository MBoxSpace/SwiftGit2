//
//  Repository+Submodule.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2020/3/8.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public typealias SubmoduleEachBlock = (Submodule) -> Int32

private func gitSubmoduleCallback(submodule: OpaquePointer?, name: UnsafePointer<Int8>?, payload: UnsafeMutableRawPointer?) -> Int32 {
    guard let submodule = submodule, let payload = payload else {
        return GIT_ERROR.rawValue
    }
    let obj = Submodule(pointer: submodule, autorelease: false)

    let buffer = payload.assumingMemoryBound(to: SubmoduleEachBlock.self)
    let block = buffer.pointee
    return block(obj)
}

extension Repository {
    @discardableResult
    func eachSubmodule(_ block: @escaping SubmoduleEachBlock) -> NSError? {
        let blockPointer = UnsafeMutablePointer<SubmoduleEachBlock>.allocate(capacity: 1)
        blockPointer.initialize(repeating: block, count: 1)
        defer { blockPointer.deallocate() }
        let result = git_submodule_foreach(self.pointer, gitSubmoduleCallback, UnsafeMutableRawPointer(blockPointer))
        if result == GIT_OK.rawValue {
            return nil
        }
        return NSError(gitError: result, pointOfFailure: "git_submodule_foreach")
    }

    private func eachRepository(name: String, block: @escaping (String, Repository) -> Bool) -> Bool {
        if !block(name, self) { return false }
        let name = name.isEmpty ? name : name + "/"
        eachSubmodule { (submodule) -> Int32 in
            if let repo = submodule.repository {
                if !repo.eachRepository(name: "\(name)\(submodule.name)", block: block) { return GIT_ERROR.rawValue }
            }
            return GIT_OK.rawValue
        }
        return true
    }

    @discardableResult
    public func eachRepository(_ block: @escaping (String, Repository) -> Bool) -> Bool {
        return eachRepository(name: "", block: block)
    }

    func submodules() -> [Submodule] {
        var names = [String]()
        self.eachSubmodule {
            names.append($0.name)
            return GIT_OK.rawValue
        }
        return names.map { try! self.submodule(for: $0).get() }
    }

    func submodule(for name: String) -> Result<Submodule, NSError> {
        var module: OpaquePointer?
        let result = name.withCString {
            git_submodule_lookup(&module, self.pointer, $0)
        }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_submodule_lookup"))
        }
        return .success(Submodule(pointer: module!))
    }
}
