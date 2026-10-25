import Foundation
import Darwin
import SystemConfiguration

/// In-process real-time network throughput collector reading BSD routing sockets via sysctl.
/// Queries cumulative byte counters directly without spawning child processes or invoking nettop.
public final class NetworkCollector: @unchecked Sendable {

    private struct PreviousSample {
        let interfaceName: String
        let inBytes: UInt64
        let outBytes: UInt64
        let timestampNanos: UInt64
    }

    private var previousSample: PreviousSample?
    private let lock = NSLock()
    private let configuredInterfaceName: String?

    /// Initializes a network collector.
    /// - Parameter interfaceName: Optional specific interface to monitor (e.g. "en0"). If nil, auto-resolves the active physical interface.
    public init(interfaceName: String? = nil) {
        self.configuredInterfaceName = interfaceName
    }

    /// The current network interface name being monitored.
    public var activeInterfaceName: String {
        configuredInterfaceName ?? Self.resolveActiveInterfaceName()
    }

    /// Samples current upload and download throughput for the active network interface.
    /// Returns 0.0 B/s on the first sample to establish a baseline.
    public func sample() -> NetworkStats {
        let interfaceName = activeInterfaceName
        let localIP = Self.resolveLocalIP(forInterface: interfaceName)
        guard let ifIndex = Self.interfaceIndex(forName: interfaceName),
              let (inBytes, outBytes) = Self.readInterfaceBytes(ifIndex: ifIndex) else {
            lock.withLock {
                previousSample = nil
            }
            return NetworkStats(uploadBytesPerSecond: 0.0, downloadBytesPerSecond: 0.0, interfaceName: interfaceName, localIP: localIP)
        }

        let now = DispatchTime.now().uptimeNanoseconds

        return lock.withLock {
            guard let prev = previousSample, prev.interfaceName == interfaceName else {
                previousSample = PreviousSample(
                    interfaceName: interfaceName,
                    inBytes: inBytes,
                    outBytes: outBytes,
                    timestampNanos: now
                )
                return NetworkStats(uploadBytesPerSecond: 0.0, downloadBytesPerSecond: 0.0, interfaceName: interfaceName, localIP: localIP)
            }

            previousSample = PreviousSample(
                interfaceName: interfaceName,
                inBytes: inBytes,
                outBytes: outBytes,
                timestampNanos: now
            )

            return Self.calculateRates(
                previous: (inBytes: prev.inBytes, outBytes: prev.outBytes, timestampNanos: prev.timestampNanos),
                current: (inBytes: inBytes, outBytes: outBytes, timestampNanos: now),
                interfaceName: interfaceName,
                localIP: localIP
            )
        }
    }

    /// Resets previous sample baseline.
    public func reset() {
        lock.withLock {
            previousSample = nil
        }
    }

    /// Pure function deriving upload/download rates from consecutive samples.
    /// Handles wrapping subtraction (`&-`) and non-positive elapsed time.
    public static func calculateRates(
        previous: (inBytes: UInt64, outBytes: UInt64, timestampNanos: UInt64),
        current: (inBytes: UInt64, outBytes: UInt64, timestampNanos: UInt64),
        interfaceName: String = "en0",
        localIP: String? = nil
    ) -> NetworkStats {
        guard current.timestampNanos > previous.timestampNanos else {
            return NetworkStats(uploadBytesPerSecond: 0.0, downloadBytesPerSecond: 0.0, interfaceName: interfaceName, localIP: localIP)
        }

        let timeDeltaNanos = current.timestampNanos - previous.timestampNanos
        let elapsedSeconds = Double(timeDeltaNanos) / 1_000_000_000.0

        guard elapsedSeconds > 0 else {
            return NetworkStats(uploadBytesPerSecond: 0.0, downloadBytesPerSecond: 0.0, interfaceName: interfaceName, localIP: localIP)
        }

        let inDelta = current.inBytes &- previous.inBytes
        let outDelta = current.outBytes &- previous.outBytes

        let downloadRate = Double(inDelta) / elapsedSeconds
        let uploadRate = Double(outDelta) / elapsedSeconds

        return NetworkStats(
            uploadBytesPerSecond: (uploadRate.isFinite && uploadRate >= 0) ? uploadRate : 0.0,
            downloadBytesPerSecond: (downloadRate.isFinite && downloadRate >= 0) ? downloadRate : 0.0,
            interfaceName: interfaceName,
            localIP: localIP
        )
    }

    /// Resolves the local IPv4 address assigned to a specific interface without network requests.
    public static func resolveLocalIP(forInterface targetName: String) -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let namePtr = ptr.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)
            guard name == targetName, let addr = ptr.pointee.ifa_addr else { continue }

            if addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let saLen = socklen_t(addr.pointee.sa_len)
                if getnameinfo(addr, saLen, &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = hostname.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) } ?? ""
                    }
                    if !ip.isEmpty && ip != "127.0.0.1" {
                        return ip
                    }
                }
            }
        }
        return nil
    }

    /// Resolves the active physical network interface name (e.g. "en0"),
    /// inspecting SystemConfiguration dynamic store with fallback to getifaddrs,
    /// skipping virtual/VPN adapters like "utun".
    public static func resolveActiveInterfaceName() -> String {
        // 1. Try SystemConfiguration dynamic store
        if let store = SCDynamicStoreCreate(nil, "StatsBar" as CFString, nil, nil) {
            for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
                if let dict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
                   let primary = dict["PrimaryInterface"] as? String,
                   !primary.isEmpty,
                   !isVirtualInterface(primary),
                   let index = interfaceIndex(forName: primary),
                   index > 0 {
                    return primary
                }
            }
        }

        // 2. Fallback to getifaddrs scanning for active physical interfaces
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr {
            defer { freeifaddrs(ifaddrPtr) }
            var fallbackCandidate: String?

            for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
                guard let namePtr = ptr.pointee.ifa_name else { continue }
                let name = String(cString: namePtr)
                let flags = Int32(ptr.pointee.ifa_flags)
                guard (flags & IFF_UP) != 0,
                      (flags & IFF_RUNNING) != 0,
                      (flags & IFF_LOOPBACK) == 0,
                      !isVirtualInterface(name) else {
                    continue
                }

                if let addr = ptr.pointee.ifa_addr {
                    let family = addr.pointee.sa_family
                    if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                        if name.hasPrefix("en") {
                            return name
                        }
                        if fallbackCandidate == nil {
                            fallbackCandidate = name
                        }
                    }
                }
            }
            if let candidate = fallbackCandidate {
                return candidate
            }
        }

        // 3. Fallback to default en0
        return "en0"
    }

    /// Checks if an interface is a virtual, VPN, or loopback tunnel adapter.
    public static func isVirtualInterface(_ name: String) -> Bool {
        let virtualPrefixes = [
            "utun", "ipsec", "ppp", "lo", "awdl", "llw",
            "bridge", "anpi", "gif", "stf", "p2p", "ap"
        ]
        return virtualPrefixes.contains(where: { name.hasPrefix($0) })
    }

    /// Resolves the BSD interface index for a given interface name.
    public static func interfaceIndex(forName name: String) -> Int32? {
        let index = if_nametoindex(name)
        guard index > 0 else { return nil }
        return Int32(index)
    }

    /// Queries BSD routing table via sysctl([CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, if_index])
    /// and reads `if_msghdr2` message records (`header2.ifm_data.ifi_ibytes` and `ifi_obytes`).
    public static func readInterfaceBytes(ifIndex: Int32) -> (inBytes: UInt64, outBytes: UInt64)? {
        if let direct = queryInterfaceBytes(mibIfIndex: ifIndex, targetIfIndex: ifIndex) {
            return direct
        }
        return queryInterfaceBytes(mibIfIndex: 0, targetIfIndex: ifIndex)
    }

    private static func queryInterfaceBytes(mibIfIndex: Int32, targetIfIndex: Int32) -> (inBytes: UInt64, outBytes: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, mibIfIndex]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else {
            return nil
        }

        return buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let msgHdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let msgLen = Int(msgHdr.ifm_msglen)
                guard msgLen > 0, offset + msgLen <= length else { break }

                if Int32(msgHdr.ifm_type) == RTM_IFINFO2 && offset + MemoryLayout<if_msghdr2>.size <= length {
                    let header2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if targetIfIndex == 0 || Int32(header2.ifm_index) == targetIfIndex {
                        return (inBytes: header2.ifm_data.ifi_ibytes, outBytes: header2.ifm_data.ifi_obytes)
                    }
                }
                offset += msgLen
            }
            return nil
        }
    }

    /// Reads cumulative byte counters for a named network interface.
    public static func readInterfaceBytes(forName name: String) -> (inBytes: UInt64, outBytes: UInt64)? {
        guard let index = interfaceIndex(forName: name) else { return nil }
        return readInterfaceBytes(ifIndex: index)
    }
}
