import CLibSSH
import CryptoKit
import Foundation

public struct SSHHostKey: Codable, Sendable, Hashable, LosslessStringConvertible {
  public let type: String
  public let blob: Data

  public init(type: String, blob: Data) {
    self.type = type
    self.blob = blob
  }

  public init?(_ description: String) {
    let fields = description.split(separator: " ", omittingEmptySubsequences: true)
    guard fields.count >= 2, let blob = Data(base64Encoded: String(fields[1])) else {
      return nil
    }
    self.init(type: String(fields[0]), blob: blob)
  }

  public var description: String {
    "\(type) \(blob.base64EncodedString())"
  }

  public var fingerprint: String {
    let digest = Data(SHA256.hash(data: blob)).base64EncodedString()
    return "SHA256:\(digest.trimmingCharacters(in: ["="]))"
  }

  static func from(raw key: ssh_key) throws(SSHError) -> SSHHostKey {
    guard let type = ssh_key_type_to_char(ssh_key_type(key)) else {
      throw .invalidState(message: "Server host key has an unknown type")
    }
    var base64: UnsafeMutablePointer<CChar>?
    guard ssh_pki_export_pubkey_base64(key, &base64) == SSH_OK, let base64 else {
      throw .invalidState(message: "Failed to export server host key")
    }
    defer { ssh_string_free_char(base64) }
    guard let blob = Data(base64Encoded: String(cString: base64)) else {
      throw .invalidState(message: "Server host key is not valid base64")
    }
    return SSHHostKey(type: String(cString: type), blob: blob)
  }
}
