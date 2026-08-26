import Foundation

public class SFTPReader: AsyncSequence {
  private let file: SFTPFile
  private let offset: UInt64
  private let length: UInt64
  private let bufferSize: UInt64

  init(file: SFTPFile, offset: UInt64, length: UInt64, bufferSize: UInt64) {
    self.file = file
    self.offset = offset
    self.length = length
    self.bufferSize = bufferSize
  }

  public func makeAsyncIterator() -> Iterator {
    Iterator(file: file, offset: offset, length: length, bufferSize: bufferSize)
  }

  public class Iterator: AsyncIteratorProtocol {
    static let QueueSize: Int = 16

    private let file: SFTPFile
    private let offset: UInt64
    private let length: UInt64
    private let bufferSize: UInt64

    private var count: UInt64 = 0
    private lazy var buffer: Data = Data(count: Int(bufferSize))
    private var queue: [SFTPAioReadContext] = []

    init(file: SFTPFile, offset: UInt64, length: UInt64, bufferSize: UInt64) {
      self.file = file
      self.offset = offset
      self.length = length
      self.bufferSize = bufferSize
    }

    public func next() async throws(SSHError) -> Data? {
      if Task.isCancelled {
        return nil
      }

      if count == 0 {
        try await file.seek(offset: offset)
      }

      while queue.count < Iterator.QueueSize && count < length {
        let size = Swift.min(bufferSize, length - count)
        guard let aio = try await file.beginRead(length: Int(size)) else {
          if !queue.isEmpty { break }
          await Task.yield()
          continue
        }
        count += size
        queue.append(aio)
      }

      if queue.isEmpty {
        return nil
      }

      let aio = queue.removeFirst()
      let bytesRead = try await aio.read(into: &buffer)
      return bytesRead == 0 ? nil : buffer.prefix(bytesRead)
    }
  }
}

public class SFTPWriter {
  static let QueueSize: Int = 16

  private let file: SFTPFile
  private var queue: [SFTPAioWriteContext] = []

  init(file: SFTPFile) {
    self.file = file
  }

  public func write(data: Data) async throws(SSHError) {
    var remaining = data[...]
    while !remaining.isEmpty {
      guard queue.count < Self.QueueSize,
        let aio = try await file.beginWrite(data: remaining)
      else {
        if queue.isEmpty {
          await Task.yield()
        } else {
          try await queue.removeFirst().flush()
        }
        continue
      }
      remaining = remaining.dropFirst(aio.length)
      queue.append(aio)
    }
  }

  public func flush() async throws(SSHError) {
    while !queue.isEmpty {
      try await queue.removeFirst().flush()
    }
  }
}

public struct SFTPFile: Sendable {
  private let session: SSHSession
  private let id: SFTPFileID
  private let limits: SFTPLimits

  init(session: SSHSession, id: SFTPFileID, limits: SFTPLimits) {
    self.session = session
    self.id = id
    self.limits = limits
  }

  public func close() async {
    await session.closeFile(id: id)
  }

  public func attributes() async throws(SSHError) -> SFTPAttributes {
    try await session.statFile(id: id)
  }

  func seek(offset: UInt64) async throws(SSHError) {
    try await session.seekFile(id: id, offset: offset)
  }

  public func read(
    range: Range<UInt64>,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize
  ) async throws(SSHError) -> Data {
    try await read(
      offset: range.lowerBound, length: range.upperBound - range.lowerBound,
      bufferSize: bufferSize
    )
  }

  public func read(
    offset: UInt64 = 0, length: UInt64 = UInt64.max,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize
  ) async throws(SSHError) -> Data {
    let bufferSize = limits.readLength(for: bufferSize)
    try await seek(offset: offset)
    var result = Data()
    var buffer = Data(count: Int(bufferSize))
    while result.count < length {
      let bytesToRead = Int(min(bufferSize, length - UInt64(result.count)))
      let bytesRead = try await session.readFile(id: id, into: &buffer, length: bytesToRead)
      guard bytesRead > 0 else { break }
      result.append(buffer.prefix(bytesRead))
    }
    return result
  }

  public func write(
    data: Data, bufferSize: UInt64 = SFTPLimits.defaultBufferSize
  ) async throws(SSHError) {
    let bufferSize = Int(limits.writeLength(for: bufferSize))
    for curr in stride(from: 0, to: data.count, by: bufferSize) {
      let next = min(data.count, curr + bufferSize)
      let buffer = data.subdata(in: curr..<next)
      let bytesWritten = try await session.writeFile(id: id, data: buffer)
      if bytesWritten != buffer.count {
        throw SSHError.invalidState(
          message:
            "Failed to write all data to file: \(bytesWritten) of \(buffer.count) bytes written")
      }
    }
  }

  func beginRead(length: Int) async throws(SSHError) -> SFTPAioReadContext? {
    try await session.beginRead(id: id, length: length)
  }

  public func stream(
    range: Range<UInt64>,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize
  ) -> SFTPReader {
    let bufferSize = limits.readLength(for: bufferSize)
    return SFTPReader(
      file: self,
      offset: range.lowerBound, length: range.upperBound - range.lowerBound,
      bufferSize: bufferSize
    )
  }

  public func stream(
    offset: UInt64 = 0, length: UInt64 = UInt64.max,
    bufferSize: UInt64 = SFTPLimits.defaultBufferSize
  ) -> SFTPReader {
    let bufferSize = limits.readLength(for: bufferSize)
    return SFTPReader(file: self, offset: offset, length: length, bufferSize: bufferSize)
  }

  func beginWrite(data: Data) async throws(SSHError) -> SFTPAioWriteContext? {
    try await session.beginWrite(id: id, buffer: data)
  }

  public func withAsyncWriter(
    perform body: (SFTPWriter) async throws -> Void
  ) async throws {
    let writer = SFTPWriter(file: self)
    try await body(writer)
    try await writer.flush()
  }

  public func download(
    to localURL: URL, bufferSize: UInt64 = SFTPLimits.defaultBufferSize,
    progress: (@Sendable (UInt64) -> Void)? = nil
  ) async throws {
    let bufferSize = limits.readLength(for: bufferSize)
    if !FileManager.default.createFile(atPath: localURL.path, contents: nil) {
      throw SSHError.invalidState(message: "Failed to create local file at \(localURL)")
    }

    guard let fp = try? FileHandle(forWritingTo: localURL) else {
      throw SSHError.invalidState(message: "Failed to open local file for writing at \(localURL)")
    }
    defer { try? fp.close() }

    var count: UInt64 = 0
    for try await data in stream(bufferSize: bufferSize) {
      try fp.write(contentsOf: data)
      count += UInt64(data.count)
      progress?(count)
    }
  }

  public func upload(
    from localURL: URL, bufferSize: UInt64 = SFTPLimits.defaultBufferSize,
    progress: (@Sendable (UInt64) -> Void)? = nil
  ) async throws {
    let bufferSize = Int(limits.writeLength(for: bufferSize))
    guard let fp = try? FileHandle(forReadingFrom: localURL) else {
      throw SSHError.invalidState(message: "Failed to open local file for reading at \(localURL)")
    }
    defer { try? fp.close() }

    var count: UInt64 = 0
    try await withAsyncWriter { writer in
      while let data = try fp.read(upToCount: bufferSize) {
        try await writer.write(data: data)
        count += UInt64(data.count)
        progress?(count)
      }
    }
  }
}
