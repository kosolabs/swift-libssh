import Darwin

/// Opens a TCP connection to the first reachable address of a host.
///
/// libssh starts a non-blocking `connect()` to the first resolved address and
/// commits to it; if that attempt is later refused or times out, it never tries
/// the remaining addresses. Hosts that resolve to several addresses (dual-stack
/// hosts, mDNS `.local` names) then fail whenever the first address doesn't
/// accept connections, e.g. an IPv6 address when sshd only listens on IPv4.
///
/// This races the addresses Happy Eyeballs style (RFC 8305): attempts start
/// in turn, 250ms apart or as soon as the previous one fails, and the first
/// to connect wins. The resulting socket is handed to libssh.
enum SocketConnector {
  struct Address {
    let family: Int32
    let storage: sockaddr_storage
    let length: socklen_t

    var bytes: [UInt8] {
      withUnsafeBytes(of: storage) { Array($0.prefix(Int(length))) }
    }
  }

  static let attemptDelay: Duration = .milliseconds(250)

  /// Resolves `host` and returns its addresses with address families
  /// interleaved, so that one unreachable family can't hold up the other.
  static func resolve(host: String, port: UInt16) throws(SSHError) -> [Address] {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_STREAM
    hints.ai_protocol = IPPROTO_TCP
    hints.ai_flags = AI_NUMERICSERV

    var result: UnsafeMutablePointer<addrinfo>?
    let rc = getaddrinfo(host, String(port), &hints, &result)
    guard rc == 0, let result else {
      throw .connectionFailed(
        message: "Failed to resolve hostname \(host): \(String(cString: gai_strerror(rc)))")
    }
    defer { freeaddrinfo(result) }

    var addresses: [Address] = []
    var seen: Set<[UInt8]> = []
    for info in sequence(first: result, next: { $0.pointee.ai_next }) {
      guard let addr = info.pointee.ai_addr else { continue }
      var storage = sockaddr_storage()
      let length = min(info.pointee.ai_addrlen, socklen_t(MemoryLayout<sockaddr_storage>.size))
      withUnsafeMutableBytes(of: &storage) {
        $0.copyMemory(from: UnsafeRawBufferPointer(start: addr, count: Int(length)))
      }
      let address = Address(family: info.pointee.ai_family, storage: storage, length: length)
      if seen.insert(address.bytes).inserted {
        addresses.append(address)
      }
    }

    guard !addresses.isEmpty else {
      throw .connectionFailed(message: "Failed to resolve hostname \(host): No addresses")
    }
    return interleaved(addresses)
  }

  static func interleaved(_ addresses: [Address]) -> [Address] {
    guard let first = addresses.first else { return [] }
    let preferred = addresses.filter { $0.family == first.family }
    let others = addresses.filter { $0.family != first.family }
    var result: [Address] = []
    for i in 0..<max(preferred.count, others.count) {
      if i < preferred.count { result.append(preferred[i]) }
      if i < others.count { result.append(others[i]) }
    }
    return result
  }

  /// Connects to the first reachable address and returns the connected,
  /// non-blocking socket. The caller owns the returned descriptor.
  static func connect(
    to addresses: [Address], host: String, timeout: Duration
  ) throws(SSHError) -> Int32 {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    var nextAttempt = clock.now
    var remaining = addresses[...]
    var pending: [Int32] = []
    var lastError: Int32 = 0

    func closePending() {
      for fd in pending { Darwin.close(fd) }
      pending.removeAll()
    }

    while true {
      let now = clock.now
      if now >= deadline {
        closePending()
        throw .connectionFailed(message: "Timeout connecting to \(host)")
      }

      if let address = remaining.first, pending.isEmpty || now >= nextAttempt {
        remaining.removeFirst()
        nextAttempt = now + attemptDelay
        switch start(address) {
        case .success(let fd, connected: true):
          closePending()
          return fd
        case .success(let fd, connected: false):
          pending.append(fd)
        case .failure(let error):
          lastError = error
          nextAttempt = now
        }
        continue
      }

      if pending.isEmpty {
        throw .connectionFailed(
          message: "Failed to connect: \(String(cString: strerror(lastError)))")
      }

      let wake = remaining.isEmpty ? deadline : min(deadline, nextAttempt)
      var fds = pending.map { pollfd(fd: $0, events: Int16(POLLOUT), revents: 0) }
      let rc = poll(&fds, nfds_t(fds.count), milliseconds(until: wake, from: now))
      if rc < 0 {
        if errno == EINTR { continue }
        let error = errno
        closePending()
        throw .connectionFailed(message: "Failed to connect: \(String(cString: strerror(error)))")
      }

      for pfd in fds where pfd.revents != 0 {
        pending.removeAll { $0 == pfd.fd }
        let error = socketError(pfd.fd)
        if error == 0 {
          closePending()
          return pfd.fd
        }
        Darwin.close(pfd.fd)
        lastError = error
        nextAttempt = clock.now
      }
    }
  }

  private enum Attempt {
    case success(Int32, connected: Bool)
    case failure(Int32)
  }

  private static func start(_ address: Address) -> Attempt {
    let fd = socket(address.family, SOCK_STREAM, IPPROTO_TCP)
    guard fd >= 0 else { return .failure(errno) }

    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
      let error = errno
      Darwin.close(fd)
      return .failure(error)
    }

    var storage = address.storage
    let rc = withUnsafePointer(to: &storage) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, address.length)
      }
    }
    if rc == 0 {
      return .success(fd, connected: true)
    }
    let error = errno
    if error == EINPROGRESS || error == EINTR {
      return .success(fd, connected: false)
    }
    Darwin.close(fd)
    return .failure(error)
  }

  private static func socketError(_ fd: Int32) -> Int32 {
    var error: Int32 = 0
    var length = socklen_t(MemoryLayout<Int32>.size)
    guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 else { return errno }
    return error
  }

  private static func milliseconds(
    until instant: ContinuousClock.Instant, from now: ContinuousClock.Instant
  ) -> Int32 {
    let (seconds, attoseconds) = (instant - now).components
    let millis = seconds * 1000 + (attoseconds + 999_999_999_999_999) / 1_000_000_000_000_000
    return Int32(clamping: max(0, millis))
  }
}
