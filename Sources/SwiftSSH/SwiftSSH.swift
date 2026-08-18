import ArgumentParser
import Foundation
import SwiftLibSSH
import Synchronization

struct SSHConfig: ParsableArguments {
  @Option(name: .shortAndLong, help: "The user to log in as on the remote machine")
  var loginName: String = ProcessInfo.processInfo.userName

  @Option(name: .shortAndLong, help: "Identity file to use as the private key")
  var identityFile: String

  @Option(name: .shortAndLong, help: "The port to connect to on the remote host")
  var port: UInt16 = 22

  @Argument(help: "The remote host to connect to")
  var host: String

  func connect() async throws -> (ssh: SSHClient, sftp: SFTPClient) {
    let ssh = try await SSHClient.connect(
      host: host, port: port, user: loginName,
      auth: .privateKey(contentsOf: URL(fileURLWithPath: identityFile))
    )

    let sftp = try await ssh.sftp()

    return (ssh, sftp)
  }

  func withConnection<T>(_ body: (SSHClient, SFTPClient) async throws -> T) async throws -> T {
    let (ssh, sftp) = try await connect()
    do {
      let result = try await body(ssh, sftp)
      await sftp.close()
      await ssh.close()
      return result
    } catch {
      await sftp.close()
      await ssh.close()
      throw error
    }
  }
}

@main
struct SwiftSSH: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "SwiftLibSSH CLI test tool",
    subcommands: [Upload.self, Download.self]
  )
}

struct Upload: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Upload a file"
  )

  @OptionGroup var sshConfig: SSHConfig

  @Argument(help: "Local source file path")
  var src: String

  @Argument(help: "Remote destination file path")
  var dst: String

  @Option(help: "Permissions")
  var mode: mode_t = 0o644

  @Option(help: "Buffer size")
  var bufferSize: UInt64 = SFTPLimits.defaultBufferSize

  func run() async throws {
    try await sshConfig.withConnection { ssh, sftp in
      let fp = try FileHandle(forReadingFrom: URL(filePath: src))
      let speedometer = Speedometer(total: try fp.seekToEnd())
      try fp.seek(toOffset: 0)

      try await sftp.withSftpFile(at: dst, accessType: .writeOnly, mode: mode) { file in
        try await file.upload(from: URL(filePath: src), bufferSize: bufferSize) { completed in
          if let progress = speedometer.update(completed: Int(completed)) {
            print("Uploading from \(src) to \(dst): \(progress)")
          }
        }
      }
      print("Uploaded \(src) to \(dst): \(speedometer.finalize())")
    }
  }
}

struct Download: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Download a file"
  )

  @OptionGroup var sshConfig: SSHConfig

  @Argument(help: "Remote source file path")
  var src: String

  @Argument(help: "Local destination file path")
  var dst: String

  @Option(help: "Buffer size")
  var bufferSize: UInt64 = SFTPLimits.defaultBufferSize

  func run() async throws {
    try await sshConfig.withConnection { ssh, sftp in
      let attrs = try await sftp.attributes(at: src)
      let speedometer = Speedometer(total: attrs.size ?? 0)

      try await sftp.withSftpFile(at: src, accessType: .readOnly) { file in
        try await file.download(to: URL(filePath: dst), bufferSize: bufferSize) { completed in
          if let progress = speedometer.update(completed: Int(completed)) {
            print("Downloading from \(src) to \(dst): \(progress)")
          }
        }
      }
      print("Downloaded from \(src) to \(dst): \(speedometer.finalize())")
    }
  }
}
