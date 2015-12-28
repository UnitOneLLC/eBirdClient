//
//  LocationViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/12/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

protocol Locatable {
    var coordinate: CLLocationCoordinate2D { get }
    var caption: String { get }
    var subcaption: String { get }
}

protocol LocationViewControllerDelegate {
    func locationViewController(sender: LocationViewController, didSelectAnnotation selection: LocationViewController.Selection)
    func locationViewController(sender: LocationViewController, didTapOnAnnotationView selection: LocationViewController.Selection)
}

class LocationViewController: UIViewController, MKMapViewDelegate {
    
    class Wrapper : NSObject {
        init(_ t: Locatable) {
            single = t
        }
        init(_ g: [Locatable]) {
            group = g
        }
        
        var single: Locatable?
        var group: [Locatable]?

    }

    var delegate: LocationViewControllerDelegate?
    var targets: [[Locatable]]?;
    var dismissOnTapAnnotationView: Bool = true
    
    enum Selection {
        case SELECTED_GROUP(group: [Locatable])
        case SELECTED_TARGET(target: Locatable)
    }
    
    var selected: Selection?
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated);

        if targets == nil {
            return
        }

        if (targets!.count == 1 && targets![0].count == 1) {
            for target in targets![0] {
                let targetPoint = target.coordinate
                
                let span  = MKCoordinateSpanMake(0.4, 0.4);
                let region = MKCoordinateRegion(center: targetPoint, span: span)
                mapView.setRegion(region, animated: true)
                
                let annotation = SelectPointAnnotion(coordinate: targetPoint, title: target.caption, subtitle: target.subcaption)
                annotation.data = Wrapper(target)
                
                mapView.addAnnotation(annotation);
            }
        }
        else {
            var minLat: Double = 180.0, minLng: Double = 180.0, maxLat: Double = -180.0, maxLng = -180.0
            for group in targets! {
                if group.count >= 1 {
                    let target = group[0]
                    minLat = min(minLat, target.coordinate.latitude)
                    minLng = min(minLng, target.coordinate.longitude)
                    maxLat = max(maxLat, target.coordinate.latitude)
                    maxLng = max(maxLng, target.coordinate.longitude)
                }
            }
            
            
            let span = makeSpan(maxLat-minLat, lngDelta: maxLng-minLng, view: mapView.superview!)
            let center = CLLocationCoordinate2D(latitude: (minLat+maxLat)/2, longitude: (minLng+maxLng)/2)
            let region = MKCoordinateRegionMake(center, span)
            mapView.setRegion(region, animated: true)
            
            for group in targets! {
                if group.count > 0 {
                    let title = group[0].caption + " (\(group.count))"
                    var subcaption : String!
                    if group.count == 1 {
                        subcaption = group[0].subcaption
                    }
                    else {
                        subcaption = ""
                    }
                    let annotation = SelectPointAnnotion(coordinate: group[0].coordinate, title: title, subtitle: subcaption)
                    annotation.data = Wrapper(group)

                    mapView.addAnnotation(annotation);
                }
            }
        }
    }
    
    //-- MKMapView delegate
    
    func mapView(mapView: MKMapView!,
        viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
            
            if annotation is MKUserLocation {
                //return nil so map view draws "blue dot" for standard user location
                return nil
            }
            
            let reuseId = "pin"
            
            var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
            if pinView == nil {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                pinView!.canShowCallout = true
                pinView!.pinColor = .Red
                
                let tapper = UITapGestureRecognizer(target: self, action: "didTapAnnotationView:")
                pinView!.addGestureRecognizer(tapper)
            }
            else {
                pinView!.annotation = annotation
            }
            
            return pinView
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        println("didSelectAnnotationView sender is \(view))")
        selected = nil
        if let wrapper = (view.annotation as? SelectPointAnnotion)!.data as? Wrapper {
            if let g = wrapper.group {
                selected = Selection.SELECTED_GROUP(group: g)
            }
            else if let s = wrapper.single {
                selected = Selection.SELECTED_TARGET(target: s)
            }
        }
        
        if selected != nil && delegate != nil {
            delegate?.locationViewController(self, didSelectAnnotation: selected!)
        }
    }
    
    func didTapAnnotationView(sender: AnyObject) {
        println("didTapAnnotationView sender is \(sender))")
        if let tapper = sender as? UITapGestureRecognizer {
            if let view = tapper.view as? MKAnnotationView {
                if view.selected {
                    if selected != nil && delegate != nil {
                        delegate?.locationViewController(self, didTapOnAnnotationView: selected!)
                    }
                }
            }
        }
    }
    
    @IBAction func didPressDone(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func makeSpan(latDelta: Double, lngDelta: Double, view: UIView) -> MKCoordinateSpan {
        let frameHeight = view.frame.size.height
        let frameWidth = view.frame.size.width
        
        if frameHeight >= frameWidth {
            let aspect = Double(frameHeight/frameWidth)

            let latDelta2 = latDelta + Double(0.1)
            let lngDelta2 = (lngDelta + Double(0.1)) * aspect
            let span = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(latDelta2), longitudeDelta: CLLocationDegrees(lngDelta2))
            return span
        }
        else {
            let aspect = Double(frameWidth/frameHeight)

            let latDelta2 = (latDelta + Double(0.1)) * aspect
            let lngDelta2 = lngDelta + Double(0.1)
            let span = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(latDelta2), longitudeDelta: CLLocationDegrees(lngDelta2))
            return span
        }

    }
}
