//
//  HotspotCacheEntry.swift
//  BirdScene
//
//  Created by Fred Hewett on 1/27/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import CoreData

@objc(HotspotCacheEntry)
class HotspotCacheEntry: NSManagedObject, Printable {

    @NSManaged var lastHitDate: NSDate
    @NSManaged var creationDate: NSDate
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var items: NSSet

    override var description: String {
        get {
            return "HotspotCacheEntry: lastHitDate=\(lastHitDate) lat=\(latitude) lng=\(longitude) size=\(items.count)"
        }
    }
    
}
