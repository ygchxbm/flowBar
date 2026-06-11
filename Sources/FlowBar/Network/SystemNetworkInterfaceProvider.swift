import Foundation

#if os(macOS)
import Darwin

final class SystemNetworkInterfaceProvider: NetworkInterfaceProviding {
    func interfaceSamples() -> [NetworkInterfaceSample] {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return []
        }
        defer { freeifaddrs(addressPointer) }

        var samples: [NetworkInterfaceSample] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = pointer {
            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data,
               let namePointer = interface.ifa_name {
                let dataPointer = data.bindMemory(to: if_data.self, capacity: 1)
                let receivedBytes = UInt64(dataPointer.pointee.ifi_ibytes)
                let name = String(cString: namePointer)

                samples.append(NetworkInterfaceSample(
                    name: name,
                    receivedBytes: receivedBytes,
                    isLoopback: isLoopback,
                    isActive: isUp && isRunning
                ))
            }

            pointer = interface.ifa_next
        }

        return samples
    }
}
#endif
