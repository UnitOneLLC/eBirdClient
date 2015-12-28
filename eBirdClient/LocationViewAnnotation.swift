//
//  LocationViewAnnotation.swift
//  BirdScene
//
//  Created by Fred Hewett on 1/29/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

class LocationViewAnnotation : MKPinAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier);
        setupDirectionButton()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    func setupDirectionButton() {
        let buttonRect = CGRect(x: 0.0, y: 0.0, width: 30.0, height: frame.height)
        let buttonView = UIButton(type: UIButtonType.System)
        buttonView.frame = buttonRect
        let image = UIImage(named: "directions.png") as UIImage?
        buttonView.setImage(image, forState: .Normal)
        
        if buttonView.imageView == nil {
            Logger.log(fromSource: self, level: .ERROR, message: "failed to set image")
        }

        buttonView.addTarget(self, action: "didPressDirections:", forControlEvents:.TouchUpInside)

        rightCalloutAccessoryView = buttonView
    }
    
    func didPressDirections(sender: AnyObject) {
        let placeMark = MKPlacemark(coordinate: annotation!.coordinate, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placeMark)
        mapItem.name = self.annotation!.title!
        let launchOptions = [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving]
        MKMapItem.openMapsWithItems([mapItem], launchOptions: launchOptions)
    }
    
}
