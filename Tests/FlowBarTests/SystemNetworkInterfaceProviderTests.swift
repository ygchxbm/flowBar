import Darwin
import XCTest
@testable import FlowBar

final class SystemNetworkInterfaceProviderTests: XCTestCase {
    func testPreserves64BitCountersAndInterfaceFlags() throws {
        let index = if_nametoindex("lo0")
        XCTAssertNotEqual(index, 0)
        var message = if_msghdr2()
        message.ifm_msglen = UInt16(MemoryLayout<if_msghdr2>.size)
        message.ifm_version = UInt8(RTM_VERSION)
        message.ifm_type = UInt8(RTM_IFINFO2)
        message.ifm_index = UInt16(index)
        message.ifm_flags = IFF_UP | IFF_RUNNING | IFF_LOOPBACK
        message.ifm_data.ifi_ibytes = UInt64(UInt32.max) + 12_345
        message.ifm_data.ifi_obytes = UInt64(UInt32.max) + 54321
        let data = withUnsafeBytes(of: &message) { Data($0) }

        let samples = SystemNetworkInterfaceProvider.samples(from: data, hardwareNames: [])
        let sample = try XCTUnwrap(samples.first)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(sample.name, "lo0")
        XCTAssertEqual(sample.receivedBytes, UInt64(UInt32.max) + 12_345)
        XCTAssertEqual(sample.sentBytes, UInt64(UInt32.max) + 54321)
        XCTAssertTrue(sample.isActive)
        XCTAssertTrue(sample.isLoopback)
        XCTAssertFalse(sample.isHardware)
    }

    func testRejectsTruncatedAndZeroLengthMessages() {
        for data in [Data([0, 0, 5, 18]), Data([255, 0, 5, 18]), Data([1]) ] {
            XCTAssertTrue(SystemNetworkInterfaceProvider.samples(from: data, hardwareNames: []).isEmpty)
        }
    }
}
