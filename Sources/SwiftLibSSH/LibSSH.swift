import CLibSSH
import Foundation

public enum AccessType: Sendable {
  case readOnly
  case writeOnly
  case readWrite

  func raw(create: Bool = true, truncate: Bool = true) -> Int32 {
    switch self {
    case .readOnly:
      return O_RDONLY
    case .writeOnly:
      var result = O_WRONLY
      if create {
        result = result | O_CREAT
      }
      if truncate {
        result = result | O_TRUNC
      }
      return result
    case .readWrite:
      var result = O_RDWR
      if create {
        result = result | O_CREAT
      }
      if truncate {
        result = result | O_TRUNC
      }
      return result
    }
  }
}

public enum StreamType: Int32, Sendable {
  case stdout = 0
  case stderr = 1
}

// MARK: - Identifiers

struct SSHChannelID: Hashable, Sendable {
  let uuid = UUID()
}

struct SFTPClientID: Hashable, Sendable {
  let uuid = UUID()
}

struct SFTPFileID: Hashable, Sendable {
  let sftpId: SFTPClientID
  let uuid = UUID()
}

struct SFTPDirectoryID: Hashable, Sendable {
  let sftpId: SFTPClientID
  let uuid = UUID()
}

struct SFTPAioID: Hashable, Sendable {
  let fileId: SFTPFileID
  let uuid = UUID()

  init(fileId: SFTPFileID) {
    self.fileId = fileId
  }
}

public enum SFTPError: Codable, Error, Sendable, Equatable {
  case eof
  case noSuchFile
  case permissionDenied
  case failure
  case badMessage
  case noConnection
  case connectionLost
  case opUnsupported
  case invalidHandle
  case noSuchPath
  case fileAlreadyExists
  case writeProtect
  case noMedia

  static func from(code: Int32) -> SFTPError? {
    switch code {
    case SSH_FX_EOF: return .eof
    case SSH_FX_NO_SUCH_FILE: return .noSuchFile
    case SSH_FX_PERMISSION_DENIED: return .permissionDenied
    case SSH_FX_FAILURE: return .failure
    case SSH_FX_BAD_MESSAGE: return .badMessage
    case SSH_FX_NO_CONNECTION: return .noConnection
    case SSH_FX_CONNECTION_LOST: return .connectionLost
    case SSH_FX_OP_UNSUPPORTED: return .opUnsupported
    case SSH_FX_INVALID_HANDLE: return .invalidHandle
    case SSH_FX_NO_SUCH_PATH: return .noSuchPath
    case SSH_FX_FILE_ALREADY_EXISTS: return .fileAlreadyExists
    case SSH_FX_WRITE_PROTECT: return .writeProtect
    case SSH_FX_NO_MEDIA: return .noMedia
    default: return nil
    }
  }
}

public enum SSHKeyError: Codable, Error, Sendable, Equatable {
  case unreadable
  case passphraseRequired
  case invalid
}

public enum SSHError: Codable, Error, Sendable, Equatable {
  case connectionFailed(message: String)
  case closed(message: String)
  case authenticationFailed(message: String)
  case keyError(SSHKeyError, message: String)
  case sftpError(SFTPError, message: String)
  case channelOpenFailed(message: String)
  case localFileError(message: String)
  case libraryError(code: Int32, message: String)
  case invalidState(message: String)

  static func from(code: Int32, message: String) -> SSHError {
    switch code {
    case Int32(SSH_FATAL.rawValue):
      return .connectionFailed(message: message)
    case Int32(SSH_REQUEST_DENIED.rawValue):
      return .authenticationFailed(message: message)
    default:
      return .libraryError(code: code, message: message)
    }
  }

  public var isConnectionFailed: Bool {
    if case .connectionFailed = self { return true }
    return false
  }

  public var isClosed: Bool {
    if case .closed = self { return true }
    return false
  }

  public var isAuthenticationFailed: Bool {
    if case .authenticationFailed = self { return true }
    return false
  }

  public var keyError: SSHKeyError? {
    guard case .keyError(let error, _) = self else { return nil }
    return error
  }

  public var sftpError: SFTPError? {
    guard case .sftpError(let error, _) = self else { return nil }
    return error
  }

  public var isChannelOpenFailed: Bool {
    if case .channelOpenFailed = self { return true }
    return false
  }

  public var isLocalFileError: Bool {
    if case .localFileError = self { return true }
    return false
  }

  public var isLibraryError: Bool {
    if case .libraryError = self { return true }
    return false
  }

  public var isInvalidState: Bool {
    if case .invalidState = self { return true }
    return false
  }
}

private typealias ErrorMapper = (_ code: Int32, _ message: String) -> SSHError?

private func channelOpenError(fallback: String) -> ErrorMapper {
  { code, message in
    if code == Int32(SSH_REQUEST_DENIED.rawValue) {
      return .channelOpenFailed(message: message)
    }
    if code == 0 && message.isEmpty {
      return .invalidState(message: fallback)
    }
    return nil
  }
}

final actor SSHSession {
  private var session: ssh_session?
  private var channels: [SSHChannelID: ssh_channel] = [:]
  private var sftps: [SFTPClientID: sftp_session] = [:]

  private struct TrackedFile {
    let file: sftp_file
    var aios: [SFTPAioID: UnsafeMutablePointer<sftp_aio?>] = [:]
  }
  private var files: [SFTPFileID: TrackedFile] = [:]
  private var directories: [SFTPDirectoryID: sftp_dir] = [:]

  init() throws(SSHError) {
    guard let session: ssh_session = ssh_new() else {
      throw SSHError.invalidState(message: "Failed to initialize SSH session")
    }
    self.session = session
  }

  private func releaseResources() {
    for id in Array(files.keys) { closeFile(id: id) }
    for id in Array(directories.keys) { closeDirectory(id: id) }
    for id in Array(sftps.keys) { freeSftp(id: id) }
    for id in Array(channels.keys) { closeChannel(id: id) }
  }

  func free() {
    releaseResources()
    ssh_free(session)
    session = nil
  }

  func close() {
    releaseResources()
    disconnect()
    free()
  }

  // MARK: - Error Handling

  private func requireOpenSession() throws(SSHError) {
    if session == nil {
      throw .closed(message: "SSH session is closed")
    }
  }

  func requireConnected() throws(SSHError) {
    try requireOpenSession()
    if !isConnected {
      throw .connectionFailed(message: "SSH session is not connected")
    }
  }

  private func getErrorMessage() -> String {
    String(cString: ssh_get_error(UnsafeMutableRawPointer(session)))
  }

  private func getErrorCode() -> Int32 {
    ssh_get_error_code(UnsafeMutableRawPointer(session))
  }

  private func error(
    sftp: sftp_session? = nil,
    mapError: ErrorMapper = { _, _ in nil }
  ) -> SSHError {
    if session == nil {
      return .closed(message: "SSH session is closed")
    }

    let message = getErrorMessage()

    if let sftp = sftp {
      let sftpCode = sftp_get_error(sftp)
      if let sftpError = SFTPError.from(code: sftpCode) {
        return .sftpError(sftpError, message: message)
      }
    }

    let code = getErrorCode()
    if code == 0 && message.isEmpty && !isConnected {
      return .connectionFailed(message: "Connection lost")
    }

    return mapError(code, message) ?? .from(code: code, message: message)
  }

  private func validate(
    _ code: Int,
    sftp: sftp_session? = nil,
    mapError: ErrorMapper = { _, _ in nil },
    onFailure cleanup: () -> Void = {}
  ) throws(SSHError) {
    try validate(Int32(code), sftp: sftp, mapError: mapError, onFailure: cleanup)
  }

  private func validate(
    _ code: Int32,
    sftp: sftp_session? = nil,
    mapError: ErrorMapper = { _, _ in nil },
    onFailure cleanup: () -> Void = {}
  ) throws(SSHError) {
    guard code == SSH_OK else {
      cleanup()
      throw error(sftp: sftp, mapError: mapError)
    }
  }

  private func validate<E>(
    _ value: E?,
    sftp: sftp_session? = nil,
    mapError: ErrorMapper = { _, _ in nil },
    onFailure cleanup: () -> Void = {}
  ) throws(SSHError) -> E {
    guard let value = value else {
      cleanup()
      throw error(sftp: sftp, mapError: mapError)
    }
    return value
  }

  // MARK: - Session Operations

  func setOption(_ option: ssh_options_e, to value: UnsafeRawPointer) throws(SSHError) {
    try validate(ssh_options_set(session, option, value))
  }

  func setHost(_ host: String) throws(SSHError) {
    try setOption(SSH_OPTIONS_HOST, to: host)
  }

  func setPort(_ port: UInt32) throws(SSHError) {
    var port = port
    try setOption(SSH_OPTIONS_PORT, to: &port)
  }

  func setTimeout(_ timeout: UInt) throws(SSHError) {
    var timeout = timeout
    try setOption(SSH_OPTIONS_TIMEOUT, to: &timeout)
  }

  func connect() throws(SSHError) {
    try validate(ssh_connect(session))
  }

  func authenticate(user: String) throws(SSHError) {
    try validate(ssh_userauth_none(session, user))
  }

  func authenticate(user: String, password: String) throws(SSHError) {
    try validate(ssh_userauth_password(session, user, password))
  }

  func authenticate(user: String, key: SSHPrivateKey) throws(SSHError) {
    try key.withKey { key throws(SSHError) in
      try validate(ssh_userauth_publickey(session, user, key))
    }
  }

  var isConnected: Bool {
    ssh_is_connected(session) == 1
  }

  func disconnect() {
    ssh_disconnect(session)
  }

  // MARK: - Channel Operations

  private func channel(id: SSHChannelID) throws(SSHError) -> ssh_channel {
    try requireOpenSession()
    guard let channel = channels[id] else {
      throw .closed(message: "SSH channel is closed")
    }
    return channel
  }

  func withSessionChannel<T: Sendable>(
    _id: SSHChannelID = SSHChannelID(),
    perform body: @Sendable (SSHSessionChannel) async throws(SSHError) -> T
  ) async throws(SSHError) -> T {
    let channel = try openChannelSession(_id: _id)
    defer { closeChannel(id: _id) }
    return try await body(channel)
  }

  func withSessionChannel<T: Sendable>(
    _id: SSHChannelID = SSHChannelID(),
    perform body: @Sendable (SSHSessionChannel) async throws -> T
  ) async throws -> T {
    let channel = try openChannelSession(_id: _id)
    defer { closeChannel(id: _id) }
    return try await body(channel)
  }

  func openChannelSession(
    _id: SSHChannelID = SSHChannelID()
  ) throws(SSHError) -> SSHSessionChannel {
    try requireConnected()
    guard let channel = ssh_channel_new(session) else {
      throw .invalidState(message: "Failed to initialize SSH channel")
    }

    try validate(
      ssh_channel_open_session(channel),
      mapError: channelOpenError(fallback: "Failed to open SSH channel")
    ) {
      ssh_channel_free(channel)
    }

    channels[_id] = channel
    return SSHSessionChannel(session: self, id: _id)
  }

  func closeChannel(id: SSHChannelID) {
    guard let channel = channels.removeValue(forKey: id) else { return }
    _ = ssh_channel_close(channel)
    ssh_channel_free(channel)
  }

  func execute(onChannel id: SSHChannelID, command: String) throws(SSHError) {
    let channel = try channel(id: id)
    try validate(ssh_channel_request_exec(channel, command))
  }

  func exitState(onChannel id: SSHChannelID) throws(SSHError) -> SSHExitStatus {
    let channel = try channel(id: id)

    var code: Int32 = 0
    var signal: UnsafeMutablePointer<CChar>? = nil
    var coreDumped: Int32 = 0

    defer { ssh_string_free_char(signal) }
    try validate(ssh_channel_get_exit_state(channel, &code, &signal, &coreDumped))

    return SSHExitStatus.from(code: code, signal: signal, coreDumped: coreDumped)
  }

  func readChannel(
    id: SSHChannelID, into buffer: inout Data, length: Int, stream: StreamType
  ) throws(SSHError) -> Int {
    let channel = try channel(id: id)
    let bytesRead = buffer.withUnsafeMutableBytes({ raw in
      Int(ssh_channel_read(channel, raw.baseAddress, UInt32(length), stream.rawValue))
    })

    if bytesRead < 0 {
      try validate(bytesRead)
    }

    return bytesRead
  }

  // MARK: - SFTP Operations

  func sftp(id: SFTPClientID) throws(SSHError) -> sftp_session {
    try requireOpenSession()
    guard let sftp = sftps[id] else {
      throw .closed(message: "SFTP session is closed")
    }
    return sftp
  }

  func withSftp<T: Sendable>(
    _id: SFTPClientID = SFTPClientID(),
    perform body: (SFTPClient) async throws -> T
  ) async throws -> T {
    let sftp = try createSftp(_id: _id)
    defer { freeSftp(id: _id) }
    return try await body(sftp)
  }

  func createSftp(_id: SFTPClientID = SFTPClientID()) throws(SSHError) -> SFTPClient {
    try requireConnected()
    let sftp = try validate(
      sftp_new(session),
      mapError: channelOpenError(fallback: "Failed to initialize SFTP client")
    )
    try validate(sftp_init(sftp), sftp: sftp, onFailure: { sftp_free(sftp) })
    let limits = try limits(sftp: sftp, onFailure: { sftp_free(sftp) })
    sftps[_id] = sftp
    return SFTPClient(session: self, id: _id, limits: limits)
  }

  func freeSftp(id: SFTPClientID) {
    guard let sftp = sftps.removeValue(forKey: id) else { return }
    for fileId in files.keys.filter({ $0.sftpId == id }) { closeFile(id: fileId) }
    for dirId in directories.keys.filter({ $0.sftpId == id }) { closeDirectory(id: dirId) }
    sftp_free(sftp)
  }

  func mkdir(id: SFTPClientID, at path: String, mode: mode_t = 0o777) throws(SSHError) {
    let sftp = try sftp(id: id)
    try validate(sftp_mkdir(sftp, path, mode), sftp: sftp)
  }

  func rmdir(id: SFTPClientID, at path: String) throws(SSHError) {
    let sftp = try sftp(id: id)
    try validate(sftp_rmdir(sftp, path), sftp: sftp)
  }

  func stat(id: SFTPClientID, path: String) throws(SSHError) -> SFTPAttributes {
    let sftp = try sftp(id: id)
    let attributes = try validate(sftp_stat(sftp, path), sftp: sftp)
    defer { sftp_attributes_free(attributes) }
    return SFTPAttributes.from(raw: attributes.pointee)
  }

  func setStat(
    id: SFTPClientID,
    path: String,
    size: UInt64? = nil,
    uid: UInt32? = nil,
    gid: UInt32? = nil,
    permissions: mode_t? = nil,
    accessTime: Date? = nil,
    modifyTime: Date? = nil
  ) throws(SSHError) {
    let sftp = try sftp(id: id)
    let attributes = try validate(sftp_stat(sftp, path), sftp: sftp)
    defer { sftp_attributes_free(attributes) }

    var flags: UInt32 = 0

    if let size {
      attributes.pointee.size = size
      flags |= UInt32(bitPattern: SSH_FILEXFER_ATTR_SIZE)
    }

    if uid != nil || gid != nil {
      if let uid { attributes.pointee.uid = uid }
      if let gid { attributes.pointee.gid = gid }
      flags |= UInt32(bitPattern: SSH_FILEXFER_ATTR_UIDGID)
    }

    if let permissions {
      attributes.pointee.permissions = UInt32(permissions)
      flags |= UInt32(bitPattern: SSH_FILEXFER_ATTR_PERMISSIONS)
    }

    if let modifyTime {
      attributes.pointee.mtime = UInt32(modifyTime.timeIntervalSince1970)
      attributes.pointee.mtime_nseconds = 0
    }

    if let accessTime {
      attributes.pointee.atime = UInt32(accessTime.timeIntervalSince1970)
      attributes.pointee.atime_nseconds = 0
    }

    // SFTPv3 uses SSH_FILEXFER_ATTR_ACMODTIME (0x00000008) to set both
    // atime and mtime together. When only one is provided we keep the
    // existing value for the other (already present from the sftp_stat call).
    if accessTime != nil || modifyTime != nil {
      flags |= UInt32(bitPattern: SSH_FILEXFER_ATTR_ACMODTIME)
    }

    attributes.pointee.flags = flags
    try validate(sftp_setstat(sftp, path, attributes), sftp: sftp)
  }

  func lstat(id: SFTPClientID, path: String) throws(SSHError) -> SFTPAttributes {
    let sftp = try sftp(id: id)
    let attributes = try validate(sftp_lstat(sftp, path), sftp: sftp)
    defer { sftp_attributes_free(attributes) }
    return SFTPAttributes.from(raw: attributes.pointee)
  }

  func readlink(id: SFTPClientID, path: String) throws(SSHError) -> String {
    let sftp = try sftp(id: id)
    let link = try validate(sftp_readlink(sftp, path), sftp: sftp)
    defer { ssh_string_free_char(link) }
    return String(cString: link)
  }

  func symlink(id: SFTPClientID, target: String, dest: String) throws(SSHError) {
    let sftp = try sftp(id: id)
    do {
      try validate(sftp_symlink(sftp, target, dest), sftp: sftp)
    } catch {
      guard case .sftpError(.failure, let message) = error,
        let attributes = sftp_lstat(sftp, dest)
      else { throw error }
      sftp_attributes_free(attributes)
      throw .sftpError(.fileAlreadyExists, message: message)
    }
  }

  private func limits(sftp: sftp_session, onFailure cleanup: () -> Void = {})
    throws(SSHError) -> SFTPLimits
  {
    let raw = try validate(sftp_limits(sftp), sftp: sftp, onFailure: cleanup)
    defer { sftp_limits_free(raw) }
    return SFTPLimits.from(raw: raw.pointee)
  }

  func rename(id: SFTPClientID, from: String, to: String) throws(SSHError) {
    let sftp = try sftp(id: id)
    try validate(sftp_rename(sftp, from, to), sftp: sftp)
  }

  func unlink(id: SFTPClientID, path: String) throws(SSHError) {
    let sftp = try sftp(id: id)
    try validate(sftp_unlink(sftp, path), sftp: sftp)
  }

  // MARK: - SFTP File

  func file(id: SFTPFileID) throws(SSHError) -> sftp_file {
    try requireOpenSession()
    guard let trackedFile = files[id] else {
      throw .closed(message: "SFTP file is closed")
    }
    return trackedFile.file
  }

  func withSftpFile<T: Sendable>(
    _id: SFTPFileID? = nil,
    id: SFTPClientID, path: String, accessType: AccessType, mode: mode_t = 0o666,
    limits: SFTPLimits, perform body: (SFTPFile) async throws -> T
  ) async throws -> T {
    let _id = _id ?? SFTPFileID(sftpId: id)
    let file = try openFile(
      _id: _id, id: id, path: path, accessType: accessType, mode: mode, limits: limits
    )
    defer { closeFile(id: _id) }
    return try await body(file)
  }

  func openFile(
    _id: SFTPFileID? = nil,
    id: SFTPClientID, path: String, accessType: AccessType, mode: mode_t = 0o666, limits: SFTPLimits
  ) throws(SSHError) -> SFTPFile {
    let _id = _id ?? SFTPFileID(sftpId: id)
    let sftp = try sftp(id: id)
    let sftpFile = try validate(sftp_open(sftp, path, accessType.raw(), mode), sftp: sftp)
    files[_id] = TrackedFile(file: sftpFile)
    return SFTPFile(session: self, id: _id, limits: limits)
  }

  func closeFile(id: SFTPFileID) {
    guard let trackedFile = files.removeValue(forKey: id) else { return }
    sftp_close(trackedFile.file)
    for aio in trackedFile.aios.values {
      freeAio(aio)
    }
  }

  func statFile(id: SFTPFileID) throws(SSHError) -> SFTPAttributes {
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)
    let attributes = try validate(sftp_fstat(file), sftp: sftp)
    defer { sftp_attributes_free(attributes) }
    return SFTPAttributes.from(raw: attributes.pointee)
  }

  func seekFile(id: SFTPFileID, offset: UInt64) throws(SSHError) {
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)
    try validate(sftp_seek64(file, offset), sftp: sftp)
  }

  func readFile(id: SFTPFileID, into buffer: inout Data, length: Int) throws(SSHError) -> Int {
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)

    let bytesRead = buffer.withUnsafeMutableBytes({ raw in
      sftp_read(file, raw.baseAddress, length)
    })

    if bytesRead < 0 {
      try validate(bytesRead, sftp: sftp)
    }

    return bytesRead
  }

  func writeFile(id: SFTPFileID, data: Data) throws(SSHError) -> Int {
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)

    let bufferSize = data.count
    let bytesWritten = data.withUnsafeBytes({ raw in
      sftp_write(file, raw.baseAddress, bufferSize)
    })

    if bytesWritten < 0 {
      try validate(bytesWritten, sftp: sftp)
    }

    return bytesWritten
  }

  // MARK: - SFTP Directory

  func directory(id: SFTPDirectoryID) throws(SSHError) -> sftp_dir {
    try requireOpenSession()
    guard let dir = directories[id] else {
      throw .closed(message: "SFTP directory is closed")
    }
    return dir
  }

  func withDirectory<T: Sendable>(
    id: SFTPClientID, path: String,
    perform: @Sendable (SFTPDirectory) async throws -> T
  ) async throws -> T {
    let _id = SFTPDirectoryID(sftpId: id)
    let dir = try openDirectory(_id: _id, id: id, path: path)
    defer { closeDirectory(id: _id) }
    return try await perform(dir)
  }

  func openDirectory(
    _id: SFTPDirectoryID,
    id: SFTPClientID, path: String
  ) throws(SSHError) -> SFTPDirectory {
    let sftp = try sftp(id: id)
    let dir = try validate(sftp_opendir(sftp, path), sftp: sftp)
    directories[_id] = dir
    return SFTPDirectory(session: self, id: _id)
  }

  func closeDirectory(id: SFTPDirectoryID) {
    guard let dir = directories.removeValue(forKey: id) else { return }
    sftp_closedir(dir)
  }

  func readDirectory(id: SFTPDirectoryID) throws(SSHError) -> SFTPAttributes? {
    let sftp = try sftp(id: id.sftpId)
    let dir = try directory(id: id)
    guard let attributes = sftp_readdir(sftp, dir) else {
      return nil
    }
    defer { sftp_attributes_free(attributes) }
    return SFTPAttributes.from(raw: attributes.pointee)
  }

  // MARK: - AIO

  private func freeAio(_ aio: UnsafeMutablePointer<sftp_aio?>) {
    sftp_aio_free(aio.pointee)
    aio.deallocate()
  }

  private func withFreeingAio<T: Sendable>(
    id: SFTPAioID,
    perform body: (UnsafeMutablePointer<sftp_aio?>) throws(SSHError) -> T
  ) throws(SSHError) -> T {
    try requireOpenSession()
    guard let aio = files[id.fileId]?.aios.removeValue(forKey: id) else {
      throw .closed(message: "SFTP file is closed")
    }
    defer { freeAio(aio) }
    return try body(aio)
  }

  private func sendableBytes(sftp: sftp_session, file: sftp_file) -> Int? {
    guard let channel = sftp.pointee.channel else { return nil }
    let overhead = Int(ssh_string_len(file.pointee.handle)) + 25
    let available = Int(ssh_channel_window_size(channel)) - overhead
    return available >= 0 ? available : nil
  }

  func beginRead(id: SFTPFileID, length: Int) throws(SSHError) -> SFTPAioReadContext? {
    let aioId = SFTPAioID(fileId: id)
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)
    guard sendableBytes(sftp: sftp, file: file) != nil else { return nil }

    // `allocate` leaves the slot uninitialized and the aio is registered before the begin call
    // runs, so a failed begin would leave `freeAio` reading garbage. libssh makes no promise
    // about `*aio` on error; `sftp_aio_free(nil)` is a no-op.
    let aio = UnsafeMutablePointer<sftp_aio?>.allocate(capacity: 1)
    aio.initialize(to: nil)
    files[id]?.aios[aioId] = aio

    let bytesToRead = sftp_aio_begin_read(file, length, aio)
    if bytesToRead < 0 {
      try validate(bytesToRead, sftp: sftp)
    }

    return SFTPAioReadContext(session: self, id: aioId, length: length)
  }

  func waitRead(id: SFTPAioID, into buffer: inout Data, length: Int) throws(SSHError) -> Int {
    let bytesRead = try withFreeingAio(id: id) { aio in
      buffer.withUnsafeMutableBytes({ raw in
        sftp_aio_wait_read(aio, raw.baseAddress, length)
      })
    }

    if bytesRead < 0 {
      try validate(bytesRead, sftp: sftp(id: id.fileId.sftpId))
    }

    return bytesRead
  }

  func beginWrite(id: SFTPFileID, buffer: Data) throws(SSHError) -> SFTPAioWriteContext? {
    let aioId = SFTPAioID(fileId: id)
    let file = try file(id: id)
    let sftp = try sftp(id: id.sftpId)
    guard let available = sendableBytes(sftp: sftp, file: file), available > 0 else { return nil }

    // `allocate` leaves the slot uninitialized and the aio is registered before the begin call
    // runs, so a failed begin would leave `freeAio` reading garbage. libssh makes no promise
    // about `*aio` on error; `sftp_aio_free(nil)` is a no-op.
    let aio = UnsafeMutablePointer<sftp_aio?>.allocate(capacity: 1)
    aio.initialize(to: nil)
    files[id]?.aios[aioId] = aio

    let length = Swift.min(buffer.count, available)
    let bytesToWrite = buffer.withUnsafeBytes({ raw in
      sftp_aio_begin_write(file, raw.baseAddress, length, aio)
    })

    if bytesToWrite < 0 {
      try validate(bytesToWrite, sftp: sftp)
    }

    return SFTPAioWriteContext(session: self, id: aioId, length: bytesToWrite)
  }

  func waitWrite(id: SFTPAioID) throws(SSHError) {
    let bytesWritten = try withFreeingAio(id: id) { aio in
      sftp_aio_wait_write(aio)
    }

    if bytesWritten < 0 {
      try validate(bytesWritten, sftp: sftp(id: id.fileId.sftpId))
    }
  }
}
