import Foundation
import Synchronization
import Testing

@testable import SwiftLibSSH

private final class Latch: Sendable {
  private let state = Mutex(false)

  var isSet: Bool {
    state.withLock { $0 }
  }

  func signal() {
    state.withLock { $0 = true }
  }
}

private struct WedgedError: Error, CustomStringConvertible {
  let seconds: Double
  var description: String {
    "SFTP session made no progress for \(seconds)s"
  }
}

private func withWatchdog(
  seconds: Double, _ body: @escaping @Sendable () async throws -> Void
) async throws {
  let latch = Latch()
  let task = Task {
    defer { latch.signal() }
    try await body()
  }

  let deadline = Date().addingTimeInterval(seconds)
  while !latch.isSet && Date() < deadline {
    try? await Task.sleep(for: .milliseconds(50))
  }

  guard latch.isSet else {
    throw WedgedError(seconds: seconds)
  }
  try await task.value
}

struct SFTPConcurrencyTests {
  @Test func cancellationOfForAwaitLoopOverSftpStreamSucceeds() async throws {
    try await withAuthenticatedClient { ssh in
      try await ssh.execute("dd if=/dev/urandom of=/tmp/drain.dat bs=1M count=1")

      let expected = try await ssh.withSftp { sftp in
        try await sftp.attributes(at: "/tmp/drain.dat").size!
      }

      let actual = try await ssh.withSftp { sftp in
        try await sftp.withSftpFile(at: "/tmp/drain.dat", accessType: .readOnly) { file in
          for try await chunk in file.stream() {
            // Returning here causes stream to cancel
            return chunk
          }
          fatalError("Stream should not complete")
        }
      }

      #expect(actual.count > 0)
      #expect(actual.count < expected)
    }
  }
}
