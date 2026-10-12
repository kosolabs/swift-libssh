import Darwin
import Foundation
import Testing

@testable import SwiftLibSSH

private final class EphemeralLoopbackListener {
  let fd: Int32
  let port: UInt16

  init() throws {
    let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let rc = withUnsafeMutablePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, length) == 0 && listen(fd, 8) == 0 && getsockname(fd, $0, &length) == 0
      }
    }
    guard rc else {
      close(fd)
      throw POSIXError(.init(rawValue: errno)!)
    }
    self.fd = fd
    port = UInt16(bigEndian: addr.sin_port)
  }

  deinit {
    close(fd)
  }
}

private func availablePort() throws -> UInt16 {
  try EphemeralLoopbackListener().port
}

private func peerPort(_ fd: Int32) -> UInt16 {
  var addr = sockaddr_in()
  var length = socklen_t(MemoryLayout<sockaddr_in>.size)
  _ = withUnsafeMutablePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getpeername(fd, $0, &length) }
  }
  return UInt16(bigEndian: addr.sin_port)
}

struct SocketConnectorTests {
  @Test func resolveInterleavesAddressFamilies() throws {
    let v6 = try SocketConnector.resolve(host: "::1", port: 22)
    let v4 = try SocketConnector.resolve(host: "127.0.0.1", port: 22)

    let interleaved = SocketConnector.interleaved(v6 + v6 + v4)

    #expect(interleaved.map(\.family) == [AF_INET6, AF_INET, AF_INET6])
  }

  @Test func resolveUnknownHostFails() {
    #expect {
      try SocketConnector.resolve(host: "nonexistent.invalid", port: 22)
    } throws: { error in
      guard case .connectionFailed(let message) = error as? SSHError else { return false }
      return message.contains("Failed to resolve hostname")
    }
  }

  @Test func connectFallsBackWhenFirstAddressRefuses() throws {
    let listener = try EphemeralLoopbackListener()
    let refused = try SocketConnector.resolve(host: "127.0.0.1", port: availablePort())
    let open = try SocketConnector.resolve(host: "127.0.0.1", port: listener.port)

    let fd = try SocketConnector.connect(
      to: refused + open, host: "localhost", timeout: .seconds(5)
    )
    defer { close(fd) }

    #expect(peerPort(fd) == listener.port)
  }

  @Test func connectSkipsAddressThatDoesNotAnswer() throws {
    let listener = try EphemeralLoopbackListener()
    let silent = try SocketConnector.resolve(host: "192.0.2.1", port: 22)
    let open = try SocketConnector.resolve(host: "127.0.0.1", port: listener.port)

    let fd = try SocketConnector.connect(
      to: silent + open, host: "localhost", timeout: .seconds(5)
    )
    defer { close(fd) }

    #expect(peerPort(fd) == listener.port)
  }

  @Test func connectReportsRefusalWhenAllAddressesRefuse() throws {
    let refused = try SocketConnector.resolve(
      host: "127.0.0.1", port: availablePort())

    #expect(throws: SSHError.connectionFailed(message: "Failed to connect: Connection refused")) {
      try SocketConnector.connect(to: refused + refused, host: "localhost", timeout: .seconds(5))
    }
  }
}
