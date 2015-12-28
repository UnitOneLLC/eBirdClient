//
//  eBirdQuery.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import Foundation
import MapKit

struct eBirdSighting : Locatable, Equatable {
    var id: String
    var commonName: String
    var scientificName: String
    var date: NSDate
    var count: Int?
    var locationID: String
    var locationName: String
    var coordinates: (lng: Double, lat: Double)
    var reviewed: Bool
    var validated: Bool
    
    init() {
        id = ""
        commonName = "";
        scientificName = "";
        date = NSDate();
        count = 0;
        locationID = "";
        locationName = "";
        coordinates = (lng: 0, lat: 0)
        reviewed = false;
        validated = false;
    }
    
    
    // Locatable
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: coordinates.lat, longitude: coordinates.lng)
    }
    var caption: String {
        return locationName
    }
    var subcaption: String {
        return commonName
    }
}

// Equatable
func ==(lhs: eBirdSighting, rhs: eBirdSighting) -> Bool {

    if (rhs.id.characters.count > 0 && rhs.id == lhs.id) {
        return true;
    }
    if (rhs.locationID != lhs.locationID) {
        return false;
    }
    if (rhs.count != lhs.count) {
        return false;
    }
    if (rhs.date.compare(lhs.date) != NSComparisonResult.OrderedSame) {
        return false;
    }
    if (rhs.coordinates.lat != lhs.coordinates.lat) {
        return false;
    }
    if (rhs.coordinates.lng != lhs.coordinates.lng) {
        return false;
    }
    if (rhs.scientificName != lhs.scientificName) {
        return false;
    }
    
    return true;
}


struct eBirdSightingDetail  {
    var basic: eBirdSighting
    var userName: String
    var countryName: String
    var countryCode: String
    var subnational1Name: String
    var subnational2Name: String
    var presenceOnly: Bool

    init() {
        basic = eBirdSighting()
        userName = ""
        countryName = ""
        countryCode = ""
        subnational1Name = ""
        subnational2Name = ""
        presenceOnly = false
    }
}

typealias eBirdSpecies = (common_name: String, sci_name: String, taxon_id: String)
var eBirdSpeciesList: [eBirdSpecies?]?

protocol eBirdQueryDelegate {
    func querySucceeded(results: [eBirdSighting])
    func queryFailed()
    func detailedSightingFound(sighting: eBirdSightingDetail)
    func detailedSightingError()
}

class eBirdQuery : CustomStringConvertible {
    let API_VERSION = "1.1"
    
    enum formatType {
        case JSON
        case XML
    }
    
    enum queryType {
        case MAPPOINT
        case SUBNATIONAL1
        case SUBNATIONAL2
        case HOTSPOT
    }
    
    enum speciesType {
        case ALL
        case NOTABLE
        case SPECIFIC
    }
    
    typealias MapPoint = (lng:Double, lat:Double)
    
    enum queryData {

        case MAP(coord: MapPoint, radius: Int, type: speciesType, lookBackDays: Int)
        case MAP_SPECIES(coord: MapPoint, radius: Int, species: String, lookBackDays: Int)
        
        case HOTSPOT(String, type: speciesType, lookBackDays: Int)
        case HOTSPOT_SPECIES(String, species: String, lookBackDays: Int)
        
        case LOCATION(String, type: speciesType, lookBackDays: Int)
        case LOCATION_SPECIES(String, species: String, lookBackDays: Int)
        
        case NEAREST(MapPoint, speciesName: String)
    }
    
    var description : String { return "eBirdQuery" }
    
    var locale: String
    var format: formatType
    var maxResults: Int
    var includeProvisional : Bool
    
    init(locale: String, format: formatType, maxResults: Int, includeProvisional : Bool) {
        self.locale = locale
        self.format = format
        self.maxResults = maxResults
        self.includeProvisional = includeProvisional
    }
    
    class func getSpeciesNames() -> [String?] {
        var list = [String?](count: eBirdSpeciesList!.count, repeatedValue: nil)
        var counter = 0
        for tuple in eBirdSpeciesList! {
            if tuple != nil {
                list[counter++] = tuple!.common_name
            }
            else {
                break
            }
        }
        return list
    }
    
    class func lookupSpecies(name: String) -> eBirdSpecies? {
        for tuple in eBirdSpeciesList! {
            if (tuple != nil) && (tuple!.common_name == name) {
                return tuple
            }
        }
        
        return nil
    }
    
    func buildQueryURL(q:queryData, fullDetail: Bool) -> NSURL? {
        var url = "http://ebird.org/ws1.1/data/"
        switch q {
        case .MAP (let point, let radius, let type, let lookBackDays):
            
            if (type == speciesType.ALL) {
                url += "obs/"
            }
            else if (type == speciesType.NOTABLE) {
                url += "notable/"
            }
            else {
                return nil;
            }
            url += "geo/recent"
            url += "?lng=\(point.lng)&lat=\(point.lat)&dist=\(radius)&back=\(lookBackDays)"

            
        case .MAP_SPECIES(let point, let radius, let species, let lookBackDays):
            
            url += "obs/geo_spp/recent"
            url += "?lng=\(point.lng)&lat=\(point.lat)&dist=\(radius)&back=\(lookBackDays)"
            
            let bird = eBirdQuery.lookupSpecies(species);
            if (bird == nil) {
                return nil;
            }
            else {
                let sn : String = bird!.sci_name.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
                url += "&sci=\(sn)"
                
            }
            
        case .HOTSPOT(let hotspotId, let type, let lookBackDays):
            
            if (type == speciesType.ALL) {
                url += "obs/"
            }
            else if (type == speciesType.NOTABLE) {
                url += "notable/"
            }
            else {
                return nil;
            }
            url += "hotspot/recent"
            url += "?r=\(hotspotId)&back=\(lookBackDays)"
            
        case .HOTSPOT_SPECIES(let hotspotId, let speciesName, let lookBackDays):
            
            url += "obs/hotspot_spp/recent"
            url += "?r=\(hotspotId)&back=\(lookBackDays)"
            
            let bird = eBirdQuery.lookupSpecies(speciesName);
            if (bird == nil) {
                return nil;
            }
            else {
                let sn : String = bird!.sci_name.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
                url += "&sci=\(sn)"
            }
            
        case .NEAREST(let point, let sciName):
            let sn : String = sciName.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
            url += "nearest/geo_spp/recent?lng=\(point.lng)&lat=\(point.lat)&sci=\(sn)"
            
            
        default:
            return nil
        }

        url += "&maxResults=\(maxResults)&locale=\(locale)"
        if (format == formatType.XML) {
            url += "&fmt=xml"
        }
        else {
            url += "&fmt=json"
        }
        
        if includeProvisional {
            url += "&includeProvisional=true"
        }
        else {
            url += "&includeProvisional=false"
        }
        
        if fullDetail {
            url += "&detail=full"
        }
        
        return NSURL(string: url);
    }
    
    
    func populateSightingFromDictionary(dictionary: NSDictionary, inout sighting:eBirdSighting) {
        
        let formatterWithTime: NSDateFormatter = NSDateFormatter();
        formatterWithTime.dateFormat = "yyyy-MM-dd' 'HH:mm";
        let formatterWithoutTime: NSDateFormatter = NSDateFormatter();
        formatterWithoutTime.dateFormat = "yyyy-MM-dd";

        if let id = dictionary.valueForKey("obsID") as? String {
            sighting.id = id
        }
        if let cn = dictionary.valueForKey("comName") as? String {
            sighting.commonName = cn
        }
        if let sn = dictionary.valueForKey("sciName") as? String {
            sighting.scientificName = sn
        }
        if let dt = dictionary.valueForKey("obsDt") as? String {
            if dt.characters.count > 10 {
                sighting.date = formatterWithTime.dateFromString(dt)!;
            }
            else {
                sighting.date = formatterWithoutTime.dateFromString(dt)!;
            }
        }
        if let hm = dictionary.valueForKey("howMany") as? Int {
            sighting.count = hm
        }
        if let li = dictionary.valueForKey("locID") as? String {
            sighting.locationID = li;
        }
        if let ln = dictionary.valueForKey("locName") as? String {
            sighting.locationName = ln
        }
        if let lt = dictionary.valueForKey("lat") as? Double {
            sighting.coordinates.lat = lt
        }
        if let lo = dictionary.valueForKey("lng") as? Double {
            sighting.coordinates.lng = lo
        }
        if let or = dictionary.valueForKey("obsReviewed") as? Bool {
            sighting.reviewed = or
        }
        if let ov = dictionary.valueForKey("obsValid") as? Bool {
            sighting.validated = ov
        }
    }

    func populateDetailedSightingFromDictionary(dictionary: NSDictionary, inout sighting:eBirdSightingDetail) {
        
        self.populateSightingFromDictionary(dictionary, sighting: &sighting.basic)
        if let cc = dictionary.valueForKey("countryCode") as? String {
            sighting.countryCode = cc
        }
        if let cn = dictionary.valueForKey("countryName") as? String {
            sighting.countryName = cn
        }
        if let po = dictionary.valueForKey("presence") as? Bool {
            sighting.presenceOnly = po
        }
        if let s1n = dictionary.valueForKey("subnational1Name") as? String {
            sighting.subnational1Name = s1n
        }
        if let s2n = dictionary.valueForKey("subnational2Name") as? String {
            sighting.subnational2Name = s2n
        }
        if let un = dictionary.valueForKey("userDisplayName") as? String {
            sighting.userName = un
        }
    }
    
    func runQuery(requestURL: NSURL?, delegate: eBirdQueryDelegate)  {
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(requestURL!, completionHandler: {data, response, error -> Void in
            if error != nil {
                delegate.queryFailed();
                return;
            }
            
            let jsonResult : NSArray?  = try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as? NSArray
            
            if jsonResult == nil {
                // If there is an error parsing JSON, print it to the console
                Logger.log(fromSource: self, level: .ERROR, message: "JSON Error ")

                delegate.queryFailed()
                return;
            }
            
            var results: [eBirdSighting] = [eBirdSighting]();
            for resultItem in jsonResult! {
                var ebs: eBirdSighting = eBirdSighting();
                self.populateSightingFromDictionary(resultItem as! NSDictionary, sighting: &ebs)
                results.append(ebs);
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                delegate.querySucceeded(results)
            })
        })
        
        task.resume()
    }

    func computeLookBackDays(date: NSDate) -> Int {

        let startDate: NSDate = date
        let endDate: NSDate = NSDate()
        
        let cal = NSCalendar.currentCalendar()
        
        let components = cal.components(NSCalendarUnit.Day, fromDate: startDate, toDate: endDate, options: [])
        
        if components.day >= 30 {
            return 30;
        }
        else {
            return components.day + 1
        }
    }
    
    
    func findDetailedSighting(basic: eBirdSighting, delegate: eBirdQueryDelegate) {
        
        let lookBackDays = computeLookBackDays(basic.date);
        let sciName = basic.scientificName.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet());
        if (sciName == nil) {
            Logger.log(fromSource: self, level: .ERROR, message: "scientific name is invalid");
            delegate.detailedSightingError()
            return;
        }
        
        let url = "http://ebird.org/ws1.1/data/obs/loc_spp/recent?r=\(basic.locationID)&sci=\(sciName!)&detail=full&includeProvisional=true&fmt=json&back=\(lookBackDays)"
        let nsURL = NSURL(string: url)!

        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(nsURL, completionHandler: {data, response, error -> Void in
                if error != nil {
                    delegate.detailedSightingError();
                    return;
                }
            
            let jsonResult:NSArray? = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSArray
                
                if jsonResult == nil {
                    Logger.log(fromSource: self, level: .ERROR, message: "JSON Error )")
                    
                    delegate.detailedSightingError()
                    return;
                }
                
                for resultItem in jsonResult! {
                    let result: NSDictionary? = resultItem as? NSDictionary
                    if result != nil {
                        var current = eBirdSighting();
                        self.populateSightingFromDictionary(result!, sighting: &current)

                        if basic == current {
                            var detailedSighting: eBirdSightingDetail = eBirdSightingDetail()
                            self.populateDetailedSightingFromDictionary(result!, sighting: &detailedSighting)
                            delegate.detailedSightingFound(detailedSighting)
                            
                            return;
                        }
                    }
                }
                delegate.detailedSightingError()
        })
        task.resume()
    }
    
    class func initSpeciesList() {
        let MAX_SPECIES_COUNT: Int = 10500
        let startTime = NSDate()
        let speciesListPathName = "species-list-sorted";
        let path = NSBundle.mainBundle().pathForResource(speciesListPathName, ofType: "csv")
        if (path == nil) {
            Logger.log(fromSource: "eBirdQuery", level: .FATAL, message: "cannot find species list file: \(speciesListPathName).csv")
            return;
        }

        var counter: Int = 0
        if let reader = StreamReader(path: path!) {
            eBirdSpeciesList = [eBirdSpecies?](count: MAX_SPECIES_COUNT, repeatedValue: nil);
            
            while let line = reader.nextLine() {
                let parts = line.componentsSeparatedByString(",");
                let thisItem = (common_name: parts[0], sci_name: parts[1], taxon_id: parts[2])
                if counter < MAX_SPECIES_COUNT {
                    eBirdSpeciesList![counter++] = thisItem
                }
                else {
                    eBirdSpeciesList!.append(thisItem)
                }
            }
            reader.close();
            let delta = startTime.timeIntervalSinceNow
            Logger.log(fromSource: "eBirdQuery", level: .INFO, message: "Time to initialize species list = \(Double(delta)) sec")
        }
    }
    
    class func speciesInComponentSize(startChar: Character) -> Int {
        var counter = 0;
        var counting = false;
        
        if eBirdSpeciesList == nil {
            return 0
        }
        
        for sp in eBirdSpeciesList! {
            
            if ((sp != nil) && (Array((sp!.common_name).characters)[0]) == startChar) {
                counting = true;
                counter++;
            }
            else {
                if (counting) {
                    return counter;
                }
            }
        }
        return counter;
    }
    
    class func speciesInComponent(startChar: Character) -> [String] {
        var results = [String]();
        var counting = false;
        
        if eBirdSpeciesList != nil {
            for sp in eBirdSpeciesList! {
                
                if ((sp != nil) && (Array((sp!.common_name).characters))[0] == startChar) {
                    results.append(sp!.common_name);
                    counting = true;
                }
                else {
                    if (counting) {
                        return results;
                    }
                }
            }
        }
        
        return results;
    }
}

// --- Hotspot Manager ---

struct Hotspot {
    init() {
        id = ""
        lat = 0
        lng = 0
        name = ""
    }
    var id: String
    var lat: Double
    var lng: Double
    var name: String
}


protocol eBirdHotspotManagerDelegate {
    func hotspotLoadSuccess(_: [Hotspot])
    func hotspotLoadFail()
}

class eBirdHotspotManager : NSObject, NSXMLParserDelegate {
    var currentElement: String?
    var currentHotspotList: [Hotspot]?
    var currentHotspotLoc: eBirdQuery.MapPoint?
    var loadingInProgress: Bool = false
    var currentHotspot: Hotspot?
    var currentDelegate: eBirdHotspotManagerDelegate?

    class var theHotspotManager: eBirdHotspotManager {
        struct Static {
            static var instance: eBirdHotspotManager?
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            Static.instance = eBirdHotspotManager()
        }
        
        return Static.instance!
    }
    
    var hotspotTitles: [String] {
        var t = [String]()
        for hs in currentHotspotList! {
            t.append(hs.name)
        }
        
        return t;
    }
    
    func getHotspotById(id: String) -> Hotspot? {
        if currentHotspotList == nil {
            return nil
        }
        
        for hs in currentHotspotList! {
            if hs.id == id {
                return hs
            }
        }
        
        return nil
    }
  
    func loadHotspotsForGeo(geo: eBirdQuery.MapPoint, delegate: eBirdHotspotManagerDelegate) {
        
        if (loadingInProgress) {
            delegate.hotspotLoadFail();
            return
        }
        else {
            loadingInProgress = true
            currentDelegate = delegate
        }
        
        let url = "http://ebird.org/ws1.1/ref/hotspot/geo?lat=\(geo.lat)&lng=\(geo.lng)&back=30&dist=50&fmt=xml"
        let xmlParser = NSXMLParser(contentsOfURL: NSURL(string: url)!)
        xmlParser?.delegate = self

        currentHotspotLoc = geo;
        currentHotspotList = [Hotspot]();

        xmlParser!.parse()
        
    }
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName : String?, attributes attributeDict: [String : String]) {
        currentElement=elementName;

        if (currentElement == "location") {
            currentHotspot = Hotspot();
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        currentElement="";
        if (elementName == "location") {
            currentHotspotList?.append(currentHotspot!)
        }
        else if (elementName == "result") {
            currentDelegate?.hotspotLoadSuccess(currentHotspotList!)
        }
    }
    
    func parser(parser: NSXMLParser,foundCharacters string: String){
        
        switch currentElement {
        case _ where currentElement == "loc-id":      currentHotspot?.id = string
        case _ where currentElement == "loc-name":    currentHotspot?.name = string
        case _ where currentElement == "lat":         currentHotspot?.lat = (string as NSString).doubleValue
        case _ where currentElement == "lng":         currentHotspot?.lng = (string as NSString).doubleValue
            
        default:
            break;
        }
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        NSLog("failure error: %@", parseError)
    }
    

    
}

 