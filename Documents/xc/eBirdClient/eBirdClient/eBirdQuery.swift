//
//  eBirdQuery.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import Foundation
import MapKit

struct eBirdSighting : Locatable {
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

var eBirdSpeciesLookup: Dictionary<String, (sci_name: String, taxon_id: String)>!
var eBirdSpeciesList: [String]!;


protocol eBirdQueryClient {
    func querySucceeded(results: [eBirdSighting])
    func queryFailed(error: NSError)
    func detailedSightingFound(sighting: eBirdSightingDetail)
    func detailedSightingError(error: NSError)
}

class eBirdQuery {
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
        
        case SUBNAT1(String, type: speciesType, lookBackDays: Int)
        case SUBNAT1_SPECIES(String, species: String, lookBackDays: Int)
        
        case SUBNAT2(String, String, type: speciesType, lookBackDays: Int)
        case SUBNAT2_SPECIES(String, String, species: String, lookBackDays: Int)
        
        case NEAREST(MapPoint, speciesName: String)        
    }
    
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
            
            var bird = eBirdSpeciesLookup[species];
            if (bird == nil) {
                return nil;
            }
            else {
                url += "&sci=\(bird!.sci_name.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)"
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
            
            var bird = eBirdSpeciesLookup[speciesName];
            if (bird == nil) {
                return nil;
            }
            else {
                url += "&sci=\(bird!.sci_name.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)"
            }
            
        case .NEAREST(let point, let sciName):
            url += "nearest/geo_spp/recent?lng=\(point.lng)&lat=\(point.lat)&sci=\(sciName.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)"
            
            
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
        var formatterWithTime: NSDateFormatter = NSDateFormatter();
        formatterWithTime.dateFormat = "yyyy-MM-dd' 'HH:mm";
        var formatterWithoutTime: NSDateFormatter = NSDateFormatter();
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
            if countElements(dt) > 10 {
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
    
    func runQuery(requestURL: NSURL?, delegate: eBirdQueryClient)  {
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(requestURL!, completionHandler: {data, response, error -> Void in
            if error != nil {
                delegate.queryFailed(error);
                return;
            }
            var err: NSError?
            
            var jsonResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: &err) as NSArray
            
            if err != nil {
                // If there is an error parsing JSON, print it to the console
                println("JSON Error \(err!.localizedDescription)")

                delegate.queryFailed(err!)
                return;
            }
            
            var results: [eBirdSighting] = [eBirdSighting]();
            for resultItem in jsonResult {
                var ebs: eBirdSighting = eBirdSighting();
                self.populateSightingFromDictionary(resultItem as NSDictionary, sighting: &ebs)
                results.append(ebs);
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                delegate.querySucceeded(results)
            })
        })
        
        task.resume()
    }

    func sightingsMatch(#first: eBirdSighting, second: eBirdSighting) -> Bool {
        if (countElements(first.id) > 0 && first.id == second.id) {
            return true;
        }
        if (first.locationID != second.locationID) {
            return false;
        }
        if (first.count != second.count) {
            return false;
        }
        if (first.date.compare(second.date) != NSComparisonResult.OrderedSame) {
            return false;
        }
        if (first.coordinates.lat != second.coordinates.lat) {
            return false;
        }
        if (first.coordinates.lng != second.coordinates.lng) {
            return false;
        }
        if (first.scientificName != second.scientificName) {
            return false;
        }
        
        return true;
    }

    func computeLookBackDays(date: NSDate) -> Int {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDate: NSDate = date
        let endDate: NSDate = NSDate()
        
        let cal = NSCalendar.currentCalendar()
        
        
        let unit:NSCalendarUnit = .DayCalendarUnit
        
        let components = cal.components(unit, fromDate: startDate, toDate: endDate, options: nil)
        
        if components.day >= 30 {
            return 30;
        }
        else {
            return components.day + 1
        }
    }
    
    
    func findDetailedSighting(basic: eBirdSighting, delegate: eBirdQueryClient) {
        let lookBackDays = computeLookBackDays(basic.date);
        var sciName = basic.scientificName.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding);
        if (sciName == nil) {
            println("sci name is invalid"); return;
        }
        var url = "http://ebird.org/ws1.1/data/obs/loc_spp/recent?r=\(basic.locationID)&sci=\(sciName!)&detail=full&includeProvisional=true&fmt=json&back=\(lookBackDays)"
        var nsURL = NSURL(string: url)!

        println("DETAIL URL=\(nsURL.absoluteString)");
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithURL(nsURL, completionHandler: {data, response, error -> Void in
                if error != nil {
                    delegate.detailedSightingError(error);
                    return;
                }
                var err: NSError?
                
                var jsonResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: &err) as NSArray
                
                if err != nil {
                    // If there is an error parsing JSON, print it to the console
                    println("JSON Error \(err!.localizedDescription)")
                    
                    delegate.detailedSightingError(err!)
                    return;
                }
                
                for resultItem in jsonResult {
                    let result: NSDictionary? = resultItem as? NSDictionary
                    if result != nil {
                        var current = eBirdSighting();
                        self.populateSightingFromDictionary(result!, sighting: &current)

                        if self.sightingsMatch(first: basic, second: current){
                            var detailedSighting: eBirdSightingDetail = eBirdSightingDetail()
                            self.populateDetailedSightingFromDictionary(result!, sighting: &detailedSighting)
                            delegate.detailedSightingFound(detailedSighting)
                            
                            return;
                        }
                    }
                }
                delegate.detailedSightingError(NSError(domain: "eBird", code: 404, userInfo: ["message": "Sighting was not found (\(jsonResult.count) sightings checked)."] ))
        })
        task.resume()
    }
    
    class func initSpeciesList() {
        let speciesListPathName = "ebird_api_ref_taxa_eBird";
        let path = NSBundle.mainBundle().pathForResource(speciesListPathName, ofType: "csv")
        if (path == nil) {
            println("cannot find species list file: \(speciesListPathName).csv")
            return;
        }
        
        var counter: Int = 0;
        if let reader = StreamReader(path: path!) {
            
            eBirdSpeciesLookup = Dictionary<String, (sci_name: String, taxon_id: String)>();
            eBirdSpeciesList = [String]();
            
            while let line = reader.nextLine() {
                let parts = line.componentsSeparatedByString(",");
                eBirdSpeciesList.append(parts[1]);
                eBirdSpeciesLookup[parts[1]] = (sci_name: parts[0], taxon_id: parts[2]);
                counter++;
            }
            reader.close();
            eBirdSpeciesList.sort( {(a:String, b:String) in a < b} )
        }
    }
    
    class func speciesInComponentSize(startChar: Character) -> Int {
        var counter = 0;
        var counting = false;
        
        for sp in eBirdSpeciesList {
            
            if ((Array(sp)[0]) == startChar) {
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
        
        for sp:String in eBirdSpeciesList {
            
            if ((Array(sp))[0] == startChar) {
                results.append(sp);
                counting = true;
            }
            else {
                if (counting) {
                    return results;
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
    func hotspotLoadSuccess([Hotspot])
    func hotspotLoadFail(error: NSError)
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
            delegate.hotspotLoadFail(NSError());
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
    func parser(parser: NSXMLParser!,didStartElement elementName: String!, namespaceURI: String!, qualifiedName : String!, attributes attributeDict: NSDictionary!) {
        currentElement=elementName;

        if (currentElement == "location") {
            currentHotspot = Hotspot();
        }
    }
    
    func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!) {
        currentElement="";
        if (elementName == "location") {
            currentHotspotList?.append(currentHotspot!)
        }
        else if (elementName == "result") {
            currentDelegate?.hotspotLoadSuccess(currentHotspotList!)
        }
    }
    
    func parser(parser: NSXMLParser!, foundCharacters string: String!) {
        
        switch currentElement {
        case let _ where currentElement == "loc-id":      currentHotspot?.id = string
        case let _ where currentElement == "loc-name":    currentHotspot?.name = string
        case let _ where currentElement == "lat":         currentHotspot?.lat = (string as NSString).doubleValue
        case let _ where currentElement == "lng":         currentHotspot?.lng = (string as NSString).doubleValue
            
        default:
            break;
        }
    }
    
    func parser(parser: NSXMLParser!, parseErrorOccurred parseError: NSError!) {
        NSLog("failure error: %@", parseError)
    }
    

    
}

 