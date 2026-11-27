import ExampleDiscovery

// A module that writes a few records and nothing else, the way an analytics module registers its
// events: it depends on ExampleDiscovery and LinkerSetsRuntime, never on LinkerSets, so the
// LinkerSetsMacros plugin isn't in its build. The kind is "sess".

/// The session events this module registers.
public enum SessionEvents {
    /// The kind of the module's records.
    public static let kind = LinkerSetKind(rawValue: 0x7365_7373)

    /// A session began.
    @Discoverable(kind: 0x7365_7373)
    static let started = "session started"

    /// A session ended.
    @Discoverable(kind: 0x7365_7373)
    static let ended = "session ended"
}

/// A session timed out, registered from file scope.
@Discoverable(kind: 0x7365_7373)
let sessionTimedOut = "session timed out"
