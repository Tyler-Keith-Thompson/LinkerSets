#if objectFormat(MachO)
import MachO
import Synchronization

extension LinkerSetSection {
    /// The section's segment and name in a Mach-O image: `@section("__DATA_CONST,__linker_sets")`.
    static let segmentName = "__DATA_CONST"
    static let sectionName = "__linker_sets"

    /// Every record in every image the loader has mapped, image by image in the order they were
    /// loaded, and within an image in the order the linker laid them out.
    ///
    /// The records are copied out while no image can be unmapped: an image `dlclose`d during the
    /// walk is read whole or not at all.
    static func records() -> [LinkerSetRecord] {
        // The loader's image callbacks and getsectiondata are the documented way to find a
        // section in each loaded image, with no symbol lookup by name and no reading of Swift's
        // metadata. Walking _dyld_image_count's indices instead races a concurrent dlclose, which
        // can shift the indices or unmap a header while it's read.
        _ = observingImages
        return loadedImages.withLock { images in
            // Can't trap: the callbacks store only the addresses of non-nil headers, never 0.
            images.flatMap { records(in: UnsafePointer(bitPattern: $0)!) }
        }
    }

    private static func records(in header: UnsafePointer<mach_header>) -> [LinkerSetRecord] {
        var size: UInt = 0
        #if _pointerBitWidth(_64)
        let image = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        #else
        let image = header
        #endif
        guard let start = getsectiondata(image, segmentName, sectionName, &size) else { return [] }
        return records(in: UnsafeRawBufferPointer(start: start, count: Int(size)))
    }
}

// The headers of the images dyld has mapped, as addresses, in the order they were added. dyld calls
// the remove callback before it unmaps an image, and the callback waits for this lock, so a read
// holding it never sees an image go. A Mutex rather than an actor: dyld's callbacks are
// synchronous C functions, and a read copies a few records while it holds the lock.
private let loadedImages = Mutex<[UInt]>([])

// Registers the callbacks once, on the first read. Registering calls the add callback for every
// image already loaded, in load order, before it returns. dyld has no call to unregister them, and
// none is needed: they live as long as the process.
private let observingImages: Void = {
    _dyld_register_func_for_remove_image { header, _ in
        guard let header else { return }
        let address = UInt(bitPattern: header)
        loadedImages.withLock { $0.removeAll { $0 == address } }
    }
    _dyld_register_func_for_add_image { header, _ in
        guard let header else { return }
        let address = UInt(bitPattern: header)
        loadedImages.withLock { $0.append(address) }
    }
}()
#endif
