//
//  ConfigFile.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/10/14.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation

extension SSH2 {
    public class ConfigFile {
        public struct Path {
            public static let System = "/etc/ssh/ssh_config"
            public static let User = "~/.ssh/config"
        }

        public let filePath: String?
        public var items: [Any]

        init(filePath: String, items: [Any]) {
            self.filePath = filePath
            self.items = items
        }

        public var includes: [String] {
            return items.compactMap { ($0 as? ConfigFile)?.filePath }
        }
        public var configs: [Config] {
            var values = [Config]()
            for item in items {
                if let i = item as? ConfigFile {
                    values.append(contentsOf: i.configs)
                } else if let i = item as? Config {
                    values.append(i)
                }
            }
            return values
        }

        public func config(for host: String) -> [Config] {
            return self.configs.filter { $0.match(host: host) }
        }

        public class func parse(_ filepath: String) -> ConfigFile? {
            let path = (filepath as NSString).expandingTildeInPath
            guard let content = try? String(contentsOfFile: path) else { return nil }
            var items = [Any]()
            for line in content.split(separator: "\n") {
                let line = line.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.starts(with: "#") {
                    continue
                }
                var values = line.split(separator: "=").flatMap { $0.split(separator: " ") }.flatMap { $0.split(separator: ",") }.map { String($0) }
                if values.count < 2 { continue }
                let key = values.removeFirst().lowercased()
                if key == "include" {
                    let path = values.joined(separator: " ")
                    if let configFile = ConfigFile.parse(path) {
                        items.append(configFile)
                    }
                } else if key == "host" {
                    items.append(Config(hosts: values))
                } else {
                    if let config = items.last as? Config {
                        config.setup(key: key, values: values)
                    }
                }
            }
            let configFile = ConfigFile(filePath: filepath, items: items)
            return configFile
        }
    }
}
