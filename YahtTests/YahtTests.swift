import Testing
@testable import Yaht

/// Scaffold smoke test — proves the test target links against the app module and
/// the CI pipeline goes green. Real model/view-model tests land with the data
/// model step (see docs/PLAN.md).
struct YahtTests {
    @Test func appModuleIsImportable() {
        // If this compiles and runs, `@testable import Yaht` resolved and the
        // host app linked. Nothing behavioural to assert yet.
        #expect(Bool(true))
    }
}
