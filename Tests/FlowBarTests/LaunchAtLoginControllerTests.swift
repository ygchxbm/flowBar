import ServiceManagement
import XCTest
@testable import FlowBar

final class LaunchAtLoginControllerTests: XCTestCase {
    @MainActor
    func testRegistrationReturnsActualSystemStatus() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let controller = LaunchAtLoginController(service: service)

        let result = controller.setEnabled(true)

        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(result.status, .requiresApproval)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(result.errorMessage)
    }

    @MainActor
    func testPendingApprovalDoesNotRepeatedlyRegisterAndCanBeCancelled() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertEqual(controller.setEnabled(true).status, .requiresApproval)
        XCTAssertEqual(service.registerCalls, 0)
        XCTAssertEqual(controller.setEnabled(false).status, .notRegistered)
        XCTAssertEqual(service.unregisterCalls, 1)
    }

    @MainActor
    func testFailureReportsErrorAndPreservesActualEnabledState() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        service.operationError = TestLaunchAtLoginError.denied
        let controller = LaunchAtLoginController(service: service)

        let result = controller.setEnabled(false)

        XCTAssertEqual(result.status, .enabled)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(result.errorMessage, "Test registration failure")
    }

    @MainActor
    func testAlreadyEnabledAndDisabledRequestsAreIdempotent() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)
        _ = controller.setEnabled(true)
        service.currentStatus = .notRegistered
        _ = controller.setEnabled(false)

        XCTAssertEqual(service.registerCalls, 0)
        XCTAssertEqual(service.unregisterCalls, 0)
    }
}

@MainActor
final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var currentStatus: SMAppService.Status
    var statusAfterRegister: SMAppService.Status = .enabled
    var statusAfterRegisterFailure: SMAppService.Status?
    var operationError: Error?
    private(set) var statusReads = 0
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0
    private(set) var openSettingsCalls = 0

    init(status: SMAppService.Status) {
        currentStatus = status
    }

    var status: SMAppService.Status {
        statusReads += 1
        return currentStatus
    }

    func register() throws {
        registerCalls += 1
        if let operationError {
            if let statusAfterRegisterFailure {
                currentStatus = statusAfterRegisterFailure
            }
            throw operationError
        }
        currentStatus = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        if let operationError { throw operationError }
        currentStatus = .notRegistered
    }

    func openSettings() {
        openSettingsCalls += 1
    }
}

enum TestLaunchAtLoginError: LocalizedError {
    case denied
    var errorDescription: String? { "Test registration failure" }
}
