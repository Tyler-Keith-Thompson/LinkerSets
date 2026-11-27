#if objectFormat(COFF)
import WinSDK

extension LinkerSetSection {
    /// The section's name in a PE image. Records are placed in `.lnkset$M`; the linker merges every
    /// `.lnkset$<suffix>` contribution into one `.lnkset` section, ordered by suffix. A PE image's
    /// section names are at most 8 bytes.
    static let imageSectionName = Array(".lnkset".utf8)

    /// Every record in every module the process has loaded, module by module in the loader's
    /// order, and within a module in the order the linker laid them out. A module freed during the
    /// walk is read whole or left out.
    static func records() -> [LinkerSetRecord] {
        // K32EnumProcessModules (psapi, exported by kernel32) lists the loaded modules, the
        // program and its DLLs, as dyld's image list does on Apple platforms; each module's
        // handle is its base address, where its PE headers begin. No symbol is looked up by name.
        modules().flatMap { base in
            // A module freed after the list was taken would leave `base` pointing at unmapped
            // memory. GetModuleHandleExW takes a reference on the module mapped at that address, if
            // one still is, so it stays mapped while its headers are read; FreeLibrary drops it.
            var module: HMODULE?
            guard GetModuleHandleExW(DWORD(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS), base.assumingMemoryBound(to: WCHAR.self), &module),
                  let module else { return [] }
            defer { FreeLibrary(module) }
            return records(inImageAt: UnsafeRawPointer(module))
        }
    }

    private static func modules() -> [UnsafeRawPointer] {
        let process = GetCurrentProcess()
        var needed: DWORD = 0
        guard K32EnumProcessModules(process, nil, 0, &needed), needed > 0 else { return [] }
        // A module loaded between the two calls is left out; the list asked for is filled up to
        // its size, and `needed` says how much it took.
        var handles = [HMODULE?](repeating: nil, count: Int(needed) / MemoryLayout<HMODULE?>.stride)
        let size = DWORD(handles.count * MemoryLayout<HMODULE?>.stride)
        guard K32EnumProcessModules(process, &handles, size, &needed) else { return [] }
        return handles.prefix(Int(min(needed, size)) / MemoryLayout<HMODULE?>.stride)
            .compactMap { $0.map { UnsafeRawPointer($0) } }
    }

    /// The records in the `.lnkset` section of the PE image mapped at `base`, read from its
    /// section table (Microsoft's PE format: the DOS header's `e_lfanew` at 0x3C locates the NT
    /// headers; the file header, after the 4-byte signature, holds `NumberOfSections` at 2 and
    /// `SizeOfOptionalHeader` at 16; the 40-byte section headers follow the optional header, each
    /// with an 8-byte name, then `VirtualSize` at 8 and `VirtualAddress` at 12).
    private static func records(inImageAt base: UnsafeRawPointer) -> [LinkerSetRecord] {
        let ntHeaders = Int(base.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self))
        guard base.loadUnaligned(fromByteOffset: ntHeaders, as: UInt32.self) == 0x0000_4550 else { return [] }  // "PE\0\0"
        let fileHeader = ntHeaders + 4
        let sectionCount = Int(base.loadUnaligned(fromByteOffset: fileHeader + 2, as: UInt16.self))
        let optionalHeaderSize = Int(base.loadUnaligned(fromByteOffset: fileHeader + 16, as: UInt16.self))
        let sectionTable = fileHeader + 20 + optionalHeaderSize
        for index in 0 ..< sectionCount {
            let header = sectionTable + index * 40
            let name = UnsafeRawBufferPointer(start: base + header, count: 8)
            guard name.prefix(imageSectionName.count).elementsEqual(imageSectionName),
                  name.dropFirst(imageSectionName.count).allSatisfy({ $0 == 0 }) else { continue }
            let size = Int(base.loadUnaligned(fromByteOffset: header + 8, as: UInt32.self))
            let address = Int(base.loadUnaligned(fromByteOffset: header + 12, as: UInt32.self))
            // The linker may pad between the contributions of different object files.
            return records(skippingPadding: UnsafeRawBufferPointer(start: base + address, count: size))
        }
        return []
    }
}
#endif
