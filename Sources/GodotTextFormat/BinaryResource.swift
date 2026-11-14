import ZstdDecoder

/// Godot's binary resource format (`.res`, and `.scn` for a scene), as
/// `core/io/resource_format_binary.cpp` writes it at 4.7: a header with the class of the
/// resource the file holds, a string table, the external resources it refers to, and its
/// internal resources, the last of which is the file's own. Godot's editor saves the whole of
/// that compressed, in blocks (`core/io/file_access_compressed.cpp`), unless its
/// `filesystem/on_save/compress_binary_resources` setting is off; `ResourceSaver.save` from a
/// script doesn't unless asked.

/// Why a binary resource file couldn't be read.
public enum BinaryResourceError: Error, Equatable, CustomStringConvertible {
    /// The file doesn't start as a binary resource does.
    case notBinaryResource
    /// The file is compressed by a method other than Zstandard, Godot's default (its number
    /// in Godot's `Compression.Mode`).
    case unsupportedCompression(Int)
    /// The file's compressed data doesn't decompress.
    case badCompressedData
    /// The file was saved on a big-endian machine.
    case bigEndian
    /// The file's format version is newer than the one read here.
    case newerFormat(Int)
    /// The file, or the part of it given, ends before what it says it holds.
    case truncated
    /// A value of a kind this format version doesn't have.
    case unknownValueKind(Int)

    public var description: String {
        switch self {
        case .notBinaryResource: return "not a binary resource file"
        case .unsupportedCompression(let mode): return "a binary resource file compressed by method \(mode), not Zstandard"
        case .badCompressedData: return "a binary resource file whose compressed data doesn't decompress"
        case .bigEndian: return "a big-endian binary resource file"
        case .newerFormat(let version): return "binary resource format \(version), newer than format \(binaryFormatVersion)"
        case .truncated: return "a binary resource file that ends early"
        case .unknownValueKind(let kind): return "a binary resource file with a value of unknown kind \(kind)"
        }
    }
}

/// The newest binary format version read here, Godot 4.7's.
let binaryFormatVersion = 6

extension ResourceFile {
    /// The class of the resource a binary resource file holds (`ArrayMesh`, `AnimationLibrary`,
    /// `PackedScene`, …), from its header. `bytes` are the file or the start of it: the first
    /// 64 KB hold the header of any file under some 50 MB, and a start too short for its file
    /// throws `truncated`.
    public static func type(ofBinary bytes: [UInt8]) throws -> String {
        let (stream, headerAt) = try binaryStream(of: bytes, upTo: 1024)
        var reader = BinaryReader(bytes: stream, offset: headerAt)
        return try StreamHeader(&reader).type
    }

    /// Reads a binary resource file into the shape a text one has: its class, the external
    /// resources it refers to, its sub-resources and its own properties, with values as the
    /// text format would spell them. An external resource's `id` is its index in the file,
    /// which is all a binary file keeps. `format` is the binary format's version.
    public static func parse(binary bytes: [UInt8]) throws -> ResourceFile {
        let (stream, headerAt) = try binaryStream(of: bytes, upTo: nil)
        return try parse(binaryStream: stream, headerAt: headerAt)
    }

    /// The stream a binary resource file holds and where its header starts: the file itself,
    /// after its four-byte mark, or the data inside a compressed file, decompressed as far as
    /// `limit` bytes need (all of it for nil).
    static func binaryStream(of bytes: [UInt8], upTo limit: Int?) throws -> ([UInt8], headerAt: Int) {
        guard bytes.count >= 4 else { throw BinaryResourceError.notBinaryResource }
        if bytes[0..<4].elementsEqual("RSRC".utf8) { return (bytes, 4) }
        guard bytes[0..<4].elementsEqual("RSCC".utf8) else { throw BinaryResourceError.notBinaryResource }
        return (try decompressedBlocks(of: bytes, upTo: limit), 0)
    }

    /// Reads the stream a binary resource file holds: the whole of an uncompressed file, whose
    /// header follows its four-byte mark, or the data inside a compressed one, which starts
    /// at the header. Offsets in the stream count from its first byte.
    static func parse(binaryStream bytes: [UInt8], headerAt offset: Int) throws -> ResourceFile {
        var reader = BinaryReader(bytes: bytes, offset: offset)
        let header = try StreamHeader(&reader)
        reader.realIsDouble = header.realIsDouble

        var strings: [String] = []
        for _ in 0..<(try reader.count()) { strings.append(try reader.string()) }

        var external: [ExtResourceEntry] = []
        for index in 0..<(try reader.count()) {
            let type = try reader.string()
            let path = try reader.string()
            let uid = header.hasUIDs ? uidText(try reader.u64()) : nil
            external.append(ExtResourceEntry(id: String(index), type: type, path: path, uid: uid))
        }

        var places: [(id: String, offset: Int)] = []
        for index in 0..<(try reader.count()) {
            let path = try reader.string()
            let offset = try reader.u64()
            guard offset <= UInt64(bytes.count) else { throw BinaryResourceError.truncated }
            let id = header.hasNamedIDs && path.hasPrefix("local://") ? String(path.dropFirst("local://".count)) : String(index)
            places.append((id, Int(offset)))
        }

        var values = BinaryValueReader(reader: reader, strings: strings, internalIDs: places.map(\.id), format: header.format)
        var resources: [SubResourceEntry] = []
        for place in places {
            values.reader.offset = place.offset
            let type = try values.reader.string()
            var body: [(String, Value)] = []
            for _ in 0..<(try values.reader.count()) {
                let name = try values.name()
                body.append((name, try values.value()))
            }
            resources.append(SubResourceEntry(id: place.id, type: type, body: body))
        }
        let own = resources.popLast()
        let nowhere = SourceLocation(line: 0, column: 0)
        return ResourceFile(
            format: header.format,
            type: header.type,
            scriptClass: header.scriptClass,
            uid: header.uid,
            extResources: external,
            subResources: resources,
            resource: own.map { Section(kind: "resource", attrs: [], body: $0.body, headerRange: SourceRange(start: nowhere, end: nowhere)) }
        )
    }
}

/// The data inside a file Godot wrote compressed: after the four-byte mark, the compression
/// method, the block size, the data's length, each block's compressed length, then the blocks,
/// each a Zstandard frame of its own. Decompresses the blocks that hold the first `limit`
/// bytes, or all of them.
func decompressedBlocks(of bytes: [UInt8], upTo limit: Int?) throws -> [UInt8] {
    var reader = BinaryReader(bytes: bytes, offset: 4)
    let method = Int(try reader.u32())
    guard method == 2 else { throw BinaryResourceError.unsupportedCompression(method) }
    let blockSize = Int(try reader.u32())
    let total = Int(try reader.u32())
    guard blockSize > 0 else { throw BinaryResourceError.badCompressedData }
    let blockCount = total / blockSize + 1
    guard blockCount <= (bytes.count - reader.offset) / 4 else { throw BinaryResourceError.truncated }
    var compressedSizes: [Int] = []
    compressedSizes.reserveCapacity(blockCount)
    for _ in 0..<blockCount { compressedSizes.append(Int(try reader.u32())) }

    let wanted = min(limit ?? total, total)
    var stream: [UInt8] = []
    stream.reserveCapacity(wanted)
    var block = [UInt8](repeating: 0, count: blockSize)
    for (index, compressedSize) in compressedSizes.enumerated() where stream.count < wanted {
        let size = index == blockCount - 1 ? total % blockSize : blockSize
        let compressed = try reader.take(compressedSize)
        guard size > 0 else { continue }
        let written = compressed.withUnsafeBytes { source in
            block.withUnsafeMutableBytes { ZSTD_decompress($0.baseAddress, size, source.baseAddress, source.count) }
        }
        guard ZSTD_isError(written) == 0, written == size else { throw BinaryResourceError.badCompressedData }
        stream.append(contentsOf: block[0..<size])
    }
    return stream
}

/// The `uid://` text of a resource id, as `ResourceUID::id_to_text` writes it; nil for the
/// id that means none.
func uidText(_ id: UInt64) -> String? {
    guard id <= UInt64(Int64.max) else { return nil }
    let characters = Array("abcdefghijklmnopqrstuvwxy012345678".utf8)
    var digits: [UInt8] = []
    var rest = id
    repeat {
        digits.append(characters[Int(rest % UInt64(characters.count))])
        rest /= UInt64(characters.count)
    } while rest != 0
    return "uid://" + String(decoding: digits.reversed(), as: UTF8.self)
}

/// The header of the stream: everything before the string table.
private struct StreamHeader {
    let format: Int
    let type: String
    let uid: String?
    let scriptClass: String?
    let hasNamedIDs: Bool
    let hasUIDs: Bool
    let realIsDouble: Bool

    init(_ reader: inout BinaryReader) throws {
        guard try reader.u32() == 0 else { throw BinaryResourceError.bigEndian }
        _ = try reader.u32() // whether the saving build's reals were doubles; the flags below say what the file holds
        _ = try reader.u32() // engine major
        _ = try reader.u32() // engine minor
        format = Int(try reader.u32())
        guard format <= binaryFormatVersion else { throw BinaryResourceError.newerFormat(format) }
        type = try reader.string()
        _ = try reader.u64() // import metadata offset, unused
        let flags = try reader.u32()
        hasNamedIDs = flags & 1 != 0
        hasUIDs = flags & 2 != 0
        realIsDouble = flags & 4 != 0
        let id = try reader.u64()
        uid = hasUIDs ? uidText(id) : nil
        scriptClass = flags & 8 != 0 ? try reader.string() : nil
        for _ in 0..<11 { _ = try reader.u32() } // reserved
    }
}

/// Little-endian reads from a file's bytes.
struct BinaryReader {
    let bytes: [UInt8]
    var offset: Int
    var realIsDouble = false

    init(bytes: [UInt8], offset: Int) {
        self.bytes = bytes
        self.offset = offset
    }

    mutating func take(_ count: Int) throws -> ArraySlice<UInt8> {
        guard count >= 0, offset >= 0, offset <= bytes.count - count else { throw BinaryResourceError.truncated }
        defer { offset += count }
        return bytes[offset..<offset + count]
    }

    mutating func u16() throws -> UInt16 {
        try take(2).reversed().reduce(0) { $0 << 8 | UInt16($1) }
    }

    mutating func u32() throws -> UInt32 {
        try take(4).reversed().reduce(0) { $0 << 8 | UInt32($1) }
    }

    mutating func u64() throws -> UInt64 {
        try take(8).reversed().reduce(0) { $0 << 8 | UInt64($1) }
    }

    mutating func i32() throws -> Int64 { Int64(Int32(bitPattern: try u32())) }

    mutating func float() throws -> Double { Double(Float(bitPattern: try u32())) }

    mutating func double() throws -> Double { Double(bitPattern: try u64()) }

    /// A `real_t`: a float, or a double in a file from a double-precision build.
    mutating func real() throws -> Double { realIsDouble ? try double() : try float() }

    /// A count of things that each take at least a byte.
    mutating func count() throws -> Int {
        let count = Int(try u32() & 0x7FFF_FFFF)
        guard count <= bytes.count - offset else { throw BinaryResourceError.truncated }
        return count
    }

    /// A string: its length in bytes, then UTF-8 with the zero that ends it.
    mutating func string() throws -> String {
        try text(Int(try u32()))
    }

    mutating func text(_ length: Int) throws -> String {
        var utf8 = try take(length)
        while utf8.last == 0 { utf8.removeLast() }
        return String(decoding: utf8, as: UTF8.self)
    }

    /// Skips to the next multiple of four bytes after `length` bytes of data.
    mutating func pad(after length: Int) throws {
        _ = try take((4 - length % 4) % 4)
    }
}

/// Reads property names and values, as `ResourceLoaderBinary::parse_variant` does.
private struct BinaryValueReader {
    var reader: BinaryReader
    let strings: [String]
    let internalIDs: [String]
    let format: Int

    /// A name: an index into the string table, or, with the top bit set, a length and the text.
    mutating func name() throws -> String {
        let id = try reader.u32()
        if id & 0x8000_0000 != 0 { return try reader.text(Int(id & 0x7FFF_FFFF)) }
        guard Int(id) < strings.count else { throw BinaryResourceError.truncated }
        return strings[Int(id)]
    }

    mutating func reals(_ count: Int) throws -> [Value] {
        try (0..<count).map { _ in .double(try reader.real()) }
    }

    mutating func ints(_ count: Int) throws -> [Value] {
        try (0..<count).map { _ in .int(try reader.i32()) }
    }

    mutating func packed(_ name: String, _ element: (inout BinaryReader) throws -> Value) throws -> Value {
        let count = try reader.count()
        var elements: [Value] = []
        elements.reserveCapacity(count)
        for _ in 0..<count { elements.append(try element(&reader)) }
        return .construct(name: name, args: elements)
    }

    mutating func value() throws -> Value {
        let kind = Int(try reader.u32())
        switch kind {
        case 1: return .null
        case 2: return .bool(try reader.u32() != 0)
        case 3: return .int(try reader.i32())
        case 40: return .int(Int64(bitPattern: try reader.u64()))
        case 4: return .double(try reader.real())
        case 41: return .double(try reader.double())
        case 5: return .string(try reader.string())
        case 44: return .stringName(try reader.string())
        case 10: return .construct(name: "Vector2", args: try reals(2))
        case 45: return .construct(name: "Vector2i", args: try ints(2))
        case 11: return .construct(name: "Rect2", args: try reals(4))
        case 46: return .construct(name: "Rect2i", args: try ints(4))
        case 12: return .construct(name: "Vector3", args: try reals(3))
        case 47: return .construct(name: "Vector3i", args: try ints(3))
        case 50: return .construct(name: "Vector4", args: try reals(4))
        case 51: return .construct(name: "Vector4i", args: try ints(4))
        case 13: return .construct(name: "Plane", args: try reals(4))
        case 14: return .construct(name: "Quaternion", args: try reals(4))
        case 15: return .construct(name: "AABB", args: try reals(6))
        case 18: return .construct(name: "Transform2D", args: try reals(6))
        case 16: return .construct(name: "Basis", args: try reals(9))
        case 17: return .construct(name: "Transform3D", args: try reals(12))
        case 52: return .construct(name: "Projection", args: try reals(16))
        case 20: return .construct(name: "Color", args: try (0..<4).map { _ in .double(try reader.float()) })
        case 22: return try nodePath()
        case 23: return .construct(name: "RID", args: [.int(Int64(try reader.u32()))])
        case 24: return try object()
        case 42: return .construct(name: "Callable", args: [])
        case 43: return .construct(name: "Signal", args: [])
        case 26:
            var pairs: [(Value, Value)] = []
            for _ in 0..<(try reader.count()) {
                let key = try value()
                pairs.append((key, try value()))
            }
            return .dictionary(pairs)
        case 30:
            var elements: [Value] = []
            for _ in 0..<(try reader.count()) { elements.append(try value()) }
            return .array(elements)
        case 31:
            let count = try reader.count()
            let elements = try reader.take(count).map { Value.int(Int64($0)) }
            try reader.pad(after: count)
            return .construct(name: "PackedByteArray", args: elements)
        case 32: return try packed("PackedInt32Array") { .int(try $0.i32()) }
        case 48: return try packed("PackedInt64Array") { .int(Int64(bitPattern: try $0.u64())) }
        case 33: return try packed("PackedFloat32Array") { .double(try $0.float()) }
        case 49: return try packed("PackedFloat64Array") { .double(try $0.double()) }
        case 34: return try packed("PackedStringArray") { .string(try $0.string()) }
        case 37: return .construct(name: "PackedVector2Array", args: try reals(try reader.count() * 2))
        case 35: return .construct(name: "PackedVector3Array", args: try reals(try reader.count() * 3))
        case 53: return .construct(name: "PackedVector4Array", args: try reals(try reader.count() * 4))
        case 36:
            let count = try reader.count() * 4
            return .construct(name: "PackedColorArray", args: try (0..<count).map { _ in .double(try reader.float()) })
        default: throw BinaryResourceError.unknownValueKind(kind)
        }
    }

    /// A node path as its text: names joined by `/`, a leading `/` when absolute, then each
    /// subname after a `:`.
    mutating func nodePath() throws -> Value {
        let nameCount = Int(try reader.u16())
        let flags = try reader.u16()
        let subnameCount = Int(flags & 0x7FFF) + (format < 3 ? 1 : 0)
        var names: [String] = []
        for _ in 0..<nameCount { names.append(try name()) }
        var path = (flags & 0x8000 != 0 ? "/" : "") + names.joined(separator: "/")
        for _ in 0..<subnameCount { path += ":" + (try name()) }
        return .nodePath(path)
    }

    /// A resource a property holds: none, one of the file's own by index, or an external one
    /// by index (by its path, in files older than the external table).
    mutating func object() throws -> Value {
        switch try reader.u32() {
        case 0: return .null
        case 2:
            let index = Int(try reader.u32())
            guard index < internalIDs.count else { throw BinaryResourceError.truncated }
            return .subResource(id: internalIDs[index])
        case 3: return .extResource(id: String(try reader.u32()))
        case 1:
            _ = try reader.string()
            return .resource(path: try reader.string())
        case let kind: throw BinaryResourceError.unknownValueKind(Int(kind))
        }
    }
}
