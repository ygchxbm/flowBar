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

    func testSkipsUnrelatedRecordsBeforeUnalignedInterfaceMessage() throws {
        var message = interfaceMessage()
        message.ifm_data.ifi_ibytes = 12_345
        // Route dumps interleave interface and address records. A preceding
        // record need not align the next if_msghdr2 to its native alignment.
        var data = Data([5, 0, UInt8(RTM_VERSION), 0, 0])
        withUnsafeBytes(of: &message) { data.append(contentsOf: $0) }
        data.append(contentsOf: [4, 0, UInt8(RTM_VERSION + 1), UInt8(RTM_IFINFO2)])

        let samples = SystemNetworkInterfaceProvider.samples(from: data, hardwareNames: ["lo0"])
        let sample = try XCTUnwrap(samples.first)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(sample.name, "lo0")
        XCTAssertEqual(sample.receivedBytes, 12_345)
        XCTAssertTrue(sample.isHardware)
    }

    func testMalformedTailRejectsWholeSnapshot() {
        var message = interfaceMessage()
        let validRecord = withUnsafeBytes(of: &message) { Data($0) }
        for tail: [UInt8] in [
            [0],
            [3, 0, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)],
            [4, 0, UInt8(RTM_VERSION), UInt8(RTM_IFINFO2)]
        ] {
            var data = validRecord
            data.append(contentsOf: tail)
            XCTAssertTrue(SystemNetworkInterfaceProvider.samples(from: data, hardwareNames: []).isEmpty)
        }
    }

    private func interfaceMessage() -> if_msghdr2 {
        let index = if_nametoindex("lo0")
        XCTAssertNotEqual(index, 0)
        var message = if_msghdr2()
        message.ifm_msglen = UInt16(MemoryLayout<if_msghdr2>.size)
        message.ifm_version = UInt8(RTM_VERSION)
        message.ifm_type = UInt8(RTM_IFINFO2)
        message.ifm_index = UInt16(index)
        return message
    }
}
