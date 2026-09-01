import Foundation

public struct SFTPDirectory: Sendable, AsyncSequence {
  private let session: SSHSession
  private let id: SFTPDirectoryID

  init(session: SSHSession, id: SFTPDirectoryID) {
    self.session = session
    self.id = id
  }

  func read() async throws(SSHError) -> SFTPAttributes? {
    while true {
      guard let attrs = try await session.readDirectory(id: id) else {
        return nil
      }

      if attrs.name == "" || attrs.name == "." || attrs.name == ".." {
        continue
      }
      return attrs
    }
  }

  public func makeAsyncIterator() -> Iterator {
    Iterator(directory: self)
  }

  public struct Iterator: AsyncIteratorProtocol {
    private let directory: SFTPDirectory

    init(directory: SFTPDirectory) {
      self.directory = directory
    }

    public func next() async throws(SSHError) -> SFTPAttributes? {
      try await directory.read()
    }
  }
}
