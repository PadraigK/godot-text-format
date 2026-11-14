import XCTest
import Foundation
@testable import GodotTextFormat

/// The fixtures in `Fixtures/binary` are Godot 4.7.2's own output, written by `make.gd` there:
/// each resource as text, as binary, and as binary compressed.
final class BinaryResourceTests: XCTestCase {
    private func bytes(_ name: String) throws -> [UInt8] {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/binary")!
        return [UInt8](try Data(contentsOf: url))
    }

    private func text(_ name: String) throws -> ResourceFile {
        try ResourceFile.parse(String(decoding: try bytes(name), as: UTF8.self))
    }

    /// The class of the resource a binary file holds is read from its header, compressed or
    /// not, and from the start of the file alone. A file that isn't one says so. llm-generated
    func testTypeOfBinaryResource() throws {
        XCTAssertEqual(try ResourceFile.type(ofBinary: try bytes("library.res")), "AnimationLibrary")
        XCTAssertEqual(try ResourceFile.type(ofBinary: try bytes("library-compressed.res")), "AnimationLibrary")
        XCTAssertEqual(try ResourceFile.type(ofBinary: try bytes("frames-compressed.res")), "SpriteFrames")
        XCTAssertEqual(try ResourceFile.type(ofBinary: Array(try bytes("values.res").prefix(256))), "Resource")
        XCTAssertThrowsError(try ResourceFile.type(ofBinary: try bytes("library.tres"))) { error in
            XCTAssertEqual(error as? BinaryResourceError, .notBinaryResource)
        }
    }

    /// A binary animation library gives the animation names, uid and sub-resources its text
    /// twin gives, compressed or not. llm-generated
    func testBinaryLibraryReadsAsItsTextTwin() throws {
        let twin = try text("library.tres")
        for name in ["library.res", "library-compressed.res"] {
            let file = try ResourceFile.parse(binary: try bytes(name))
            XCTAssertEqual(file.type, "AnimationLibrary", name)
            XCTAssertEqual(file.uid, "uid://bw6o1pq4ksl5j", name)
            XCTAssertEqual(file.uid, twin.uid, name)
            XCTAssertEqual(AnimationExtractor.animationNames(inLibrary: file), ["Take 001", "idle", "walk"], name)
            XCTAssertEqual(AnimationExtractor.animationNames(inLibrary: file), AnimationExtractor.animationNames(inLibrary: twin), name)
            XCTAssertEqual(file.subResources.map(\.id), twin.subResources.map(\.id), name)
            XCTAssertEqual(file.subResources.map(\.type), twin.subResources.map(\.type), name)
        }
    }

    /// A binary SpriteFrames gives the animation names its text twin gives. llm-generated
    func testBinarySpriteFramesReadAsTheirTextTwin() throws {
        let twin = try text("frames.tres")
        for name in ["frames.res", "frames-compressed.res"] {
            let file = try ResourceFile.parse(binary: try bytes(name))
            XCTAssertEqual(AnimationExtractor.animationNames(inSpriteFrames: file), ["jump_up", "run"], name)
            XCTAssertEqual(AnimationExtractor.animationNames(inSpriteFrames: file), AnimationExtractor.animationNames(inSpriteFrames: twin), name)
        }
    }

    /// A value of every kind the binary format holds reads as the text format spells it: the
    /// same properties in the same order with the same values, numbers compared as numbers,
    /// dictionaries whatever their order, and resources by what they refer to. The binary file
    /// also keeps a null `script`, which the text file leaves out. llm-generated
    func testEveryValueKindReadsAsTheTextFormatSpellsIt() throws {
        let twin = try text("values.tres")
        let expected = twin.resource!.body.map { "\($0.0) = \(canonical($0.1, in: twin))" }
        XCTAssertEqual(expected.count, 39)
        for name in ["values.res", "values-compressed.res"] {
            let file = try ResourceFile.parse(binary: try bytes(name))
            let found = file.resource!.body.filter { $0.0 != "script" }.map { "\($0.0) = \(canonical($0.1, in: file))" }
            XCTAssertEqual(found, expected, name)
            XCTAssertEqual(file.subResources.map(\.type), ["Gradient"], name)
            XCTAssertEqual(file.extResources.map(\.path), ["res://frames.tres"], name)
        }
    }

    /// A file cut short throws rather than reading past its end, compressed or not.
    /// llm-generated
    func testFileCutShortIsTruncated() throws {
        for name in ["values.res", "values-compressed.res"] {
            let whole = try bytes(name)
            XCTAssertThrowsError(try ResourceFile.parse(binary: Array(whole.prefix(whole.count / 2))), name) { error in
                XCTAssertEqual(error as? BinaryResourceError, .truncated, name)
            }
        }
    }

    /// A value as text, alike for the two formats: every number as a double, a dictionary's
    /// pairs sorted, a byte array as its bytes (the text format writes it as base64), and a
    /// resource as the path or sub-resource it names.
    private func canonical(_ value: Value, in file: ResourceFile) -> String {
        switch value {
        case .int(let number): return String(Double(number))
        case .double(let number): return String(number)
        case .string(let text): return "\"\(text)\""
        case .stringName(let text): return "&\"\(text)\""
        case .nodePath(let path): return "^\"\(path)\""
        case .bool(let flag): return String(flag)
        case .null: return "null"
        case .array(let elements): return "[" + elements.map { canonical($0, in: file) }.joined(separator: ", ") + "]"
        case .dictionary(let pairs):
            return "{" + pairs.map { canonical($0.0, in: file) + ": " + canonical($0.1, in: file) }.sorted().joined(separator: ", ") + "}"
        case .construct(let name, let arguments):
            if name == "PackedByteArray", arguments.count == 1, case .string(let base64) = arguments[0] {
                return "PackedByteArray(" + (Data(base64Encoded: base64) ?? Data()).map { String(Double($0)) }.joined(separator: ", ") + ")"
            }
            return name + "(" + arguments.map { canonical($0, in: file) }.joined(separator: ", ") + ")"
        case .subResource(let id): return "SubResource(\(file.subResources.first { $0.id == id }?.type ?? "?") \(id))"
        case .extResource(let id): return "ExtResource(\(file.extResources.first { $0.id == id }?.path ?? "?"))"
        case .resource(let path): return "ExtResource(\(path))"
        default: return String(describing: value)
        }
    }
}
