//
//  Repository.swift
//  SwiftGit2
//
//  Created by Matt Diephouse on 11/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation
@_implementationOnly import git2

/// A git repository.
public final class Repository {

    // MARK: - Creating Repositories

    /// Create a new repository at the given URL.
    ///
    /// URL - The URL of the repository.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public class func create(at url: URL) -> Result<Repository, NSError> {
        var pointer: OpaquePointer? = nil
        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_init(&pointer, $0, 0)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_init"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    /// Load the repository at the given URL.
    ///
    /// URL - The URL of the repository.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public class func at(_ url: URL) -> Result<Repository, NSError> {
        var pointer: OpaquePointer? = nil
        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_open(&pointer, $0)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_open"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    public class func discover(_ path: String, acrossFS: Bool = false, ceiling: [String] = []) -> Result<Repository, NSError> {
        var buf = git_buf(ptr: nil, reserved: 0, size: 0)
        defer {
            git_buf_dispose(&buf)
        }
        let result = path.withCString { start_path in
            return ceiling.joined(separator: ":").withCString { ceiling_dirs in
                return git_repository_discover(&buf, start_path, acrossFS ? 1 : 0, ceiling_dirs)
            }
        }
        guard result == GIT_OK.rawValue,
              let root = String(bytes: buf.ptr, count: buf.size) else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_discover"))
        }
        return Repository.at(URL(fileURLWithPath: root))
    }

    // MARK: - Initializers

    /// Create an instance with a libgit2 `git_repository` object.
    ///
    /// The Repository assumes ownership of the `git_repository` object.
    public init(_ pointer: OpaquePointer, submodule: Submodule? = nil) {
        self.pointer = pointer
        self.submodule = submodule
    }

    deinit {
        git_repository_free(pointer)
    }

    // MARK: - Properties

    /// The underlying libgit2 `git_repository` object.
    public let pointer: OpaquePointer

    /**
     * Get the path of this repository
     *
     * This is the path of the `.git` folder for normal repositories,
     * or of the repository itself for bare repositories.
     */
    public lazy var gitDir: URL? = {
        let path = git_repository_path(pointer)
        return path.map { URL(fileURLWithPath: String(validatingUTF8: $0)!, isDirectory: true) }
    }()

    /// The URL of the repository's working directory, or `nil` if the
    /// repository is bare.
    public lazy var workDir: URL? = {
        let path = git_repository_workdir(pointer)
        return path.map { URL(fileURLWithPath: String(validatingUTF8: $0)!, isDirectory: true) }
    }()

    /**
     * Get the path of the shared common directory for this repository.
     *
     * If the repository is bare, it is the root directory for the repository.
     * If the repository is a worktree, it is the parent repo's gitdir.
     * Otherwise, it is the gitdir.
     */
    public lazy var commonDir: URL? = {
        let path = git_repository_commondir(pointer)
        return path.map { URL(fileURLWithPath: String(validatingUTF8: $0)!, isDirectory: true) }
    }()

    public func path(for item: Item) -> Result<URL, NSError> {
        var pathBuf = git_buf()
        let result = git_repository_item_path(&pathBuf, pointer, item.toGit())
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_item_path"))
        }
        guard let url = pathBuf.ptr.map({ URL(fileURLWithPath: String(validatingUTF8: $0)!, isDirectory: true) }) else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_item_path"))
        }
        return .success(url)
    }

    public var submodule: Submodule?

    // MARK: - Object Lookups

    /// Load a libgit2 object and transform it to something else.
    ///
    /// oid       - The OID of the object to look up.
    /// type      - The type of the object to look up.
    /// transform - A function that takes the libgit2 object and transforms it
    ///             into something else.
    ///
    /// Returns the result of calling `transform` or an error if the object
    /// cannot be loaded.
    func withGitObject<T>(_ oid: OID, type: git_object_t,
                          transform: (OpaquePointer) -> Result<T, NSError>) -> Result<T, NSError> {
        var pointer: OpaquePointer? = nil
        var git_oid = oid.oid
        let result = git_object_lookup_prefix(&pointer, self.pointer, &git_oid, oid.length, type)

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_object_lookup_prefix"))
        }

        let value = transform(pointer!)
        git_object_free(pointer)
        return value
    }

    func withGitObject<T>(_ oid: OID, type: git_object_t, transform: (OpaquePointer) -> T) -> Result<T, NSError> {
        return withGitObject(oid, type: type) { Result.success(transform($0)) }
    }

    func withGitObjects<T>(_ oids: [OID], type: git_object_t, transform: ([OpaquePointer]) -> Result<T, NSError>) -> Result<T, NSError> {
        var pointers = [OpaquePointer]()
        defer {
            for pointer in pointers {
                git_object_free(pointer)
            }
        }

        for oid in oids {
            var pointer: OpaquePointer? = nil
            var oid = oid.oid
            let result = git_object_lookup(&pointer, self.pointer, &oid, type)

            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_object_lookup"))
            }

            pointers.append(pointer!)
        }

        return transform(pointers)
    }

    /// Loads the object with the given OID.
    ///
    /// oid - The OID of the blob to look up.
    ///
    /// Returns a `Blob`, `Commit`, `Tag`, or `Tree` if one exists, or an error.
    public func object(_ oid: OID) -> Result<ObjectType, NSError> {
        return withGitObject(oid, type: GIT_OBJECT_ANY) { object in
            return self.object(from: object)
        }
    }

    /// Loads the referenced object from the pointer.
    ///
    /// pointer - A pointer to an object.
    ///
    /// Returns the object if it exists, or an error.
    public func object<T>(from pointer: PointerTo<T>) -> Result<T, NSError> {
        return withGitObject(pointer.oid, type: pointer.type.git_type) { T($0) }
    }

    /// Loads the referenced object from the pointer.
    ///
    /// pointer - A pointer to an object.
    ///
    /// Returns the object if it exists, or an error.
    public func object(from pointer: Pointer) -> Result<ObjectType, NSError> {
        switch pointer {
        case let .blob(oid):
            return blob(oid).map { $0 as ObjectType }
        case let .commit(oid):
            return commit(oid).map { $0 as ObjectType }
        case let .tag(oid):
            return tag(oid).map { $0 as ObjectType }
        case let .tree(oid):
            return tree(oid).map { $0 as ObjectType }
        }
    }

    /// Loads the referenced object from the git_object.
    ///
    /// pointer - A pointer to an object.
    ///
    /// Returns the object if it exists, or an error.
    func object(from object: OpaquePointer) -> Result<ObjectType, NSError> {
        let type = git_object_type(object)
        if type == Blob.type.git_type {
            return .success(Blob(object))
        } else if type == Commit.type.git_type {
            return .success(Commit(object))
        } else if type == Tag.type.git_type {
            return .success(Tag(object))
        } else if type == Tree.type.git_type {
            return .success(Tree(object))
        }
        let error = NSError(domain: "org.libgit2.SwiftGit2",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Unrecognized git_object_t '\(type)'."])
        return Result.failure(error)
    }

    public func object(from name: String) -> Result<ObjectType, NSError> {
        var pointer: OpaquePointer? = nil
        let result = git_revparse_single(&pointer, self.pointer, name)
        defer { git_object_free(pointer) }
        guard result == GIT_OK.rawValue, let point = pointer else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_revparse_single"))
        }
        return object(from: point)
    }

    /// Loads the blob with the given OID.
    ///
    /// oid - The OID of the blob to look up.
    ///
    /// Returns the blob if it exists, or an error.
    public func blob(_ oid: OID) -> Result<Blob, NSError> {
        return withGitObject(oid, type: GIT_OBJECT_BLOB) { Blob($0) }
    }

    /// Loads the tree with the given OID.
    ///
    /// oid - The OID of the tree to look up.
    ///
    /// Returns the tree if it exists, or an error.
    public func tree(_ oid: OID) -> Result<Tree, NSError> {
        return withGitObject(oid, type: GIT_OBJECT_TREE) { Tree($0) }
    }

    // MARK: - Status

    public func status(options: StatusOptions? = nil) -> Result<[StatusEntry], NSError> {
        let options = options ?? .includeUntracked
        var returnArray = [StatusEntry]()

        // Do this because GIT_STATUS_OPTIONS_INIT is unavailable in swift
        let pointer = UnsafeMutablePointer<git_status_options>.allocate(capacity: 1)
        let optionsResult = git_status_options_init(pointer, UInt32(GIT_STATUS_OPTIONS_VERSION))
        guard optionsResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: optionsResult, pointOfFailure: "git_status_init_options"))
        }
        var opts = pointer.move()
        opts.flags = options.rawValue
        pointer.deallocate()

        var unsafeStatus: OpaquePointer? = nil
        defer { git_status_list_free(unsafeStatus) }
        let statusResult = git_status_list_new(&unsafeStatus, self.pointer, &opts)
        guard statusResult == GIT_OK.rawValue, let unwrapStatusResult = unsafeStatus else {
            return .failure(NSError(gitError: statusResult, pointOfFailure: "git_status_list_new"))
        }

        let count = git_status_list_entrycount(unwrapStatusResult)

        for i in 0..<count {
            let s = git_status_byindex(unwrapStatusResult, i)
            if s?.pointee.status.rawValue == GIT_STATUS_CURRENT.rawValue {
                continue
            }

            let statusEntry = StatusEntry(from: s!.pointee)
            returnArray.append(statusEntry)
        }

        return .success(returnArray)
    }

    public func status(for path: String) -> Result<Diff.Status?, NSError> {
        var flags: UInt32 = 0
        let result = path.withCString { cpath in
            git_status_file(&flags, self.pointer, cpath)
        }
        if result == GIT_ENOTFOUND.rawValue {
            return .success(nil)
        }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_status_file"))
        }
        return .success(Diff.Status(rawValue: flags))
    }

    // MARK: - Validity/Existence Check

    /// - returns: `.success(true)` iff there is a git repository at `url`,
    ///   `.success(false)` if there isn't,
    ///   and a `.failure` if there's been an error.
    public static func isValid(url: URL) -> Result<Bool, NSError> {
        var pointer: OpaquePointer?

        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_open_ext(&pointer, $0, GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, nil)
        }

        switch result {
        case GIT_ENOTFOUND.rawValue:
            return .success(false)
        case GIT_OK.rawValue:
            return .success(true)
        default:
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_open_ext"))
        }
    }

    /*
     * The tag name will be checked for validity. You must avoid
     * the characters '~', '^', ':', '\\', '?', '[', and '*', and the
     * sequences ".." and "@{" which have special meaning to revparse.
     */
    public func checkValid(_ refname: String) -> Bool {
        var status: Int32 = 0
        let result = git_reference_name_is_valid(&status, refname)
        guard result == GIT_OK.rawValue else {
            return false
        }
        return status == 1
    }
}

extension Array {
    func aggregateResult<Value, Error>() -> Result<[Value], Error> where Element == Result<Value, Error> {
        var values: [Value] = []
        for result in self {
            switch result {
            case .success(let value):
                values.append(value)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(values)
    }
}
