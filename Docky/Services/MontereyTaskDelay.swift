import Foundation

struct DockyDelay: Sendable {
    let nanoseconds: UInt64

    static func seconds(_ seconds: Double) -> Self {
        let bounded = seconds.isFinite ? min(max(0, seconds), Double(UInt64.max / 1_000_000_000)) : 0
        return Self(nanoseconds: UInt64(bounded * 1_000_000_000))
    }

    static func milliseconds(_ milliseconds: Double) -> Self {
        seconds(milliseconds / 1000)
    }
}

func dockySleep(for delay: DockyDelay) async throws {
    try await Task<Never, Never>.sleep(nanoseconds: delay.nanoseconds)
}
