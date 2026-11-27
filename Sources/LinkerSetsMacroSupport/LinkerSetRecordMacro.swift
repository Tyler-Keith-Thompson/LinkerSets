import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#linkerSetRecord(kind:storing:)`: one record of `kind` whose accessor stores the expression,
/// written in the section LinkerSets owns, under `#if objectFormat(...)` with one declaration per
/// object format.
///
/// Every ``LinkerSetMacro`` expands to a call of it, so a client's expansion is one line that stays
/// the same when LinkerSets adds an object format: the per-format literal lives in this macro's
/// own expansion. The LinkerSets module declares it, and its plugin, LinkerSetsMacros, lists this
/// type.
///
/// The record is a private static member, so the call goes in a type or an extension: for a
/// declaration at file scope, a private enum of the record's own.
public enum LinkerSetRecordMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        #if canImport(SwiftSyntax510)
        let (macroName, arguments) = ("#" + node.macroName.text, node.arguments)
        #else
        // swift-syntax 509 names them `macro` and `argumentList`.
        let (macroName, arguments) = ("#" + node.macro.text, node.argumentList)
        #endif
        let kind = try arguments.kindArgument(macroName: macroName, at: node)
        guard let value = arguments.first(where: { $0.label?.text == "storing" })?.expression else {
            throw LinkerSetMacroDiagnostic(.missingValue, macroName: macroName, at: node).error
        }
        let name = context.makeUniqueName("linkerSetRecord")
        let storage = "private static let"
        let record: ExprSyntax = "(\(raw: kind.hexadecimalLiteral), 0, { outValue, type, _, _ in LinkerSetsRuntime.LinkerSetRecord.__store(\(value.trimmed), into: outValue, ifAsked: type) }, 0, 0)"
        // An ELF image holds each record as a note (LinkerSetRecord.Note) whose header gives the
        // record's size, a literal that differs with the pointer width; a section's initializer is
        // a constant expression, so each width gets a declaration of its own.
        return [
            """
            #if objectFormat(MachO)
            @section("__DATA_CONST,__linker_sets") @used \(raw: storage) \(name): LinkerSetsRuntime.LinkerSetRecord.Literal = \(record)
            #elseif objectFormat(ELF) && _pointerBitWidth(_64)
            @section(".note.linker_sets") @used \(raw: storage) \(name): LinkerSetsRuntime.LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), \(record))
            #elseif objectFormat(ELF) && _pointerBitWidth(_32)
            @section(".note.linker_sets") @used \(raw: storage) \(name): LinkerSetsRuntime.LinkerSetRecord.Note = (11, 20, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0), \(record))
            #elseif objectFormat(Wasm)
            @section("linker_sets") @used \(raw: storage) \(name): LinkerSetsRuntime.LinkerSetRecord.Literal = \(record)
            #elseif objectFormat(COFF)
            @section(".lnkset$M") @used \(raw: storage) \(name): LinkerSetsRuntime.LinkerSetRecord.Literal = \(record)
            #endif
            """,
        ]
    }
}
