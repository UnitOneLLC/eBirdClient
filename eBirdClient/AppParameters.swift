//
//  AppParameters.swift
//  BirdScene
//
//  Created by Fred Hewett on 1/30/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import CoreData


@objc(AppParameters)
class AppParameters: NSManagedObject {

    @NSManaged var useMetricUnits: NSNumber

}
