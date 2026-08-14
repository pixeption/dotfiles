import Foundation
import ApplicationServices
import Darwin

func parentPid(_ pid: pid_t) -> pid_t {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return -1 }
    return pid_t(info.pbi_ppid)
}

// Find the running Unity Editor (any version) by executable path; skip Unity Hub and
// the AssetImportWorker children, which share the editor's executable path but have no
// windows. The editor is the match whose parent is not itself a Unity process.
func findUnity() -> pid_t? {
    var n = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
    let cap = Int(n) / MemoryLayout<pid_t>.size + 32
    var pids = [pid_t](repeating: 0, count: cap)
    n = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(cap * MemoryLayout<pid_t>.size))
    let count = Int(n) / MemoryLayout<pid_t>.size
    var buf = [CChar](repeating: 0, count: 4096)
    var matches: [(pid: pid_t, ppid: pid_t)] = []
    for i in 0..<count {
        let p = pids[i]; if p == 0 { continue }
        if proc_pidpath(p, &buf, 4096) <= 0 { continue }
        let path = String(cString: buf)
        if path.hasSuffix("/Unity.app/Contents/MacOS/Unity") && !path.contains("Unity Hub") {
            matches.append((p, parentPid(p)))
        }
    }
    let pidSet = Set(matches.map { $0.pid })
    return matches.first { !pidSet.contains($0.ppid) }?.pid
}

func boolAttr(_ ax: AXUIElement, _ key: String) -> Bool {
    var r: CFTypeRef?
    AXUIElementCopyAttributeValue(ax, key as CFString, &r)
    return (r as? Bool) ?? false
}

func raiseWindows(_ ax: AXUIElement) {
    var wr: CFTypeRef?
    AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &wr)
    if let wins = wr as? [AXUIElement] {
        for w in wins { AXUIElementPerformAction(w, kAXRaiseAction as CFString) }
    }
}

guard let upid = findUnity() else { exit(0) }
let ax = AXUIElementCreateApplication(upid)

if boolAttr(ax, kAXFrontmostAttribute) {
    // Already looking at Unity -> hide it.
    AXUIElementSetAttributeValue(ax, kAXHiddenAttribute as CFString, kCFBooleanTrue)
} else {
    // Unhide first; wait for it to settle before raising/fronting.
    let wasHidden = boolAttr(ax, kAXHiddenAttribute)
    AXUIElementSetAttributeValue(ax, kAXHiddenAttribute as CFString, kCFBooleanFalse)
    if wasHidden {
        for _ in 0..<25 { // up to ~250ms
            if !boolAttr(ax, kAXHiddenAttribute) { break }
            usleep(10_000)
        }
    }
    // Raise all windows and bring frontmost, retrying until it takes.
    for _ in 0..<15 { // up to ~150ms
        raiseWindows(ax)
        AXUIElementSetAttributeValue(ax, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if boolAttr(ax, kAXFrontmostAttribute) { break }
        usleep(10_000)
    }
}
