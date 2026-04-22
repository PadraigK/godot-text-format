public enum InputActionsExtractor {
    public struct InputAction: Equatable {
        public let name: String
        public let deadzone: Double?
        public init(name: String, deadzone: Double?) {
            self.name = name
            self.deadzone = deadzone
        }
    }

    public struct InputActions: Equatable {
        public let base: [InputAction]
        public let platformVariants: [String: [InputAction]]
        public init(base: [InputAction], platformVariants: [String: [InputAction]]) {
            self.base = base
            self.platformVariants = platformVariants
        }
    }

    public static func extract(from project: ProjectFile) -> InputActions {
        var base: [InputAction] = []
        var variants: [String: [InputAction]] = [:]

        for section in project.sections(named: "input") {
            let variant = section.kind == "input" ? nil : String(section.kind.dropFirst("input.".count))
            let actions = section.body.compactMap(parseAction)
            if let v = variant {
                variants[v] = actions
            } else {
                base = actions
            }
        }

        return InputActions(base: base, platformVariants: variants)
    }

    private static func parseAction(_ kv: (String, Value)) -> InputAction? {
        guard case .dictionary(let pairs) = kv.1 else { return nil }
        var deadzone: Double? = nil
        for (k, v) in pairs {
            if case .string("deadzone") = k {
                if case .double(let d) = v {
                    deadzone = d
                } else if case .int(let i) = v {
                    // Support integer-literal deadzone (e.g., `"deadzone": 0`)
                    deadzone = Double(i)
                }
            }
        }
        return InputAction(name: kv.0, deadzone: deadzone)
    }
}
