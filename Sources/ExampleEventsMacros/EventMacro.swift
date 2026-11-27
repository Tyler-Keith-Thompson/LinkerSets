import LinkerSetsMacroSupport
import SwiftCompilerPlugin

// The third client's plugin: a kind, the protocol every type it registers must conform to, and the
// type's name as a key no two events in one program may share.

@main
struct ExampleEventsMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [EventMacro.self]
}

/// `@Event`: registers an event type, a record of kind `"evnt"` holding `any AnalyticsEvent.Type`.
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }

    // Qualified with its module, so a type of the same name where `@Event` is used can't shadow it.
    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "ExampleEvents.AnalyticsEvent"
    }

    // The declared name. A variable has none in the syntax, so an event held in one goes unchecked.
    public static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> String? {
        declaration.asProtocol(NamedDeclSyntax.self)?.name.text
    }
}
