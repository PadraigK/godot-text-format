public indirect enum Value: Equatable, Sendable {
    // Atoms
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null

    // Containers (order-preserving)
    case array([Value])
    case dictionary([(Value, Value)])

    // References
    case extResource(id: String)
    case subResource(id: String)
    case nodePath(String)
    case stringName(String)
    case resource(path: String)

    // Catch-all for Vector2, Color, Transform3D, PackedByteArray, AABB, etc.
    case construct(name: String, args: [Value])

    // Object(ClassName, "prop": value, ...)
    case object(className: String, properties: [(String, Value)])

    // Array[T]([...]) typed array
    case typedArray(elementType: String, elements: [Value])

    // Dictionary[K, V]({...}) typed dictionary
    case typedDictionary(keyType: String, valueType: String, pairs: [(Value, Value)])

    // Hex color literal #RRGGBB / #RRGGBBAA
    case hexColor(UInt32, hasAlpha: Bool)
}

extension Value {
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)):
            if a.isNaN && b.isNaN { return true } // NaN == NaN for test convenience
            return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.null, .null): return true
        case (.array(let a), .array(let b)): return a == b
        case (.dictionary(let a), .dictionary(let b)):
            return a.count == b.count && zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.extResource(let a), .extResource(let b)): return a == b
        case (.subResource(let a), .subResource(let b)): return a == b
        case (.nodePath(let a), .nodePath(let b)): return a == b
        case (.stringName(let a), .stringName(let b)): return a == b
        case (.resource(let a), .resource(let b)): return a == b
        case (.construct(let an, let aa), .construct(let bn, let ba)):
            return an == bn && aa == ba
        case (.object(let an, let aps), .object(let bn, let bps)):
            return an == bn && aps.count == bps.count
                && zip(aps, bps).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.typedArray(let at, let ae), .typedArray(let bt, let be)):
            return at == bt && ae == be
        case (.typedDictionary(let ak, let av, let ap), .typedDictionary(let bk, let bv, let bp)):
            return ak == bk && av == bv && ap.count == bp.count
                && zip(ap, bp).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.hexColor(let av, let aa), .hexColor(let bv, let ba)):
            return av == bv && aa == ba
        default: return false
        }
    }
}
