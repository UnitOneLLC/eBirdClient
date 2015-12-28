//
//  DataManager.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/9/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import CoreData


var theDataManager: DataManager! = DataManager();


class DataManager {
    
    init() {}
    
    func fetchAllQueryObjects(moc: NSManagedObjectContext!, inout error: NSError?) -> [Query]? {
        let ENTITY_NAME = "Query"
        let fetchRequest = NSFetchRequest(entityName: ENTITY_NAME)
        
        let fetchedResults =
            moc.executeFetchRequest(fetchRequest, error: &error) as [Query]?
        
        return fetchedResults
    }

    func fetchAllHotspotCacheEntryObjects(moc: NSManagedObjectContext!, inout error: NSError?) -> [HotspotCacheEntry]? {
        let ENTITY_NAME = "HotspotCacheEntry"
        let fetchRequest = NSFetchRequest(entityName: ENTITY_NAME)
        
        let fetchedResults = moc.executeFetchRequest(fetchRequest, error: &error) as [HotspotCacheEntry]?
        
        return fetchedResults
    }
    
    func fetchHotspotItemsForEntry(entry: HotspotCacheEntry, moc: NSManagedObjectContext, inout error: NSError?)->[HotspotItem]? {
        return nil
    }
    
    func saveAsManagedObject(query queryData: eBirdQuery.queryData, queryTitle: String, moc: NSManagedObjectContext) -> NSError? {
        let ENTITY_NAME = "Query"
        let entity =  NSEntityDescription.entityForName(ENTITY_NAME, inManagedObjectContext: moc)
        
        let newQuery = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_NAME, inManagedObjectContext: moc) as Query;
        newQuery.title = queryTitle
        initializeQuery(newQuery, fromData: queryData)

        var error: NSError?
        
        if !moc.save(&error) {
            println("Could not save \(error), \(error?.userInfo)")
        }
        
        return error
    }
    
    func saveAsManagedObject(cacheEntry entry: UnmanagedHotspotCacheEntry, moc: NSManagedObjectContext) -> NSError! {
        let ENTITY_NAME = "HotspotCacheEntry"
        let entity =  NSEntityDescription.entityForName(ENTITY_NAME, inManagedObjectContext: moc)
        
        let newEntry = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_NAME, inManagedObjectContext: moc) as HotspotCacheEntry;
        
        newEntry.latitude = entry.latitude
        newEntry.longitude = entry.longitude
        newEntry.creationDate = entry.creationDate
        newEntry.lastHitDate = entry.lastHitDate
        
        if entry.items != nil {
            var array = [HotspotItem]()
            
            for hs in entry.items! {
                let newItem = NSEntityDescription.insertNewObjectForEntityForName("HotspotItem", inManagedObjectContext: moc) as HotspotItem;
                newItem.id = hs.id
                newItem.name = hs.name
                newItem.longitude = hs.lng
                newItem.latitude = hs.lat
                newItem.cache = newEntry
                array.append(newItem)
            }
            
            newEntry.items = NSSet(array: array)
            
            var error: NSError?
            println("Saving \(newEntry.description)")
            if !moc.save(&error) {
                println("Could not save \(error), \(error?.userInfo)")
            }
            else {
                println("DataManager saved new hotspot cache entry")
            }
            
            return error
        }
        
        return NSError()
    }
    
    func initializeQuery(query: Query, fromData data: eBirdQuery.queryData) {
        switch data {
        case .MAP(let mapPoint, let radius, let type, let lookBackDays):
            query.locationType = "MAP"
            query.latitude = mapPoint.lat
            query.longitude = mapPoint.lng
            query.lookBackDays = lookBackDays
            query.radius = radius
            query.speciesType = getString(forSpeciesType: type)
            query.speciesList = "";
            query.hotspotId = ""
            
        case .MAP_SPECIES(let mapPoint, let radius, let species, let lookBackDays):
            query.locationType = "MAP_SPECIES"
            query.latitude = mapPoint.lat
            query.longitude = mapPoint.lng
            query.lookBackDays = lookBackDays
            query.radius = radius
            query.speciesType = "SPECIFIC"
            query.speciesList = species;
            query.hotspotId = ""
            
        case .HOTSPOT(let hotspotId, let type, let lookBackDays):
            query.locationType = "HOTSPOT"
            query.latitude = 0.0
            query.longitude = 0.0
            query.lookBackDays = lookBackDays
            query.radius = 0.0
            query.speciesType = getString(forSpeciesType: type)
            query.speciesList = ""
            query.hotspotId = hotspotId
            
        case .HOTSPOT_SPECIES(let hotspotId, let species, let lookBackDays):
            query.locationType = "HOTSPOT_SPECIES"
            query.latitude = 0.0
            query.longitude = 0.0
            query.lookBackDays = lookBackDays
            query.radius = 0.0
            query.speciesType = "SPECIFIC"
            query.speciesList = species
            query.hotspotId = hotspotId

        default:
            break;
        }
    }
    
    func getString(#forSpeciesType: eBirdQuery.speciesType) -> String {
        switch forSpeciesType {
        case .ALL: return "ALL"
        case .NOTABLE: return "NOTABLE"
        case .SPECIFIC: return "SPECIFIC"
        }
    }
    
    func getSpeciesType(#forString: String) -> eBirdQuery.speciesType? {
        switch forString {
        case "ALL": return .ALL;
        case "NOTABLE": return .NOTABLE;
        case "SPECIFIC": return .SPECIFIC;
        default:
            return nil;
        }
    }
    
    func getQueryData(fromManagedObject obj:Query) -> eBirdQuery.queryData? {
        var qData: eBirdQuery.queryData?
        
        switch obj.locationType {
        case "MAP":
            let coord = eBirdQuery.MapPoint(lng: obj.longitude.doubleValue, lat: obj.latitude.doubleValue)
            let radius = obj.radius.integerValue;
            let lookBack = obj.lookBackDays.integerValue;
            let speciesType = getSpeciesType(forString: obj.speciesType);
            qData = eBirdQuery.queryData.MAP(coord: coord, radius: radius, type: speciesType!, lookBackDays: lookBack);
            
        case "MAP_SPECIES":
            let coord = eBirdQuery.MapPoint(lng: obj.longitude.doubleValue, lat: obj.latitude.doubleValue)
            let radius = obj.radius.integerValue;
            let lookBack = obj.lookBackDays.integerValue;
            let speciesList = obj.speciesList;
            qData = eBirdQuery.queryData.MAP_SPECIES(coord: coord, radius: radius, species: speciesList, lookBackDays: lookBack);
            
        case "HOTSPOT":
            let lookBack = obj.lookBackDays.integerValue;
            let speciesType = getSpeciesType(forString: obj.speciesType);
            qData = eBirdQuery.queryData.HOTSPOT(obj.hotspotId, type: speciesType!, lookBackDays: lookBack)
 
        case "HOTSPOT_SPECIES":
            let lookBack = obj.lookBackDays.integerValue;
            let speciesType = getSpeciesType(forString: obj.speciesType);
            qData = eBirdQuery.queryData.HOTSPOT_SPECIES(obj.hotspotId, species: obj.speciesList, lookBackDays: lookBack)
            
        default:
            break;
        }
        
        return qData;
    }
    
    func deleteQueryObjectByTitle(moc: NSManagedObjectContext, title: String) -> NSError? {
        
        var error: NSError? = NSError(domain: "", code: 0, userInfo: Dictionary<NSObject, AnyObject>())
        let qs = fetchAllQueryObjects(moc, error: &error)
        

        for q in qs! {
            if (q.title == title) {
                moc.deleteObject(q)
                moc.save(NSErrorPointer())
                return nil
            }
        }
        
        
        return nil
    }
    
    
}
