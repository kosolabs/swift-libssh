import Foundation

public struct SFTPClient: Sendable {
  private let session: SSHSession
  private let id: SFTPClientID
  public let limits: SFTPLimits

  init(session: SSHSession, id: SFTPClientID, limits: SFTPLimits) {
    self.session = session
    self.id = id
    self.limits = limits
  }

  public func close() async {
    await session.freeSftp(id: id)
  }

  public func createDirectory(at path: String, mode: mode_t = 0o777) async throws(SSHError) {
    try await session.mkdir(id: id, at: path, mode: mode)
  }

  public func createDirectoryRecursively(
    at path: String, mode: mode_t = 0o777
  ) async throws(SSHError) {
    let isAbsolute = path.hasPrefix("/")
    let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    for i in components.indices {
      let partial = (isAbsolute ? "/" : "") + components[0...i].joined(separator: "/")
      do {
        try await createDirectory(at: partial, mode: mode)
      } catch {
        guard error.sftpError == .fileAlreadyExists else { throw error }
      }
    }
  }

  public func removeDirectory(at path: String) async throws(SSHError) {
    try await session.rmdir(id: id, at: path)
  }

  public func removeDirectoryRecursively(at path: String) async throws {
    try await withDirectory(at: path) { directory in
      for try await entry in directory {
        guard let name = entry.name else { continue }
        let entryPath = path + "/" + name
        if entry.type == .directory {
          try await removeDirectoryRecursively(at: entryPath)
        } else {
          try await removeFile(at: entryPath)
        }
      }
    }
    try await removeDirectory(at: path)
  }

  public func withDirectory<T: Sendable>(
    at path: String, perform: @Sendable (SFTPDirectory) async throws -> T
  ) async throws -> T {
    try await session.withDirectory(id: id, path: path, perform: perform)
  }

  public func attributes(
    at path: String, followSymlinks: Bool = true
  ) async throws(SSHError) -> SFTPAttributes {
    if followSymlinks {
      try await session.stat(id: id, path: path)
    } else {
      try await session.lstat(id: id, path: path)
    }
  }

  public func setAttributes(
    at path: String,
    size: UInt64? = nil,
    uid: UInt32? = nil,
    gid: UInt32? = nil,
    permissions: mode_t? = nil,
    accessTime: Date? = nil,
    modifyTime: Date? = nil
  ) async throws(SSHError) {
    try await session.setStat(
      id: id,
      path: path,
      size: size,
      uid: uid,
      gid: gid,
      permissions: permissions,
      accessTime: accessTime,
      modifyTime: modifyTime
    )
  }

  public func move(from oldPath: String, to newPath: String) async throws(SSHError) {
    try await session.rename(id: id, from: oldPath, to: newPath)
  }

  public func removeFile(at path: String) async throws(SSHError) {
    try await session.unlink(id: id, path: path)
  }

  public func symlinkTarget(at path: String) async throws(SSHError) -> String {
    try await session.readlink(id: id, path: path)
  }

  public func createSymlink(to target: String, at dest: String) async throws(SSHError) {
    try await session.symlink(id: id, target: target, dest: dest)
  }

  public func withSftpFile<T: Sendable>(
    at path: String, accessType: AccessType, mode: mode_t = 0o666,
    perform: @Sendable (SFTPFile) async throws -> T
  ) async throws -> T {
    try await session.withSftpFile(
      id: id, path: path, accessType: accessType, mode: mode, limits: limits, perform: perform
    )
  }

  public func download(
    from remotePath: String, to localURL: URL,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize,
    progress: (@Sendable (UInt64) -> Void)? = nil
  ) async throws {
    try await withSftpFile(at: remotePath, accessType: .readOnly) { file in
      try await file.download(to: localURL, bufferSize: bufferSize, progress: progress)
    }
  }

  public func upload(
    from localURL: URL, to remotePath: String, mode: mode_t = 0o666,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize,
    progress: (@Sendable (UInt64) -> Void)? = nil
  ) async throws {
    try await withSftpFile(at: remotePath, accessType: .writeOnly, mode: mode) { file in
      try await file.upload(from: localURL, bufferSize: bufferSize, progress: progress)
    }
  }
}
