internal import Lint
package import SwiftSyntax

extension Lint.SwiftUI {

  package enum Expression {}
}

extension Lint.SwiftUI.Expression {

  package static func isWithAnimation(_ call: FunctionCallExprSyntax) -> Swift::Bool {
    let callee = call.calledExpression
    if let reference = callee.as(DeclReferenceExprSyntax.self) {
      return reference.baseName.text == "withAnimation"
    }
    if let member = callee.as(MemberAccessExprSyntax.self),
      member.declName.baseName.text == "withAnimation",
      member.base?.trimmedDescription == "SwiftUI"
    {
      return true
    }
    return false
  }

  package static func name(of callee: ExprSyntax) -> Swift::String? {
    if let reference = callee.as(DeclReferenceExprSyntax.self) {
      return reference.baseName.text
    }
    if let specialized = callee.as(GenericSpecializationExprSyntax.self) {
      return name(of: specialized.expression)
    }
    return nil
  }

  package static func isBinding(_ expression: ExprSyntax?) -> Swift::Bool {
    var current = expression
    while let node = current {
      if let reference = node.as(DeclReferenceExprSyntax.self) {
        return reference.baseName.text.hasPrefix("$")
      }
      if let member = node.as(MemberAccessExprSyntax.self) {
        if member.declName.baseName.text.hasPrefix("$") { return true }
        current = member.base
        continue
      }
      if let call = node.as(FunctionCallExprSyntax.self) {
        current = call.calledExpression
        continue
      }
      if let forced = node.as(ForceUnwrapExprSyntax.self) {
        current = forced.expression
        continue
      }
      if let optional = node.as(OptionalChainingExprSyntax.self) {
        current = optional.expression
        continue
      }
      return false
    }
    return false
  }

  package static func isStable(_ expression: ExprSyntax) -> Swift::Bool {
    if let literal = expression.as(StringLiteralExprSyntax.self) {
      return literal.segments.allSatisfy { $0.is(StringSegmentSyntax.self) }
    }
    if expression.is(IntegerLiteralExprSyntax.self)
      || expression.is(FloatLiteralExprSyntax.self)
      || expression.is(BooleanLiteralExprSyntax.self)
      || expression.is(NilLiteralExprSyntax.self)
    {
      return true
    }
    if let prefix = expression.as(PrefixOperatorExprSyntax.self),
      prefix.operator.text == "-"
    {
      return prefix.expression.is(IntegerLiteralExprSyntax.self)
        || prefix.expression.is(FloatLiteralExprSyntax.self)
    }
    if let member = expression.as(MemberAccessExprSyntax.self) {
      guard let base = member.base else { return true }
      return isTypeReference(base)
    }
    return false
  }

  package static func isTypeReference(_ expression: ExprSyntax) -> Swift::Bool {
    if let reference = expression.as(DeclReferenceExprSyntax.self) {
      let text = reference.baseName.text
      guard let first = text.first else { return false }
      return text == "Self" || first.isUppercase
    }
    if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
      guard let first = member.declName.baseName.text.first, first.isUppercase else { return false }
      return isTypeReference(base)
    }
    if let specialized = expression.as(GenericSpecializationExprSyntax.self) {
      return isTypeReference(specialized.expression)
    }
    return expression.is(TypeExprSyntax.self)
  }

  package static func isFunctionType(_ type: TypeSyntax) -> Swift::Bool {
    var current = type
    while true {
      if current.is(FunctionTypeSyntax.self) { return true }
      if let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
      } else if let optional = current.as(OptionalTypeSyntax.self) {
        current = optional.wrappedType
      } else if let unwrapped = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        current = unwrapped.wrappedType
      } else if let tuple = current.as(TupleTypeSyntax.self), tuple.elements.count == 1,
        let only = tuple.elements.first, only.firstName == nil
      {
        current = only.type
      } else {
        return false
      }
    }
  }

  package static func isInsideToolbar(_ node: some SyntaxProtocol) -> Swift::Bool {
    var current: Syntax? = Syntax(node).parent
    while let ancestor = current {
      if ancestor.is(DeclSyntax.self) && !ancestor.is(VariableDeclSyntax.self) {
        return false
      }
      if let closure = ancestor.as(ClosureExprSyntax.self), isToolbarBuilder(closure) {
        return true
      }
      current = ancestor.parent
    }
    return false
  }

  fileprivate static func isToolbarBuilder(_ closure: ClosureExprSyntax) -> Swift::Bool {
    var owner: Syntax? = closure.parent
    if let argument = owner?.as(LabeledExprSyntax.self) {
      owner = argument.parent?.parent
    } else if let element = owner?.as(MultipleTrailingClosureElementSyntax.self) {
      owner = element.parent?.parent
    }
    guard let call = owner?.as(FunctionCallExprSyntax.self) else { return false }
    let callee = call.calledExpression
    if let member = callee.as(MemberAccessExprSyntax.self) {
      return member.declName.baseName.text == "toolbar"
    }
    if let name = name(of: callee) {
      return name == "ToolbarItem" || name == "ToolbarItemGroup"
    }
    return false
  }
}
