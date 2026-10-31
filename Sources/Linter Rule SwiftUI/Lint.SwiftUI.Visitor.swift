public import Lint
public import Linter_Rule_Scope
public import SwiftSyntax

extension Lint.SwiftUI {

    public final class Visitor: SyntaxVisitor {

        public static let sequenceAlgorithms: Swift::Set<Swift::String> = [
            "filter", "sorted", "sort", "reduce", "map", "compactMap", "flatMap", "min", "max",
            "allSatisfy",
        ]

        public static let predicateAlgorithms: Swift::Set<Swift::String> = [
            "first", "last", "contains",
        ]

        public static let lifecycleModifiers: Swift::Set<Swift::String> = [
            "task", "onAppear", "onDisappear", "onChange", "onReceive",
        ]

        public static let stateWrappers: Swift::Set<Swift::String> = [
            "State", "StateObject", "ObservedObject", "AppStorage", "SceneStorage",
        ]

        public static let systemServices: Swift::Set<Swift::String> = [
            "UserDefaults", "FileManager",
        ]

        public static let storeBases: Swift::Set<Swift::String> = [
            "store", "self.store", "_store", "$store",
        ]

        let index: Lint.Scope.Index
        var frames: [Swift::Bool] = []
        var representable: [Swift::Bool] = []
        public var hits: [Hit] = []

        public init(index: Lint.Scope.Index) {
            self.index = index
            super.init(viewMode: .sourceAccurate)
        }

        var inScope: Swift::Bool {
            (frames.last ?? false) && !representable.contains(true)
        }

        func hit(_ node: some SyntaxProtocol, _ kind: Kind, _ detail: Swift::String) {
            guard inScope else { return }
            hits.append(Hit(node: Syntax(node), kind: kind, detail: detail))
        }

        func enter(
            _ node: some DeclSyntaxProtocol,
            inheritance: InheritanceClauseSyntax?,
            extending: Swift::Bool
        ) {
            let name = Lint.Scope.Declaration.qualified(type: Syntax(node)) ?? ""
            let isView =
                Lint.Scope.Index.conforms(inheritance, to: Lint.Scope.Index.viewProtocols)
                || Lint.Scope.Index.matches(name, in: index.views)
            let isRepresentable =
                Lint.Scope.Index.conforms(inheritance, to: Lint.Scope.Index.representableProtocols)
                || (extending && Lint.Scope.Index.matches(name, in: index.representables))
            frames.append(isView)
            representable.append(isRepresentable)
        }

        func leave() {
            frames.removeLast()
            representable.removeLast()
        }

        public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, inheritance: node.inheritanceClause, extending: false)
            return .visitChildren
        }

        public override func visitPost(_ node: StructDeclSyntax) { leave() }

        public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, inheritance: node.inheritanceClause, extending: false)
            return .visitChildren
        }

        public override func visitPost(_ node: ClassDeclSyntax) { leave() }

        public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, inheritance: node.inheritanceClause, extending: false)
            return .visitChildren
        }

        public override func visitPost(_ node: EnumDeclSyntax) { leave() }

        public override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, inheritance: node.inheritanceClause, extending: false)
            return .visitChildren
        }

        public override func visitPost(_ node: ActorDeclSyntax) { leave() }

        public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
            frames.append(false)
            representable.append(false)
            return .visitChildren
        }

        public override func visitPost(_ node: ProtocolDeclSyntax) { leave() }

        public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, inheritance: node.inheritanceClause, extending: true)
            return .visitChildren
        }

        public override func visitPost(_ node: ExtensionDeclSyntax) { leave() }

        public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard inScope else { return .visitChildren }
            if Lint.SwiftUI.Expression.isWithAnimation(node) {
                if !Lint.SwiftUI.Expression.animatesStoreSends(node) {
                    hit(node, .withAnimation, "`withAnimation` call")
                }
                return .visitChildren
            }
            let callee = node.calledExpression
            if let name = Lint.SwiftUI.Expression.name(of: callee) {
                call(node, named: name)
            } else if callee.is(DictionaryExprSyntax.self) {
                hit(node, .viewLogic, "Dictionary construction")
            } else if let member = callee.as(MemberAccessExprSyntax.self) {
                method(node, member: member)
            }
            return .visitChildren
        }

        func call(_ node: FunctionCallExprSyntax, named name: Swift::String) {
            let empty = node.arguments.isEmpty && node.trailingClosure == nil
            switch name {
            case "Task":
                hit(node, .viewLogic, "`Task { }`")
            case "Set", "Dictionary":
                hit(node, .viewLogic, "\(name) construction")
            case "Date" where empty, "UUID" where empty:
                hit(node, .viewLogic, "`\(name)()`")
            case "Store", "StoreOf":
                hit(node, .viewLogic, "`Store(` initialisation")
            default:
                break
            }
        }

        func method(_ node: FunctionCallExprSyntax, member: MemberAccessExprSyntax) {
            let name = member.declName.baseName.text
            let arguments = Swift::Array(node.arguments)
            let closure = node.trailingClosure != nil
            if name == "animation" {
                if Lint.SwiftUI.Expression.isBinding(member.base), arguments.count <= 1, !closure {
                    if !Lint.SwiftUI.Expression.isStoreBinding(member.base) {
                        hit(node, .animationModifier, "`Binding.animation(_:)` on a binding not rooted at `$store`")
                    }
                } else if !closure, arguments.count == 1, arguments[0].label == nil {
                    hit(node, .animationModifier, "`.animation(_:)`")
                }
                return
            }
            if name == "id", !closure, arguments.count == 1, arguments[0].label == nil {
                if !Lint.SwiftUI.Expression.isStable(arguments[0].expression) {
                    hit(node, .stateIdentity, "`.id(\(arguments[0].expression.trimmedDescription))`")
                }
                return
            }
            if name == "hidden", !closure, arguments.isEmpty {
                if Lint.SwiftUI.Expression.isInsideToolbar(node) {
                    hit(node, .toolbarHidden, "`.hidden()` in a toolbar builder")
                }
                return
            }
            if Self.sequenceAlgorithms.contains(name) {
                hit(node, .viewLogic, "`\(name)` call")
                return
            }
            if Self.predicateAlgorithms.contains(name) {
                if arguments.first?.label?.text == "where" || (arguments.isEmpty && closure) {
                    hit(node, .viewLogic, "`\(name)(where:)` call")
                }
                return
            }
            if Self.lifecycleModifiers.contains(name) {
                hit(node, .viewLogic, "`.\(name)` modifier")
                return
            }
            if name == "detached", member.base?.trimmedDescription == "Task" {
                hit(node, .viewLogic, "`Task.detached { }`")
            }
        }

        public override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            guard inScope, let base = node.base else { return .visitChildren }
            let name = node.declName.baseName.text
            if name == "modify", Self.storeBases.contains(base.trimmedDescription) {
                hit(node, .viewLogic, "`store.modify`")
            } else if name == "now", base.trimmedDescription == "Date" {
                hit(node, .viewLogic, "`Date.now`")
            }
            return .visitChildren
        }

        public override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            let name = node.baseName.text
            if Self.systemServices.contains(name) {
                hit(node, .viewLogic, "`\(name)`")
            }
            return .visitChildren
        }

        public override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            let name = node.name.text
            if Self.systemServices.contains(name) {
                hit(node, .viewLogic, "`\(name)`")
            }
            return .visitChildren
        }

        public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            guard inScope, node.parent?.is(MemberBlockItemSyntax.self) == true else {
                return .visitChildren
            }
            for element in node.attributes {
                guard let attribute = element.as(AttributeSyntax.self) else { continue }
                let wrapper = Lint.Scope.Declaration.leaf(attribute.attributeName)
                if Self.stateWrappers.contains(wrapper) {
                    hit(attribute, .viewState, "`@\(wrapper)` property")
                }
            }
            let isStatic = node.modifiers.contains {
                $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
            }
            guard !isStatic else { return .visitChildren }
            for binding in node.bindings {
                let name = binding.pattern.trimmedDescription
                if let annotation = binding.typeAnnotation {
                    if Lint.SwiftUI.Expression.isFunctionType(annotation.type), Self.isStored(binding) {
                        hit(binding, .viewState, "stored closure property `\(name)`")
                        continue
                    }
                    let leaf = Lint.Scope.Declaration.typeName(annotation.type)
                    if Lint.Scope.Index.matches(Self.unwrapped(leaf), in: index.observables) {
                        hit(binding, .viewState, "`@Observable` class property `\(name)`")
                        continue
                    }
                }
                if let value = binding.initializer?.value.as(FunctionCallExprSyntax.self),
                    let callee = Lint.SwiftUI.Expression.name(of: value.calledExpression),
                    Lint.Scope.Index.matches(callee, in: index.observables)
                {
                    hit(binding, .viewState, "`@Observable` class property `\(name)`")
                }
            }
            return .visitChildren
        }

        static func unwrapped(_ name: Swift::String) -> Swift::String {
            var name = name
            while name.hasSuffix("?") || name.hasSuffix("!") { name.removeLast() }
            return name
        }

        static func isStored(_ binding: PatternBindingSyntax) -> Swift::Bool {
            guard let block = binding.accessorBlock else { return true }
            guard let accessors = block.accessors.as(AccessorDeclListSyntax.self) else { return false }
            return accessors.allSatisfy {
                $0.accessorSpecifier.tokenKind == .keyword(.willSet)
                    || $0.accessorSpecifier.tokenKind == .keyword(.didSet)
            }
        }
    }
}
