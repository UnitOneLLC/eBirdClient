//
//  HotspotItem.swift
//  BirdScene
//
//  Created by Fred Hewett on 1/27/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import CoreData

@objc(HotspotItem)
class HotspotItem: NSManagedObject {

    @NSManaged var id: String
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var name: String
    @NSManaged var cache: HotspotCacheEntry

}
