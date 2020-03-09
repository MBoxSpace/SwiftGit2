//
//  FileMode.swift
//  SwiftGit2-OSX
//
//  Created by 詹迟晶 on 2020/3/9.
//  Copyright © 2020 GitHub, Inc. All rights reserved.
//

import Foundation
import git2

public enum FileMode: UInt32 {
    case unreadable = 0000000
    case tree       = 0040000
    case blob       = 0100644
    case executable = 0100755
    case link       = 0120000
    case commit     = 0160000
}
