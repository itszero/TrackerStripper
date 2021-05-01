//
//  AppDelegate.swift
//  TrackerStripper
//
//  Created by Zero Cho on 5/1/21.
//

import Cocoa
import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    let PARAMS_TO_REMOVE = [
        "fbclid",
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "gclid",
        "gclsrc",
        "dclid",
        "__cft__[0]",
        "__tn__",
    ]
    var window: NSWindow!
    var monitor: PasteboardMonitor? = nil
    var canSendNotification: Bool = false
    var statusItem: NSStatusItem? = nil
    var urlBeforeStripping: String = ""
    var lastDismissTimer: Timer? = nil
    
    struct TSEnums {
        struct Category {
            static let trackerStripped = "TRACKER_STRIPPED"
        }
        
        struct Action {
            static let restore = "RESTORE"
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let action = UNNotificationAction(identifier: TSEnums.Action.restore, title: "Restore", options: [])
        let actionCategory = UNNotificationCategory(identifier: TSEnums.Category.trackerStripped, actions: [action], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: nil, categorySummaryFormat: nil, options: [])
        UNUserNotificationCenter.current().setNotificationCategories([actionCategory])
        UNUserNotificationCenter.current().delegate = self

        setupPasteboardMonitor()
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .provisional], completionHandler: { granted, error in
            self.canSendNotification = true
        })
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(named: NSImage.Name("Logo"))
        statusItem?.button?.imageScaling = .scaleProportionallyDown
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "")
        statusItem?.menu = menu
    }

    func setupPasteboardMonitor() {
        monitor = PasteboardMonitor(self.handlePasteboardChange)
    }
    
    func handlePasteboardChange() {
        let pasteboard = NSPasteboard.general
        
        guard let items = pasteboard.pasteboardItems else {
            return
        }
        guard let firstItem = items.first else {
            return
        }
        guard let str = firstItem.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) else {
            return
        }
        guard var urlComponents = URLComponents(string: str.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")) else {
            return
        }

        var hasChanged = false
        if urlComponents.scheme == "http" || urlComponents.scheme == "https" {
            if var queryItems = urlComponents.queryItems {
                var idxToRemove: Array<Int> = []
                for (i, queryItem) in queryItems.enumerated() {
                    if PARAMS_TO_REMOVE.contains(queryItem.name.lowercased()) {
                        hasChanged = true
                        idxToRemove.append(i)
                    }
                }
                for idx in idxToRemove.reversed() {
                    queryItems.remove(at: idx)
                }

                if hasChanged {
                    urlBeforeStripping = str
                    urlComponents.queryItems = queryItems.count > 0 ? queryItems : nil
                }
            }
        }

        if hasChanged, let newUrlStr = urlComponents.string {
            pasteboard.clearContents()
            pasteboard.writeObjects([newUrlStr] as [NSPasteboardWriting])

            let notification = UNMutableNotificationContent()
            notification.title = "Tracker Stripped!"
            notification.body = "Tracker has been removed from your copied URL. Click here to restore it."
            notification.categoryIdentifier = TSEnums.Category.trackerStripped
            let request = UNNotificationRequest(identifier: "urlTrackerStripped", content: notification, trigger: nil)
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    return
                }
                DispatchQueue.main.async {
                    self.lastDismissTimer?.invalidate()
                    self.lastDismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false, block: { timer in
                        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    })
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let pasteboard = NSPasteboard.general
        switch response.actionIdentifier {
        case TSEnums.Action.restore:
            pasteboard.clearContents()
            pasteboard.writeObjects([urlBeforeStripping] as [NSPasteboardWriting])
            monitor?.skipThisChange()
        default:
            print("?? Unknown notification response")
        }
        
        completionHandler()
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
}

