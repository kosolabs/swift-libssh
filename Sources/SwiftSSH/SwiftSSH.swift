import ArgumentParser
import Foundation
import SwiftLibSSH

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
    subcommands: [Upload.self, Download.self, Stress.self]
  )
}
