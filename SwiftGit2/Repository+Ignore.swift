//
//  Repository+Ignore.swift
//  SwiftGit2-MBox
//
//  Created by 詹迟晶 on 2021/12/21.
//

import Foundation
@_implementationOnly import git2

public extension Repository {
    private func parse(file: String) -> [String] {
        let content = (try? String(contentsOfFile: file)) ?? ""
        return content.split(separator: "\n").compactMap { string in
            var str = string.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
            if str.hasPrefix("#") {
                return nil
            }
            if str.hasPrefix("\\#") {
                str.removeFirst()
            }
            str = str.replacingOccurrences(of: "(?<!\\\\) +$", with: "", options: .regularExpression)
            if str.isEmpty {
                return nil
            }
            return str
        }
    }

    enum IgnoreType: Comparable {
        case memory
        case trackedConfig(String)
        case untrakcedConfig
        case global
    }

    func ignoreFile(for type: IgnoreType) -> String? {
        switch type {
        case .memory:
            return nil
        case .trackedConfig(let string):
            return self.gitDir?.appendingPathComponent(string).path
        case .untrakcedConfig:
            return try? self.path(for: .info).map {
                $0.appendingPathComponent("exclude").path
            }.get()
        case .global:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/git/ignore").path
        }
    }

    func ignoreRules(for type: IgnoreType) -> [String] {
        guard let file = self.ignoreFile(for: type) else { return [] }
        return ignoreRules(from: file)
    }

    func ignoreRules(from configPath: String) -> [String] {
        return parse(file: configPath)
    }

    func ignore(rules: [String], type: IgnoreType) -> Result<(), NSError> {
        if type == .memory {
            return self.ignoreInMemory(rules: rules)
        }
        guard let file = self.ignoreFile(for: type) else {
            return .failure(NSError(gitError: 0, description: "not ignore file for type \(type)") )
        }
        return self.ignore(rules: rules, configPath: file)
    }

    func ignore(rules: [String], configPath: String) -> Result<(), NSError> {
        var content = (try? String(contentsOfFile: configPath)) ?? ""
        if !content.hasSuffix("\n") {
            content.append("\n")
        }
        content.append(rules.joined(separator: "\n"))
        content.append("\n")
        do {
            try? FileManager.default.createDirectory(atPath: (configPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            return .success(())
        } catch let error as NSError {
            return .failure(error)
        } catch {
            return .failure(NSError(gitError: 0, description: "write ignore file error") )
        }
    }

    private func ignoreInMemory(rules: [String]) -> Result<(), NSError> {
        let result = git_ignore_add_rule(self.pointer, rules.joined(separator: "\n"))
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_ignore_add_rule"))
        }
        return .success(())
    }

    func checkIgnore(_ path: String) -> Bool {
        var ignore: Int32 = 0
        let result = git_ignore_path_is_ignored(&ignore, self.pointer, path)
        guard result == GIT_OK.rawValue else {
            return false
        }
        return ignore != 0
    }
}
