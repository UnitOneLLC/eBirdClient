//
//  HotspotCache.swift
//  BirdScene
//
//  Created by Fred Hewett on 1/27/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import MapKit


struct UnmanagedHotspotCacheEntry {
    init() {
        creationDate = NSDate()
        lastHitDate = NSDate()
        latitude = 0.0
        longitude = 0.0
        items = nil
    }
    var creationDate: NSDate
    var lastHitDate: NSDate
    var latitude: NSNumber
    var longitude: NSNumber
    var items: [Hotspot]?
}


class HotspotCache {
    
    class var theHotspotCache: HotspotCache {
        struct Static {
            static var instance: HotspotCache?
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            Static.instance = HotspotCache()
        }
        
        return Static.instance!
    }
    
    let MAX_ENTRIES_IN_CACHE: Int = 4
    
    func assureCacheNotAtCapacity() {
        let appDel = UIApplication.sharedApplication().delegate as AppDelegate
        var error: NSError?
        let entries = theDataManager.fetchAllHotspotCacheEntryObjects(appDel.managedObjectContext, error: &error)

        if entries == nil {
            return
        }
        if entries!.count == MAX_ENTRIES_IN_CACHE {
            println("The HS cache is at capacity")
            var leastRecentlyUsed: HotspotCacheEntry? = nil
            var oldest = NSDate()
            for e in entries! {
                if e.lastHitDate.isBefore(oldest) {
                    leastRecentlyUsed = e
                    oldest = e.lastHitDate
                    println("new oldest entry updated to \(leastRecentlyUsed!.description)")
                }
            }
            if leastRecentlyUsed != nil {
                println("deleting entry from HS cache \(leastRecentlyUsed!.description)")
                appDel.managedObjectContext!.deleteObject(leastRecentlyUsed!)
            }
        }
    }
    
    func createHotspotCacheEntryForLocation(coordinates: CLLocationCoordinate2D, hotspots: [Hotspot]) -> NSError? {
        assureCacheNotAtCapacity()
        
        var entry = UnmanagedHotspotCacheEntry()
        entry.latitude = coordinates.latitude
        entry.longitude = coordinates.longitude
        entry.items = hotspots
        
        let appDel = UIApplication.sharedApplication().delegate as AppDelegate
        return theDataManager.saveAsManagedObject(cacheEntry: entry, moc: appDel.managedObjectContext!)
    }
    
    
    func getHotspotCacheEntryForLocation(coordinates: CLLocationCoordinate2D, withinKm: Double) -> [Hotspot]? {
        var error: NSError?
        let appDel = UIApplication.sharedApplication().delegate as AppDelegate
        println("Looking for cache entry at \(coordinates.latitude),\(coordinates.longitude)")
        if let entries = theDataManager.fetchAllHotspotCacheEntryObjects(appDel.managedObjectContext, error: &error) {

            println("There are \(entries.count) cache entries")
            var foundEntry: HotspotCacheEntry?
            var minDist = withinKm * 1000.0
            let point = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            for e in entries {
                let entryPoint = CLLocation(latitude: CLLocationDegrees(e.latitude), longitude: CLLocationDegrees(e.longitude))
                let thisDist = point.distanceFromLocation(entryPoint)
                if thisDist <= minDist {
                    foundEntry = e
                    minDist = thisDist
                    println("found close enough \(foundEntry!.lastHitDate)")
                }
            }
            if foundEntry != nil {
                println("Found a cache entry at distance \(minDist) \(foundEntry!.description)")
                foundEntry!.lastHitDate = NSDate()
                
                var hotspots = [Hotspot]()
                
                for item in foundEntry!.items {
                    var hs = Hotspot();
                    let managed = item as HotspotItem
                    hs.id = managed.id
                    hs.lat = managed.latitude.doubleValue
                    hs.lng = managed.longitude.doubleValue
                    hs.name = trim(string: managed.name)
                    
                    hotspots.append(hs)
                }
                hotspots.sort({(a, b)->Bool in return a.name < b.name})
                return hotspots
            }
        }

        return nil
    }
}