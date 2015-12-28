//
//  MapPointPickerView.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/2/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import Foundation
import UIKit
import MapKit

protocol MapPointPickerDelegate {
    func mapPointPicker(mapPointPicker viewController: MapPointPickerViewController, didCancel: Bool )
    func mapPointPicker(mapPointPicker viewController: MapPointPickerViewController, pickedCoordinate coord: CLLocationCoordinate2D)
}

class MapPointPickerViewController : UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    
    var locationManager: CLLocationManager!
    var delegate: MapPointPickerDelegate?
    var initialPoint: CLLocationCoordinate2D?
    var selectedPoint: CLLocationCoordinate2D?
    
    @IBOutlet weak var mapView: MKMapView!
    override func viewDidLoad() {
        locationManager = CLLocationManager();

        super.viewDidLoad()
        
        locationManager!.delegate = self;
        if (!CLLocationManager.locationServicesEnabled()) {
            Logger.log(fromSource: self, level: .ERROR, message: "Location services are not enabled");
        }
        
        let singleTap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "didTapMap:")
        singleTap.delegate = self
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(singleTap)
        
        if initialPoint != nil {
            let span  = MKCoordinateSpanMake(4.0, 4.0);
            let region = MKCoordinateRegion(center: initialPoint!, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
//  not used
    func addRadiusCircle(location: CLLocation){
        self.mapView.delegate = self
        let circle = MKCircle(centerCoordinate: location.coordinate, radius: 10000 as CLLocationDistance)
        self.mapView.addOverlay(circle)
    }

    func didTapMap(recognizer: UITapGestureRecognizer) {
        let pt: CGPoint = recognizer.locationInView(mapView);
        let touchMapCoordinate = mapView.convertPoint(pt, toCoordinateFromView: mapView);

        mapView.addAnnotation(SelectPointAnnotation(coordinate: touchMapCoordinate, title: "", subtitle: ""));
        
        selectedPoint = touchMapCoordinate
        
        if delegate != nil {
            delegate?.mapPointPicker(mapPointPicker: self, pickedCoordinate: selectedPoint!)
        }
        _ = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("mapDone"), userInfo: nil, repeats: false)
    }
    func mapDone() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func didPressCancel(sender: AnyObject) {
        if delegate != nil {
            delegate?.mapPointPicker(mapPointPicker: self, didCancel: true)
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //-- MKMapView delegate

    func mapView(mapView: MKMapView,
        viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
            
            if annotation is MKUserLocation {
                //return nil so map view draws "blue dot" for standard user location
                return nil
            }
            
            let reuseId = "pin"
            
            var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
            if pinView == nil {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                pinView!.canShowCallout = true
                pinView!.animatesDrop = true
                pinView!.pinColor = .Red
            }
            else {
                pinView!.annotation = annotation
            }
            
            return pinView
    }
    
}