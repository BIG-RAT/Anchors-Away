//
//  Globals.swift
//  Anchors Away

//
//  Created by Leslie Helou on 6/10/21.
//  Copyright © 2021 jamf. All rights reserved.
//

import Foundation

struct appInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let build   = dict["CFBundleVersion"] as! String
    static let name    = dict["CFBundleExecutable"] as! String

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(appInfo.version)"
}

struct History {
    static var logPath: String? = (NSHomeDirectory() + "/Library/Logs/AnchorsAway/")
    static var logFile  = ""
    static var didRun   = false
    static var maxFiles = 20
}

struct jamfProVersion {
    static var major = 0
    static var minor = 0
    static var patch = 0
}

struct prestages {
    static var computer = [String:AnyObject]()
    static var mobile   = [String:AnyObject]()
}
