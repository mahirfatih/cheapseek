import XCTest
@testable import CheapSeek

/// Exercises the real `SMAppService` wrapper. Registering may change the login
/// items on the machine (and usually throws for ad-hoc signed dev builds); the
/// test swallows errors and always unregisters afterwards. See TESTING.md.
final class SystemLoginItemServiceTests: XCTestCase {

    func testRegisterUnregisterAndStatusDoNotCrash() {
        let service = SystemLoginItemService()
        defer { try? service.unregister() }

        _ = service.isEnabled
        try? service.unregister()
        try? service.register()
        _ = service.isEnabled
        try? service.unregister()

        XCTAssertTrue(true)
    }
}
