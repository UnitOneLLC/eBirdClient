//
//  StreamReader.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/6/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//


import UIKit
import SystemConfiguration
import MapKit

// from http://stackoverflow.com/questions/24581517/read-a-file-url-line-by-line-in-swift
class StreamReader  {
    
    let encoding : UInt
    let chunkSize : Int
    
    var fileHandle : NSFileHandle?
    var buffer : NSMutableData?
    var delimData : NSData?
    var atEof : Bool
    
    init?(path: String, delimiter: String = "\n", encoding : UInt = NSUTF8StringEncoding, chunkSize : Int = 4096) {
        self.fileHandle = nil
        self.buffer = nil
        self.delimData = nil
        self.chunkSize = chunkSize
        self.encoding = encoding
        self.atEof = false
        
        if let fileHandle = NSFileHandle(forReadingAtPath: path) {
            self.fileHandle = fileHandle

            // Create NSData object containing the line delimiter:
            if let delimData = delimiter.dataUsingEncoding(NSUTF8StringEncoding) {
                self.delimData = delimData
                
                if let buffer = NSMutableData(capacity: chunkSize) {
                    self.buffer = buffer
                    return
                }
            }
        }
        
        return nil
    }
    
    deinit {
        self.close()
    }
    
    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        
        if atEof {
            return nil
        }
        
        // Read data chunks from file until a line delimiter is found:
        var range = buffer!.rangeOfData(delimData!, options: [], range: NSMakeRange(0, buffer!.length))
        while range.location == NSNotFound {
            let tmpData = fileHandle!.readDataOfLength(chunkSize)
            if tmpData.length == 0 {
                // EOF or read error.
                atEof = true
                if buffer!.length > 0 {
                    // Buffer contains last line in file (not terminated by delimiter).
                    let line = NSString(data: buffer!, encoding: encoding);
                    buffer!.length = 0
                    if line != nil {
                        return line as? String
                    }
                    return nil
                }
                // No more lines.
                return nil
            }
            buffer!.appendData(tmpData)
            range = buffer!.rangeOfData(delimData!, options: [], range: NSMakeRange(0, buffer!.length))
        }
        
        // Convert complete line (excluding the delimiter) to a string:
        let line = NSString(data: buffer!.subdataWithRange(NSMakeRange(0, range.location)),
            encoding: encoding)
        // Remove line (and the delimiter) from the buffer:
        buffer!.replaceBytesInRange(NSMakeRange(0, range.location + range.length), withBytes: nil, length: 0)

        
        if line == nil {
            return nil;
        }
        
        return line! as String
    }
    
    /// Start reading from the beginning of file.
    func rewind() -> Void {
        fileHandle!.seekToFileOffset(0)
        buffer!.length = 0
        atEof = false
    }
    
    /// Close the underlying file. No reading must be done after calling this method.
    func close() -> Void {
        if fileHandle != nil {
            fileHandle!.closeFile()
            fileHandle = nil
        }
    }
}


public class Reachability {
    class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
}

func isInternetConnected() -> Bool {
    return Reachability.isConnectedToNetwork()
}

func getAlertIfNoInternet() -> UIAlertController? {
    
    if isInternetConnected() {
        return nil
    }

    let alert = UIAlertController(title: "No Internet Connection",
        message: "This app requires a connection to the internet.",
        preferredStyle: .Alert)

    let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
        // ...
    }
    alert.addAction(OKAction)
    
    return alert
}

func getAlertIfNoLocationServices() -> UIAlertController? {
    
    let status = CLLocationManager.authorizationStatus()
    if status == CLAuthorizationStatus.AuthorizedAlways || status == CLAuthorizationStatus.AuthorizedWhenInUse {
        return nil
    }
    
    let alert = UIAlertController(title: "Location Services Disabled",
        message: "This app will not work correctly with Location Services disabled.",
        preferredStyle: .Alert)
    
    let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
        // ...
    }
    
    alert.addAction(OKAction)
    
    return alert
}

func simpleAlert(title: String, message: String, controller: UIViewController) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
    let okAction = UIAlertAction(title: "OK", style: .Default) { (action) in  }
    alert.addAction(okAction)
    controller.presentViewController(alert, animated: true, completion: nil)
}

extension NSDate {
    func isAfter(d: NSDate) -> Bool {
        return self.compare(d) == NSComparisonResult.OrderedDescending
    }
    
    func isBefore(d: NSDate) -> Bool {
        return self.compare(d) == NSComparisonResult.OrderedAscending
    }
}

func trim(string string: String) -> String {
    let components = string.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter({!$0.characters.isEmpty})
    return components.joinWithSeparator(" ")
}

func falsey(arg: Bool?) -> Bool {
    return arg == nil || !arg!
}


func synchronized(lock: AnyObject, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}




