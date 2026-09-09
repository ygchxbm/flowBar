import Foundation

#if os(macOS)
import Darwin
import SystemConfiguration

final class SystemNetworkInterfaceProvider: NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample] {
        // Hardware interfaces count traffic once, before it passes through VPNs,
        // tunnels or bridges that can report the same received bytes again.
        let hardwareNames = Set(
            (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []).filter {
                let type = SCNetworkInterfaceGetInterfaceType($0)
                return type == kSCNetworkInterfaceTypeEthernet
                    || type == kSCNetworkInterfaceTypeIEEE80211
                    || type == kSCNetworkInterfaceTypeWWAN
            }.compactMap {
                SCNetworkInterfaceGetBSDName($0) as String?
            }
        )
        // NET_RT_IFLIST2 exposes 64-bit counters; getifaddrs uses if_data's
        // 32-bit byte counters, which wrap after every 4 GiB received.
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
                  size > 0 else { return [] }
            var data = Data(count: size)
            let result = data.withUnsafeMutableBytes { buffer in
                sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0)
            }
            if result == 0 {
                data.count = size
                return Self.samples(from: data, hardwareNames: hardwareNames)
            }
            // Interfaces can change between the sizing and reading calls.
            if errno != ENOMEM { return [] }
        }
        return []
    }

    static func samples(from data: Data, hardwareNames: Set<String>) -> [NetworkInterfaceSample] {
        data.withUnsafeBytes { buffer in
            var samples: [NetworkInterfaceSample] = []
            var offset = 0
            while offset + 4 <= buffer.count {
                let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard length >= 4, length <= buffer.count - offset else { return [] }
                let version = buffer[offset + 2]
                let type = buffer[offset + 3]
                if version == RTM_VERSION && type == RTM_IFINFO2 {
                    guard length >= MemoryLayout<if_msghdr2>.size else { return [] }
                    let message = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var nameBuffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(message.ifm_index), &nameBuffer) != nil {
                        let name = String(cString: nameBuffer)
                        let flags = message.ifm_flags
                        samples.append(NetworkInterfaceSample(
                            name: name,
                            receivedBytes: message.ifm_data.ifi_ibytes,
                            isLoopback: (flags & IFF_LOOPBACK) != 0,
                            isActive: (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0,
                            isHardware: hardwareNames.contains(name),
                            sentBytes: message.ifm_data.ifi_obytes
                        ))
                    }
                }
                offset += length
            }
            return offset == buffer.count ? samples : []
        }
    }
}
#endif
