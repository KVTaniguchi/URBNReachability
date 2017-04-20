//
//  Reachability.swift
//  URBNReachability
//
//  Created by Kevin Taniguchi on 4/19/17.
//  Copyright © 2017 URBN. All rights reserved.
//

import Foundation
import SystemConfiguration

extension Notification.Name {
    static let reachability = Notification.Name("ReachabilityDidChangeNotification")
}

enum ReachabilityStatus {
    case notReachable
    case reachableViaWiFi
    case reachableViaWWAN
}

struct ReachabilityX {
    var scNetworkReachabilty: SCNetworkReachability
}

// for checking specific URBN network connections, not randomly hitting www.google.com
class Reachability: NSObject {
    var isReachable: Bool {
        switch currentStatus {
        case .notReachable:
            return false
        case .reachableViaWiFi, .reachableViaWWAN:
            return true
        }
    }
    
    private var networkReachabilty: SCNetworkReachability?
    private var notifiying = false
    
    private var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        if let networkReachabilty = networkReachabilty,
            withUnsafeMutablePointer(to: &flags, {
                SCNetworkReachabilityGetFlags(networkReachabilty, UnsafeMutablePointer($0))}) == true {
            return flags
        }
        else {
            return []
        }
    }
    
    var currentStatus: ReachabilityStatus {
        if !flags.contains(.reachable) {
            return .notReachable
        }
        else if flags.contains(.isWWAN) {
            return .reachableViaWWAN
        }
        else if !flags.contains(.connectionRequired) {
            return .reachableViaWiFi
        }
        else if (flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) && !flags.contains(.interventionRequired)) {
            return .reachableViaWiFi
        }
        else {
            return .notReachable
        }
    }
    
    init?(host: String) {
        guard let nodeName = (host as NSString).utf8String,
              let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, nodeName) else { return nil }
        networkReachabilty = reachability
        
        super.init()
    }
    
    init?(hostAddress: sockaddr_in) {
        var address = hostAddress
        
        guard let defaultReachablity = withUnsafePointer(to: &address, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
            }
        }) else {
            return nil
        }
        
        networkReachabilty = defaultReachablity
    }
    
    static func internetReachabilty() -> Reachability? {
        var zeroAdr = sockaddr_in()
        zeroAdr.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAdr) )
        zeroAdr.sin_family = sa_family_t(AF_INET)
        return Reachability(hostAddress: zeroAdr)
    }
    
    func startNotifiying() -> Bool {
        guard !notifiying else { return false }
        
        var context = SCNetworkReachabilityContext()
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let reachability = networkReachabilty,
              SCNetworkReachabilitySetCallback(reachability, { (target, flags, info) in
                if let currentInfo = info {
                    let infoObject = Unmanaged<AnyObject>.fromOpaque(currentInfo).takeUnretainedValue()
                    if infoObject is Reachability {
                        let networkReachable = infoObject as! Reachability
                        NotificationCenter.default.post(name: Notification.Name.reachability, object: networkReachable)
                    }
                }
              }, &context) == true
        
        else { return false }
        
        guard  SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) == true else { return false }
        
        notifiying = true
        
        return notifiying
    }
    
    func stopNotifying() {
        if let reachable = networkReachabilty, notifiying == true {
            SCNetworkReachabilityUnscheduleFromRunLoop(reachable, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode as! CFString)
            notifiying = false
        }
    }
    
    deinit {
        stopNotifying()
    }
}
