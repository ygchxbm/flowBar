import Combine
import XCTest
@testable import FlowBar

final class FlowBarPopoverViewModelTests: XCTestCase {
    @MainActor
    func testOnlyChangedDisplayedRowsArePublished() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: LaunchAtLoginController(service: service))
        var updates = 0
        let subscription = viewModel.$rows.dropFirst().sink { _ in updates += 1 }
        defer { subscription.cancel() }

        viewModel.update(snapshot: .unavailable)
        XCTAssertEqual(updates, 0)

        var snapshot = MetricsSnapshot(downloadBytesPerSecond: 1_024, uploadBytesPerSecond: 0, battery: .unavailable)
        viewModel.update(snapshot: snapshot)
        XCTAssertEqual(updates, 1)
        snapshot.downloadBytesPerSecond = 1_100 // Both snapshots display 1K.
        viewModel.update(snapshot: snapshot)
        XCTAssertEqual(updates, 1)
        snapshot.downloadBytesPerSecond = 2_048
        viewModel.update(snapshot: snapshot)
        XCTAssertEqual(updates, 2)
    }

    @MainActor
    func testSamplingDoesNotReadLoginStatusAndExplicitRefreshReflectsExternalChange() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: LaunchAtLoginController(service: service))
        let initialReads = service.statusReads
        service.currentStatus = .enabled

        viewModel.update(snapshot: .unavailable)

        XCTAssertEqual(service.statusReads, initialReads)
        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        viewModel.refreshLaunchAtLogin()
        XCTAssertTrue(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(service.statusReads, initialReads + 1)
    }

    @MainActor
    func testApprovalNoticeIsShownWithoutClaimingEnabledAndSettingsOpenOnlyOnRequest() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: LaunchAtLoginController(service: service))
        var notice: LaunchAtLoginNotice?
        viewModel.onLaunchAtLoginNotice = { notice = $0 }

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(notice, .requiresApproval)
        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(service.openSettingsCalls, 0)
        viewModel.openLoginItemSettings()
        XCTAssertEqual(service.openSettingsCalls, 1)
    }

    @MainActor
    func testRegistrationErrorWithPendingApprovalStillOffersSystemSettings() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.operationError = TestLaunchAtLoginError.denied
        service.statusAfterRegisterFailure = .requiresApproval
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: LaunchAtLoginController(service: service))
        var notice: LaunchAtLoginNotice?
        viewModel.onLaunchAtLoginNotice = { notice = $0 }

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(service.registerCalls, 1)
        XCTAssertEqual(notice, .requiresApproval)
        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(service.openSettingsCalls, 0)
        viewModel.openLoginItemSettings()
        XCTAssertEqual(service.openSettingsCalls, 1)
    }

    @MainActor
    func testFailureNoticeRetainsActualSystemState() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        service.operationError = TestLaunchAtLoginError.denied
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: LaunchAtLoginController(service: service))
        var notice: LaunchAtLoginNotice?
        viewModel.onLaunchAtLoginNotice = { notice = $0 }

        viewModel.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(notice, .failed("Test registration failure"))
        XCTAssertTrue(viewModel.launchAtLoginEnabled)
    }
}
