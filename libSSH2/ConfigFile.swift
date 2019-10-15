//
//  ConfigFile.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2019/10/14.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation

extension SSH2 {
    public class ConfigFile {
        public var configs: [Config]

        init(configs: [Config]) {
            self.configs = configs
        }

        public func config(for host: String) -> Config? {
            return self.configs.first { $0.match(host: host) }
        }

        public class func parse(_ path: String) -> ConfigFile? {
            guard let content = try? String(contentsOfFile: path) else { return nil }
            var configs = [Config]()
            for line in content.split(separator: "\n") {
                let line = line.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.starts(with: "#") {
                    continue
                }
                var values = line.split(separator: "=").flatMap { $0.split(separator: " ") }.flatMap { $0.split(separator: ",") }.map { String($0) }
                if values.count < 2 { continue }
                let key = values.removeFirst().lowercased()
                if key == "host" {
                    configs.append(Config(hosts: values))
                } else {
                    configs.last?.setup(key: key, values: values)
                }
            }
            let configFile = ConfigFile(configs: configs)
            return configFile
        }
    }
}
