import Testing
@testable import OffYetCore

struct VersionTests {
    @Test func versionIs010() {
        #expect(version == "0.1.0")
    }
}
