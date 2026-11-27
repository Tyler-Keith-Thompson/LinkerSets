import LinkerSetsMacroSupport
import SwiftCompilerPlugin

// The third client's plugin: a kind, and the protocol every type it registers must conform to.

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
}
