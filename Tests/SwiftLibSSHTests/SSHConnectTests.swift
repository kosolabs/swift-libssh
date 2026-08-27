import CryptoKit
import Foundation
import Testing

@testable import SwiftLibSSH

private var host: String {
  let env = ProcessInfo.processInfo.environment
  return env["SWIFT_LIBSSH_TEST_HOST"] ?? "localhost"
}

private var port: UInt16 {
  let env = ProcessInfo.processInfo.environment
  if let portString = env["SWIFT_LIBSSH_TEST_PORT"], let port = UInt16(portString) {
    return port
  }
  return 2248
}

private var user: String {
  let env = ProcessInfo.processInfo.environment
  return env["SWIFT_LIBSSH_TEST_USER"] ?? NSUserName()
}

private var password: String? {
  let env = ProcessInfo.processInfo.environment
  return env["SWIFT_LIBSSH_TEST_PASSWORD"]
}

private let passwordComment: Comment =
  "Set SWIFT_LIBSSH_TEST_PASSWORD to the login password of the account running the test server."

private var privateKey: URL {
  let env = ProcessInfo.processInfo.environment
  return URL(fileURLWithPath: env["SWIFT_LIBSSH_TEST_PRIVATE_KEY_PATH"] ?? "Tests/Data/id_ed25519")
}

private var publicKey: URL {
  let env = ProcessInfo.processInfo.environment
  return URL(
    fileURLWithPath: env["SWIFT_LIBSSH_TEST_PUBLIC_KEY_PATH"] ?? "Tests/Data/id_ed25519.pub"
  )
}

private var encryptedPrivateKey: URL {
  let env = ProcessInfo.processInfo.environment
  return URL(
    fileURLWithPath: env["SWIFT_LIBSSH_TEST_ENCRYPTED_PRIVATE_KEY_PATH"]
      ?? "Tests/Data/id_ed25519_encrypted"
  )
}

private let encryptedPassphrase = "hunter2"

func client() async throws -> SSHClient {
  return try await SSHClient.connect(
    host: host, port: port, user: user, auth: .privateKey(contentsOf: privateKey))
}

@discardableResult
func withAuthenticatedClient<T: Sendable>(
  perform body: @Sendable (SSHClient) async throws -> T
) async throws -> T {
  let client = try await client()
  do {
    let result = try await body(client)
    await client.close()
    return result
  } catch {
    await client.close()
    throw error
  }
}

struct SSHConnectTests {
  @Test(.enabled(if: password != nil, passwordComment))
  func passwordAuthenticationSucceeds() async throws {
    try await SSHClient.withAuthenticatedClient(
      host: host, port: port, user: user, auth: .password(#require(password))
    ) { ssh in
      let proc = try await ssh.execute("whoami")
      let actual = try proc.stdout
        .decoded(as: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      let expected = user
      #expect(actual == expected)
      #expect(proc.status.code == 0)
    }
  }

  @Test func privateKeyFileAuthenticationSucceeds() async throws {
    try await SSHClient.withAuthenticatedClient(
      host: host, port: port, user: user, auth: .privateKey(contentsOf: privateKey)
    ) { ssh in

      let proc = try await ssh.execute("whoami")
      let actual = try proc.stdout
        .decoded(as: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      let expected = user
      #expect(actual == expected)
      #expect(proc.status.code == 0)
    }
  }

  @Test func base64PrivateKeyAuthenticationSucceeds() async throws {
    let privateKey = try String(contentsOf: privateKey, encoding: .utf8)
    try await SSHClient.withAuthenticatedClient(
      host: host, port: port, user: user, auth: .privateKey(contents: privateKey)
    ) { ssh in

      let proc = try await ssh.execute("whoami")
      let actual = try proc.stdout
        .decoded(as: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      let expected = user
      #expect(actual == expected)
      #expect(proc.status.code == 0)
    }
  }

  @Test func importedPrivateKeyAuthenticationSucceeds() async throws {
    let key = try SSHPrivateKey(contentsOf: privateKey)
    try await SSHClient.withAuthenticatedClient(
      host: host, port: port, user: user, auth: .privateKey(key)
    ) { ssh in
      let proc = try await ssh.execute("whoami")
      let actual = try proc.stdout
        .decoded(as: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      let expected = user
      #expect(actual == expected)
      #expect(proc.status.code == 0)
    }
  }

  @Test func importedPrivateKeyIsReusableAcrossConnections() async throws {
    let key = try SSHPrivateKey(contentsOf: privateKey)
    for _ in 0..<3 {
      try await SSHClient.withAuthenticatedClient(
        host: host, port: port, user: user, auth: .privateKey(key)
      ) { ssh in
        let proc = try await ssh.execute("true")
        #expect(proc.status.code == 0)
      }
    }
  }

  @Test func encryptedPrivateKeyAuthenticationSucceeds() async throws {
    try await SSHClient.withAuthenticatedClient(
      host: host, port: port, user: user,
      auth: .privateKey(contentsOf: encryptedPrivateKey, passphrase: encryptedPassphrase)
    ) { ssh in
      let proc = try await ssh.execute("whoami")
      let actual = try proc.stdout
        .decoded(as: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      let expected = user
      #expect(actual == expected)
      #expect(proc.status.code == 0)
    }
  }

  @Test func noPasswordThrowsAuthenticationFailed() async throws {
    await #expect {
      try await SSHClient.connect(host: host, port: port, user: user)
    } throws: { error in
      (error as? SSHError)?.isAuthenticationFailed == true
    }
  }

  @Test func badPasswordThrowsAuthenticationFailed() async throws {
    await #expect {
      try await SSHClient.connect(host: host, port: port, user: user, auth: .password("bad"))
    } throws: { error in
      (error as? SSHError)?.isAuthenticationFailed == true
    }
  }

  @Test func missingPrivateKeyThrowsUnreadable() async throws {
    await #expect {
      try await SSHClient.connect(
        host: host, port: port, user: user,
        auth: .privateKey(contentsOf: URL(filePath: "/tmp/missing_pk")))
    } throws: { error in
      (error as? SSHError)?.keyError == .unreadable
    }
  }

  @Test func invalidPrivateKeyThrowsInvalid() async throws {
    await #expect {
      try await SSHClient.connect(
        host: host, port: port, user: user, auth: .privateKey(contentsOf: publicKey))
    } throws: { error in
      (error as? SSHError)?.keyError == .invalid
    }
  }

  @Test func invalidKeyContentsThrowsInvalid() async throws {
    await #expect {
      try await SSHClient.connect(
        host: host, port: port, user: user, auth: .privateKey(contents: ""))
    } throws: { error in
      (error as? SSHError)?.keyError == .invalid
    }
  }

  @Test func encryptedPrivateKeyWithoutPassphraseThrowsPassphraseRequired() async throws {
    await #expect {
      try await SSHClient.connect(
        host: host, port: port, user: user,
        auth: .privateKey(contentsOf: encryptedPrivateKey))
    } throws: { error in
      (error as? SSHError)?.keyError == .passphraseRequired
    }
  }

  @Test func invalidHostThrowsConnectionFailed() async throws {
    await #expect {
      try await SSHClient.connect(host: "invalid", user: user)
    } throws: { error in
      (error as? SSHError)?.isConnectionFailed == true
    }
  }

  @Test func invalidPortThrowsConnectionFailed() async throws {
    await #expect {
      try await SSHClient.connect(host: host, port: 2200, user: user)
    } throws: { error in
      (error as? SSHError)?.isConnectionFailed == true
    }
  }

  @Test func timeoutThrowsConnectionFailed() async throws {
    await #expect {
      try await SSHClient.connect(host: "192.0.2.1", timeout: 1, user: user)
    } throws: { error in
      (error as? SSHError)?.isConnectionFailed == true
    }
  }
}
