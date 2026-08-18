import CLibSSH
import Dispatch
import Foundation

public enum SSHAuthMethod: Sendable {
  case none
  case password(String)
  case privateKey(SSHPrivateKey)

  public static func privateKey(
    contentsOf file: URL, passphrase: String? = nil
  ) throws(SSHError) -> Self {
    .privateKey(try SSHPrivateKey(contentsOf: file, passphrase: passphrase))
  }

  public static func privateKey(
    contents: String, passphrase: String? = nil
  ) throws(SSHError) -> Self {
    .privateKey(try SSHPrivateKey(contents: contents, passphrase: passphrase))
  }
}

public struct SSHClient: Sendable {
  public struct CommandResult: Sendable {
    public let status: SSHExitStatus
    public let stdout: Data
    public let stderr: Data
  }

  private let session: SSHSession

  private init(host: String, port: UInt16 = 22, timeout: UInt = 60) async throws(SSHError) {
    self.session = try SSHSession()
    try await session.setHost(host)
    try await session.setPort(UInt32(port))
    try await session.setTimeout(timeout)
  }

  private func connect() async throws(SSHError) {
    try await session.connect()
  }

  private func authenticate(user: String, auth: SSHAuthMethod) async throws(SSHError) {
    switch auth {
    case .none:
      try await session.authenticate(user: user)

    case .password(let password):
      try await session.authenticate(user: user, password: password)

    case .privateKey(let key):
      try await session.authenticate(user: user, key: key)
    }
  }

  public static func connect(
    host: String, port: UInt16 = 22, timeout: UInt = 60,
    user: String, auth: SSHAuthMethod = .none
  ) async throws(SSHError) -> SSHClient {
    let client = try await SSHClient(host: host, port: port, timeout: timeout)
    try await client.connect()
    try await client.authenticate(user: user, auth: auth)
    return client
  }

  @discardableResult
  public static func withAuthenticatedClient<T: Sendable>(
    host: String, port: UInt16 = 22, timeout: UInt = 60,
    user: String, auth: SSHAuthMethod = .none,
    perform body: @Sendable (SSHClient) async throws -> T
  ) async throws -> T {
    let client = try await connect(
      host: host, port: port, timeout: timeout, user: user, auth: auth
    )
    do {
      let result = try await body(client)
      await client.close()
      return result
    } catch {
      await client.close()
      throw error
    }
  }

  public var isConnected: Bool {
    get async {
      await session.isConnected
    }
  }

  func isConnectedOrThrow() async throws(SSHError) {
    if await !isConnected {
      throw SSHError.connectionFailed(message: "SSH session is closed")
    }
  }

  public func sftp() async throws(SSHError) -> SFTPClient {
    try await session.createSftp()
  }

  @discardableResult
  public func withSftp<T: Sendable>(
    perform body: @Sendable (SFTPClient) async throws -> T
  ) async throws -> T {
    try await session.withSftp(perform: body)
  }

  public func close() async {
    await session.disconnect()
    await session.free()
  }

  @discardableResult
  public func execute(_ command: String) async throws(SSHError) -> CommandResult {
    return try await execute(command) {
      channel throws(SSHError) in
      return try await CommandResult(
        status: channel.exitStatus(),
        stdout: channel.read(from: .stdout),
        stderr: channel.read(from: .stderr)
      )
    }
  }

  func execute<T: Sendable>(
    _ command: String,
    perform body: @Sendable (SSHSessionChannel) async throws(SSHError) -> T
  ) async throws(SSHError) -> T {
    try await isConnectedOrThrow()

    return try await session.withSessionChannel { channel throws(SSHError) in
      try await channel.execute(command: command)
      return try await body(channel)
    }
  }

  public func execute<T: Sendable>(
    _ command: String,
    perform body: @Sendable (SSHSessionChannel) async throws -> T
  ) async throws -> T {
    try await isConnectedOrThrow()

    return try await session.withSessionChannel { channel in
      try await channel.execute(command: command)
      return try await body(channel)
    }
  }
}
