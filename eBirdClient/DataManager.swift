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


class DataManager : CustomStringConvertible {

    let ENTITY_APP_PARAMETERS = "AppParameters"
    let ENTITY_QUERY = "Query"
    let ENTITY_HOTSPOT_CACHE_ENTRY = "HotspotCacheEntry"
    let ENTITY_HOTSPOT_ITEM = "HotspotItem"
    
    init() {}
    
    var description : String { return "DataManager" }
    
    func fetchAllQueryObjects(moc: NSManagedObjectContext!) throws -> [Query] {

        let fetchRequest = NSFetchRequest(entityName: ENTITY_QUERY)
        
        let fetchedResults =
            try moc.executeFetchRequest(fetchRequest) as [AnyObject]?
        
        return fetchedResults as! [Query]
    }
    
    func savedQueryExists(name name: String, moc: NSManagedObjectContext) -> Bool {
        if name.isEmpty {
            return false
        }

        do {
            let queries = try fetchAllQueryObjects(moc)
            for q in queries {
                if q.title == name {
                    return true
                }
            }
        } catch _ as NSError {

        }
        return false
    }

    func fetchAllHotspotCacheEntryObjects(moc: NSManagedObjectContext!) throws -> [HotspotCacheEntry] {
        let fetchRequest = NSFetchRequest(entityName: ENTITY_HOTSPOT_CACHE_ENTRY)
        
        let fetchedResults = try moc.executeFetchRequest(fetchRequest)
        
        return fetchedResults as! [HotspotCacheEntry]
    }
    
    func fetchHotspotItemsForEntry(entry: HotspotCacheEntry, moc: NSManagedObjectContext) throws->[HotspotItem] {
        let error: NSError! = NSError(domain: "Migrator", code: 0, userInfo: nil)
        throw error
    }
    
    func saveAsManagedObject(query queryData: eBirdQuery.queryData, queryTitle: String, moc: NSManagedObjectContext) -> NSError? {

        let newQuery = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_QUERY, inManagedObjectContext: moc) as! Query;
        newQuery.title = queryTitle
        initializeQuery(newQuery, fromData: queryData)

        do {
            try moc.save()
        } catch let error as NSError {
            Logger.log(fromSource: self, level: .ERROR, message: "Could not save \(error), \(error.userInfo)")
            return error
        }
        
        return nil
    }
    
    func saveAsManagedObject(cacheEntry entry: UnmanagedHotspotCacheEntry, moc: NSManagedObjectContext) -> NSError? {
        let newEntry = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_HOTSPOT_CACHE_ENTRY, inManagedObjectContext: moc) as! HotspotCacheEntry;
        
        newEntry.latitude = entry.latitude
        newEntry.longitude = entry.longitude
        newEntry.creationDate = entry.creationDate
        newEntry.lastHitDate = entry.lastHitDate
        
        if entry.items != nil {
            var array = [HotspotItem]()
            
            for hs in entry.items! {
                let newItem = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_HOTSPOT_ITEM, inManagedObjectContext: moc) as! HotspotItem;
                newItem.id = hs.id
                newItem.name = hs.name
                newItem.longitude = hs.lng
                newItem.latitude = hs.lat
                newItem.cache = newEntry
                array.append(newItem)
            }
            
            newEntry.items = NSSet(array: array)
            
            do {
                try moc.save()
                Logger.log(fromSource: self, level: .INFO, message: "DataManager saved new hotspot cache entry")
            } catch let error as NSError {
                Logger.log(fromSource: self, level: .ERROR, message: "Could not save \(error), \(error.userInfo)")
                return error
            }
        }
        
        return nil
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
    
    func getString(forSpeciesType forSpeciesType: eBirdQuery.speciesType) -> String {
        switch forSpeciesType {
        case .ALL: return "ALL"
        case .NOTABLE: return "NOTABLE"
        case .SPECIFIC: return "SPECIFIC"
        }
    }
    
    func getSpeciesType(forString forString: String) -> eBirdQuery.speciesType? {
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
            qData = eBirdQuery.queryData.HOTSPOT_SPECIES(obj.hotspotId, species: obj.speciesList, lookBackDays: lookBack)
            
        default:
            break;
        }
        
        return qData;
    }
    
    func deleteQueryObjectByTitle(moc: NSManagedObjectContext, title: String) -> NSError? {
        
        var error: NSError? = NSError(domain: "", code: 0, userInfo: Dictionary<NSObject, AnyObject>())
        let qs: [Query]?
        do {
            qs = try fetchAllQueryObjects(moc)
        } catch let error1 as NSError {
            error = error1
            qs = nil
            return error
        }
        

        for q in qs! {
            if (q.title == title) {
                moc.deleteObject(q)
                do {
                    try moc.save()
                } catch let error as NSError {
                    NSErrorPointer().memory = error
                    return error
                }
                return nil
            }
        }
        
        
        return nil
    }
    
    func createInitialAppParametersObject(moc moc: NSManagedObjectContext) -> Bool {
        let newAP = NSEntityDescription.insertNewObjectForEntityForName(ENTITY_APP_PARAMETERS, inManagedObjectContext: moc) as! AppParameters;
        newAP.useMetricUnits = false
        do {
            try moc.save()
        } catch  {
            return false
        }
        return true
    }

    
    func getAppParameter<T: AnyObject>(parameter parameter: String, moc: NSManagedObjectContext) -> T? {

        let fetchRequest = NSFetchRequest(entityName: ENTITY_APP_PARAMETERS)
        let fetchedResults = try? moc.executeFetchRequest(fetchRequest)
        if (fetchedResults == nil) {
            Logger.log(fromSource: self, level: .ERROR, message: "failed to get app parameters")
        }
        else if fetchedResults!.count == 0 {
            if createInitialAppParametersObject(moc: moc) {
                return getAppParameter(parameter: parameter, moc: moc)
            }
        }

        let appParams = fetchedResults![0] as! AppParameters
        let retObj = appParams.valueForKey(parameter) as? NSObject
        if retObj == nil {
            return nil
        }
        else {
            return retObj as? T
        }
    }
    
    func setAppParameter<T: AnyObject>(parameter parameter: String, value: T, moc: NSManagedObjectContext) -> Bool {
        
        let fetchRequest = NSFetchRequest(entityName: ENTITY_APP_PARAMETERS)
        let fetchedResults = try? moc.executeFetchRequest(fetchRequest)
        if (fetchedResults == nil) {
            Logger.log(fromSource: self, level: .ERROR, message: "failed to get app parameters")
        }
        else if fetchedResults!.count == 0 {
            if createInitialAppParametersObject(moc: moc) {
                return setAppParameter(parameter: parameter, value: value, moc: moc)
            }
        }
        
        let appParams = fetchedResults![0] as! AppParameters
        appParams.setValue(value, forKey: parameter)
        
        do {
            try moc.save()
        } catch {
            return false
        }
        return true
    }
}
