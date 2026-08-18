import CLibSSH
import Foundation
import Synchronization

public enum SSHKeyType: Sendable, Equatable {
  case dss
  case rsa
  case ecdsaP256
  case ecdsaP384
  case ecdsaP521
  case ed25519
  case securityKeyEcdsa
  case securityKeyEd25519
  case other(name: String)

  static func from(raw: ssh_keytypes_e) -> SSHKeyType {
    switch raw {
    case SSH_KEYTYPE_DSS: return .dss
    case SSH_KEYTYPE_RSA: return .rsa
    case SSH_KEYTYPE_ECDSA_P256: return .ecdsaP256
    case SSH_KEYTYPE_ECDSA_P384: return .ecdsaP384
    case SSH_KEYTYPE_ECDSA_P521: return .ecdsaP521
    case SSH_KEYTYPE_ED25519: return .ed25519
    case SSH_KEYTYPE_SK_ECDSA: return .securityKeyEcdsa
    case SSH_KEYTYPE_SK_ED25519: return .securityKeyEd25519
    default:
      guard let name = ssh_key_type_to_char(raw) else { return .other(name: "unknown") }
      return .other(name: String(cString: name))
    }
  }
}

public final class SSHPrivateKey: Sendable {
  private let key: Mutex<ssh_key>

  public convenience init(contentsOf file: URL, passphrase: String? = nil) throws(SSHError) {
    try self.init(source: "file \(file.path)") { userdata, key in
      ssh_pki_import_privkey_file(file.path, passphrase, recordPassphraseRequest, userdata, &key)
    }
  }

  public convenience init(contents: String, passphrase: String? = nil) throws(SSHError) {
    try self.init(source: "data") { userdata, key in
      ssh_pki_import_privkey_base64(contents, passphrase, recordPassphraseRequest, userdata, &key)
    }
  }

  private init(
    source: String,
    importing: (UnsafeMutableRawPointer, inout ssh_key?) -> Int32
  ) throws(SSHError) {
    let flag = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
    flag.initialize(to: false)
    var key: ssh_key?
    let code = importing(UnsafeMutableRawPointer(flag), &key)
    let passphraseRequested = flag.pointee
    flag.deallocate()

    guard code == SSH_OK, let imported = key else {
      let reason: SSHKeyError
      if code == SSH_EOF {
        reason = .unreadable
      } else if passphraseRequested {
        reason = .passphraseRequired
      } else {
        reason = .invalid
      }
      throw SSHError.keyError(reason, message: reason.message(source: source))
    }

    self.key = Mutex(imported)
  }

  public var keyType: SSHKeyType {
    key.withLock { SSHKeyType.from(raw: ssh_key_type($0)) }
  }

  func withKey<T: Sendable>(
    _ body: (ssh_key) throws(SSHError) -> T
  ) throws(SSHError) -> T {
    try key.withLock { key throws(SSHError) in try body(key) }
  }

  deinit {
    key.withLock { ssh_key_free($0) }
  }
}

private let recordPassphraseRequest: ssh_auth_callback = { _, _, _, _, _, userdata in
  userdata?.assumingMemoryBound(to: Bool.self).pointee = true
  return SSH_ERROR
}

extension SSHKeyError {
  fileprivate func message(source: String) -> String {
    switch self {
    case .unreadable:
      "Failed to read private key from \(source)"
    case .passphraseRequired:
      "Private key from \(source) is encrypted and requires a passphrase"
    case .invalid:
      "Failed to import private key from \(source)"
    }
  }
}
