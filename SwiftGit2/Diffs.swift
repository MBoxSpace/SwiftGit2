//
//  Diffs.swift
//  SwiftGit2
//
//  Created by Jake Van Alstyne on 8/20/17.
//  Copyright © 2017 GitHub, Inc. All rights reserved.
//

@_implementationOnly import git2

public struct StatusEntry {
    public var status: Diff.Status
    public var headToIndex: Diff.Delta?
    public var indexToWorkDir: Diff.Delta?

    init(from statusEntry: git_status_entry) {
        self.status = Diff.Status(rawValue: statusEntry.status.rawValue)

        if let htoi = statusEntry.head_to_index {
            self.headToIndex = Diff.Delta(htoi.pointee)
        }

        if let itow = statusEntry.index_to_workdir {
            self.indexToWorkDir = Diff.Delta(itow.pointee)
        }
    }
}

public struct Diff {

    /// The set of deltas.
    public var deltas = [Delta]()

    public struct Delta {
        public enum Status: UInt32 {
            case unmodified     = 0     /**< no changes */
            case added          = 1     /**< entry does not exist in old version */
            case deleted        = 2     /**< entry does not exist in new version */
            case modified       = 3     /**< entry content changed between old and new */
            case renamed        = 4     /**< entry was renamed between old and new */
            case copied         = 5     /**< entry was copied from another old entry */
            case ignored        = 6     /**< entry is ignored item in workdir */
            case untracked      = 7     /**< entry is untracked item in workdir */
            case typeChange     = 8     /**< type of entry changed between old and new */
            case unreadable     = 9     /**< entry is unreadable */
            case conflicted     = 10    /**< entry in the index is conflicted */
        }
        static let type = GIT_OBJECT_REF_DELTA

        public var status: Status
        public var statusName: String
        public var flags: Flags
        public var oldFile: File?
        public var newFile: File?

        init(_ delta: git_diff_delta) {
            self.status = Status(rawValue: delta.status.rawValue)!
            self.statusName = String(UnicodeScalar(UInt8(git_diff_status_char(delta.status))))
            self.flags = Flags(rawValue: delta.flags)
            self.oldFile = File(delta.old_file)
            self.newFile = File(delta.new_file)
        }
    }

    public struct File {
        public var oid: OID
        public var path: String
        public var size: UInt64
        public var flags: Flags
        public var mode: UInt32

        init(_ diffFile: git_diff_file) {
            self.oid = OID(diffFile.id)
            let path = diffFile.path
            self.path = path.map(String.init(cString:))!
            self.size = diffFile.size
            self.flags = Flags(rawValue: diffFile.flags)
            self.mode = UInt32(diffFile.mode)
        }
    }

    public struct Status: OptionSet {
        // This appears to be necessary due to bug in Swift
        // https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        public let rawValue: UInt32

        public static let current                = Status(rawValue: GIT_STATUS_CURRENT.rawValue)
        public static let indexNew               = Status(rawValue: GIT_STATUS_INDEX_NEW.rawValue)
        public static let indexModified          = Status(rawValue: GIT_STATUS_INDEX_MODIFIED.rawValue)
        public static let indexDeleted           = Status(rawValue: GIT_STATUS_INDEX_DELETED.rawValue)
        public static let indexRenamed           = Status(rawValue: GIT_STATUS_INDEX_RENAMED.rawValue)
        public static let indexTypeChange        = Status(rawValue: GIT_STATUS_INDEX_TYPECHANGE.rawValue)
        public static let workTreeNew            = Status(rawValue: GIT_STATUS_WT_NEW.rawValue)
        public static let workTreeModified       = Status(rawValue: GIT_STATUS_WT_MODIFIED.rawValue)
        public static let workTreeDeleted        = Status(rawValue: GIT_STATUS_WT_DELETED.rawValue)
        public static let workTreeTypeChange     = Status(rawValue: GIT_STATUS_WT_TYPECHANGE.rawValue)
        public static let workTreeRenamed        = Status(rawValue: GIT_STATUS_WT_RENAMED.rawValue)
        public static let workTreeUnreadable     = Status(rawValue: GIT_STATUS_WT_UNREADABLE.rawValue)
        public static let ignored                = Status(rawValue: GIT_STATUS_IGNORED.rawValue)
        public static let conflicted             = Status(rawValue: GIT_STATUS_CONFLICTED.rawValue)
    }

    public struct Flags: OptionSet {
        // This appears to be necessary due to bug in Swift
        // https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        public let rawValue: UInt32

        public static let binary     = Flags(rawValue: 1 << 0)
        public static let notBinary  = Flags(rawValue: 1 << 1)
        public static let validId    = Flags(rawValue: 1 << 2)
        public static let exists     = Flags(rawValue: 1 << 3)
    }

    /// Create an instance with a libgit2 `git_diff`.
    public init(_ pointer: OpaquePointer) {
        for i in 0..<git_diff_num_deltas(pointer) {
            if let delta = git_diff_get_delta(pointer, i) {
                deltas.append(Diff.Delta(delta.pointee))
            }
        }
    }
}
