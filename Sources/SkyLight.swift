import Foundation

/// Private CoreGraphics / SkyLight bindings for reading the current Space ID.
///
/// macOS provides NSWorkspace.activeSpaceDidChangeNotification publicly, but gives
/// no public API for a stable Space identifier. yabai, Hammerspoon, and TotalSpaces
/// all relied on these two undocumented symbols. They have been stable since ~10.11.
///
/// We resolve them at runtime via dlsym on the global symbol scope so the binary
/// does not hard-link to the private framework. If Apple ever removes them,
/// `currentSpaceID()` simply returns nil and the app degrades gracefully.
enum SkyLight {
    private typealias CGSMainConnectionIDFunc = @convention(c) () -> UInt32
    private typealias CGSGetActiveSpaceFunc = @convention(c) (UInt32) -> UInt64

    private static let globalHandle: UnsafeMutableRawPointer? = dlopen(nil, RTLD_NOW)

    private static let mainConnectionID: CGSMainConnectionIDFunc? = {
        guard let handle = globalHandle,
            let sym = dlsym(handle, "CGSMainConnectionID")
        else { return nil }
        return unsafeBitCast(sym, to: CGSMainConnectionIDFunc.self)
    }()

    private static let getActiveSpace: CGSGetActiveSpaceFunc? = {
        guard let handle = globalHandle,
            let sym = dlsym(handle, "CGSGetActiveSpace")
        else { return nil }
        return unsafeBitCast(sym, to: CGSGetActiveSpaceFunc.self)
    }()

    static func currentSpaceID() -> UInt64? {
        guard let cid = mainConnectionID?() else { return nil }
        return getActiveSpace?(cid)
    }
}
