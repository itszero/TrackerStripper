//
//  PasteboardMonitor.swift
//  TrackerStripper
//
//  Created by Zero Cho on 5/1/21.
//

import Foundation
import Cocoa

class PasteboardMonitor {
    var lastChangeCount : Int = 0
    var pollTimer : Timer? = nil
    var callback: (() -> Void)? = nil
    
    init(_ _callback: @escaping () -> Void) {
        pollTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerDidFire), userInfo: nil, repeats: true)
        callback = _callback
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func skipThisChange() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    @objc func timerDidFire() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        if changeCount != self.lastChangeCount {
            self.callback?()
        }
        self.lastChangeCount = changeCount
    }
    
    deinit {
        pollTimer?.invalidate()
        callback = nil
    }
}
