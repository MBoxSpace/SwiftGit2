//
//  GitURL.swift
//  SwiftGit2-OSX
//
//  Created by Whirlwind on 2019/10/14.
//  Copyright © 2019 GitHub, Inc. All rights reserved.
//

import Foundation

public struct GitURL {
    public init?(_ git: String) {
        guard let regex = try? NSRegularExpression(pattern: "^((.*):\\/\\/)?((.*)@)?(.*?)[:|\\/](.*?)\\/(.*?)(.git)?$", options: []),
            let result = regex.firstMatch(in: git, range: NSMakeRange(0, git.count)) else {
                return nil
        }
        let nsString = git as NSString
        let matchData = (0..<result.numberOfRanges).map { (index) -> String? in
            let range = result.range(at: index)
            if range.location == NSNotFound {
                return nil
            } else {
                return nsString.substring(with: range)
            }
        }
        scheme = matchData[2]?.lowercased() ?? "ssh"
        user = matchData[4]
        host = matchData[5]!
        group = matchData[6]!
        project = matchData[7]!
    }

    public private(set) var scheme: String
    public private(set) var host: String
    public private(set) var user: String?
    public private(set) var group: String
    public private(set) var project: String
}
