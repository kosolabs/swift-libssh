import Foundation

struct SFTPAioReadContext: Sendable {
  private let session: SSHSession
  private let id: SFTPAioID
  private let length: Int

  init(session: SSHSession, id: SFTPAioID, length: Int) {
    self.session = session
    self.id = id
    self.length = length
  }

  func read(into buffer: inout Data) async throws(SSHError) -> Int {
    try await session.waitRead(id: id, into: &buffer, length: length)
  }
}

struct SFTPAioWriteContext: Sendable {
  private let session: SSHSession
  private let id: SFTPAioID
  let length: Int

  init(session: SSHSession, id: SFTPAioID, length: Int) {
    self.session = session
    self.id = id
    self.length = length
  }

  func flush() async throws(SSHError) {
    try await session.waitWrite(id: id)
  }
}
