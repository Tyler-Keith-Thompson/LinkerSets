import LinkerSetsRuntime

/// The example app's schema migrations, each registered with ``Migration()``. A schema here
/// is the list of its tables' names.
public enum Migrations {
    /// Adds the users table.
    @Migration
    public static func addUsers(_ tables: inout [String]) {
        tables.append("users")
    }

    /// Adds the sessions table.
    @Migration
    public static func addSessions(_ tables: inout [String]) {
        tables.append("sessions")
    }
}

/// Adds the audit table, registered as a free function.
@Migration
public func addAudit(_ tables: inout [String]) {
    tables.append("audit")
}
