//
//  Logger.swift
//  BirdScene
//
//  Created by Fred Hewett on 2/3/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation

class Logger {
    
    enum Level: Int {
        case INFO=0
        case DEBUG
        case WARN
        case ERROR
        case FATAL
    }
    
    class func log<T: CustomStringConvertible>(fromSource source: T, level: Level, message: String) {
        var output = "\(source) "
        
        switch level {
        case .INFO: output += "INFO"
        case .DEBUG: output += "DEBUG"
        case .WARN: output += "WARN"
        case .ERROR: output += "ERROR"
        case .FATAL: output += "FATAL"
        }
        
        output += " \"" + message + "\""
        
        NSLog("%@", output)
    }
}