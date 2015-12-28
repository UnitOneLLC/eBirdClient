//
//  Query.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/9/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import CoreData

@objc(Query)
class Query: NSManagedObject {

    @NSManaged var id: NSNumber
    @NSManaged var latitude: NSNumber
    @NSManaged var locationType: String
    @NSManaged var longitude: NSNumber
    @NSManaged var lookBackDays: NSNumber
    @NSManaged var radius: NSNumber
    @NSManaged var speciesList: String
    @NSManaged var speciesType: String
    @NSManaged var subtitle: String
    @NSManaged var title: String
    @NSManaged var hotspotId: String
}
