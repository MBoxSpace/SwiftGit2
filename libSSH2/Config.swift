//
//  Config.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2019/10/14.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation

extension SSH2 {
    public class Config: NSCopying {
        public var hosts: [String]

        public var hostName: String?
        public var user: String?
        public var port: String?
        public var identityFiles: [String]?

        init(hosts: [String]) {
            self.hosts = hosts
        }

        public func match(host: String) -> Bool {
            let host = host.lowercased()
            for myhost in hosts {
                var myhost = myhost.lowercased()

                let negated = myhost.starts(with: "!")
                if negated { myhost.removeFirst() }

                if !myhost.contains("*") && !myhost.contains("?") {
                    if host == myhost {
                        return !negated
                    }
                } else {
                    var regexString = myhost.replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "*", with: ".*")
                    regexString = regexString.replacingOccurrences(of: "?", with: ".")
                    guard let regex = try? NSRegularExpression(pattern: regexString) else { continue }
                    if regex.firstMatch(in: host, range: NSMakeRange(0, host.count)) != nil {
                        return !negated
                    }
                }
            }
            return false
        }

        public func setup(key: String, values: [String]) {
            guard !values.isEmpty else { return }
            let param = values.last!
            switch key {
            case "user":
                self.user = param
            case "port":
                self.port = param
            case "hostname":
                self.hostName = param
            case "identityfile":
                if self.identityFiles == nil {
                    self.identityFiles = []
                }
                self.identityFiles?.append((param as NSString).expandingTildeInPath)
            default:
                break
            }
        }

        public func copy(with zone: NSZone? = nil) -> Any {
            let config = Config(hosts: self.hosts)
            config.hostName = self.hostName
            config.user = self.user
            config.port = self.port
            config.hosts = self.hosts
            config.identityFiles = self.identityFiles
            return config
        }

        public func merge(_ config: Config) -> Config {
            let result = self.copy() as! Config
            result.hosts.append(contentsOf: config.hosts)
            result.hosts = Array(Set(result.hosts))
            if config.user != nil {
                result.user = config.user
            }
            if config.port != nil {
                result.port = config.port
            }
            if config.hostName != nil {
                result.hostName = config.hostName
            }
            if config.identityFiles != nil {
                result.identityFiles = Array(Set((result.identityFiles ?? []) + (config.identityFiles ?? [])))
            }
            return result
        }
    }
}
