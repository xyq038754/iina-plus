//
//  DanmakuWindowController.swift
//  iina+
//
//  Created by xjbeta on 2018/8/31.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa
import AppKit

class DanmakuWindowController: NSWindowController, NSWindowDelegate {
    var targeTitle = ""
    var waittingSocket = false
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.level = NSWindow.Level(NSWindow.Level.floating.rawValue)
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.ignoresMouseEvents = true
        window?.orderOut(self)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(foremostAppActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        NotificationCenter.default.addObserver(forName: .updateDanmakuWindow, object: nil, queue: .main) {_ in
            self.resizeWindow()
        }
    }
    
    func setObserver(_ pid: pid_t) {
        
        let observerCallback: AXObserverCallback = { _,_,_,_  in
            NotificationCenter.default.post(name: .updateDanmakuWindow, object: nil)
        }
        var window: CFTypeRef?
        
        let app = AXUIElementCreateApplication(pid)
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window)
        
        let observer: UnsafeMutablePointer<AXObserver?> = UnsafeMutablePointer<AXObserver?>.allocate(capacity: 1)
        AXObserverCreate(pid, observerCallback as AXObserverCallback, observer)
        
        if let observer = observer.pointee {
            let window = window as! AXUIElement
            AXObserverAddNotification(observer, window, kAXMovedNotification as CFString, nil)
            AXObserverAddNotification(observer, window, kAXResizedNotification as CFString, nil)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), CFRunLoopMode.defaultMode)
        }
    }

    
    func initDanmaku(_ site: LiveSupportList, _ title: String, _ url: String) {
        waittingSocket = true
        targeTitle = title
        if let danmakuViewController = self.contentViewController as? DanmakuViewController {
            danmakuViewController.initDanmaku(site, url)
        }
    }
    
    func initMpvSocket() {
        if let danmakuViewController = self.contentViewController as? DanmakuViewController {
            danmakuViewController.initMpvSocket()
        }
    }
    
    @objc func foremostAppActivated(_ notification: NSNotification) {
        guard let app = notification.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication,
            app.bundleIdentifier == "com.colliderli.iina" else {
                if let window = window, window.isVisible {
                    window.orderOut(self)
                    Logger.log("hide danmaku window")
                }
                return
        }
        resizeWindow()
    }
    
    func resizeWindow() {
        let tt = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .optionOnScreenAboveWindow], kCGNullWindowID) as? [[String: AnyObject]]
        if let d = tt?.filter ({
            if let owner = $0["kCGWindowOwnerName"] as? String,
                owner == "IINA",
                let title = $0["kCGWindowName"] as? String,
                title == targeTitle {
                return true
            } else {
                return false
            }
        }).first {
            var re = WindowData(d).frame
            re.origin.y = (NSScreen.main?.frame.size.height)! - re.size.height - re.origin.y
            guard let window = window else { return }
            window.setFrame(re, display: true)
            if !window.isVisible {
                window.orderFront(self)
                Logger.log("show danmaku window")
            }
            if waittingSocket {
                initMpvSocket()
                waittingSocket = false
                setObserver(pid_t(WindowData(d).pid))
            }
        }
    }
}



struct WindowData {
    public let name: String
    public let pid: Int
    public let wid: Int
    public let layer: Int
    public let opacity: CGFloat
    public let frame: CGRect
    
    init(_ d: [String: AnyObject]) {
        let _r = d[kCGWindowBounds as String] as? [String: Int]
        frame = NSRect(x: _r?["X"] ?? 0,
                       y: _r?["Y"] ?? 0,
                       width: _r?["Width"] ?? 0,
                       height: _r?["Height"] ?? 0)
        name = d[kCGWindowName as String] as? String ?? ""
        pid = d[kCGWindowOwnerPID as String] as? Int ?? -1
        wid = d[kCGWindowNumber as String] as? Int ?? -1
        layer = d[kCGWindowLayer as String] as? Int ?? 0
        opacity = d[kCGWindowAlpha as String] as? CGFloat ?? 0.0
    }
}
