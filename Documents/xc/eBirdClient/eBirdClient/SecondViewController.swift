//
//  SecondViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

class SecondViewController: UITableViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, MapPointPickerDelegate, CompositePickerViewControllerDelegate {
    
    var cell2Selected: Bool = false;
    
    @IBOutlet var queryView: UITableView!
    @IBOutlet weak var cell1: UITableViewCell!
    @IBOutlet weak var cell2: UITableViewCell!
    @IBOutlet weak var cell3: UITableViewCell!
    
    @IBOutlet weak var cellAllSpecies: UITableViewCell!
    @IBOutlet weak var cellNotableSpecies: UITableViewCell!
    @IBOutlet weak var cellParticularSpecies: UITableViewCell!
    @IBOutlet weak var cellListOfSpecies: UITableViewCell!
    
    @IBOutlet weak var selectedSpeciesLabel: UILabel!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var milesKmSwitch: UISegmentedControl!
    @IBOutlet weak var radiusValueLabel: UILabel!
    @IBOutlet weak var mapPointPicker: MapPointPickerViewController!
    @IBOutlet weak var dateRangeSlider: UISlider!
    @IBOutlet weak var dateRangeLabel: UILabel!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    var queryType: eBirdQuery.queryType?
    var speciesType: eBirdQuery.speciesType?
    var selectedPoint: CLLocationCoordinate2D?;
    var currentLocation: CLLocationCoordinate2D?;
    var selectedSpecies: String?
    var locationManager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        showHideRadiusControls(false);
        
        cell1.selectionStyle = UITableViewCellSelectionStyle.None;
        cell2.selectionStyle = UITableViewCellSelectionStyle.None;
        cell3.selectionStyle = UITableViewCellSelectionStyle.None;
        
        cellAllSpecies.selectionStyle = UITableViewCellSelectionStyle.None;
        cellNotableSpecies.selectionStyle = UITableViewCellSelectionStyle.None;
        cellParticularSpecies.selectionStyle = UITableViewCellSelectionStyle.None;
        cellListOfSpecies.selectionStyle = UITableViewCellSelectionStyle.None;
        
        onRadiusChanged(radiusSlider);
        dateRangeSliderValueChanged(dateRangeSlider)
        locationManager = CLLocationManager();
        
        //self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var selected = queryView.cellForRowAtIndexPath(indexPath)
        selected!.selected = false
        if (indexPath.section == 0) {
            cell1.accessoryType =  UITableViewCellAccessoryType.None
            cell2.accessoryType =  UITableViewCellAccessoryType.None
            cell3.accessoryType =  UITableViewCellAccessoryType.None
            cell2Selected = (cell2 == selected!)
            
            switch selected! {
            case let cell where selected == cell1:
                self.queryType = eBirdQuery.queryType.MAPPOINT
            case let cell where selected == cell2:
                self.queryType = eBirdQuery.queryType.MAPPOINT;
            case let cell where selected == cell3:
                self.queryType = eBirdQuery.queryType.HOTSPOT; //fix
            default:
                self.queryType = eBirdQuery.queryType.HOTSPOT; //fix
            }
        }
        else if indexPath.section == 1 {
            
            switch selected! {
            case let cell where selected == cellAllSpecies:
                speciesType = eBirdQuery.speciesType.ALL;
        
            case let cell where selected == cellNotableSpecies:
                speciesType = eBirdQuery.speciesType.NOTABLE;
            case let cell where selected == cellParticularSpecies:
                speciesType = eBirdQuery.speciesType.LIST;
            case let cell where selected == cellListOfSpecies:
                speciesType = eBirdQuery.speciesType.LIST;
            default:
                speciesType = nil;
            }
            
            cellAllSpecies.accessoryType =  UITableViewCellAccessoryType.None
            cellNotableSpecies.accessoryType =  UITableViewCellAccessoryType.None
            cellParticularSpecies.accessoryType =  UITableViewCellAccessoryType.None
            cellListOfSpecies.accessoryType =  UITableViewCellAccessoryType.None
        }
        
        selected!.accessoryType =  UITableViewCellAccessoryType.Checkmark
        queryView.beginUpdates()
        showHideRadiusControls(cell2Selected)
        queryView.endUpdates()
    }

    override func viewWillAppear(animated: Bool) {
 //       self.navigationController?.setToolbarHidden(false, animated: true)
 //       self.navigationController?.setNavigationBarHidden(true, animated: true)
        setCurrentLocation();
    }
    
    @IBAction func onRadiusChanged(sender: AnyObject) {
        var slider = sender as? UISlider;
        if (slider != nil) {
            radiusValueLabel!.text = String(format: "%.0f", slider!.value)
        }
    }

    override func tableView(tableView:UITableView, heightForRowAtIndexPath indexPath:NSIndexPath) -> CGFloat {
    
        if (indexPath.section == 0) {
            if (indexPath.row == 0 && cell2Selected) {
                return  90;
            }
            else {
                return 40;
            }
        }
        else if (indexPath.section == 1) {
            return 40;
        }
        
        return 40;
    }

    
    func showHideRadiusControls(show: Bool) {
        if radiusSlider == nil {
            return;
        }
        var alpha:CGFloat = show ? 1.0 : 0.0;

        radiusSlider.alpha = alpha;
        radiusValueLabel.alpha = alpha;
        radiusLabel.alpha = alpha
        milesKmSwitch.alpha = alpha
    }

    func buildQueryData()-> eBirdQuery.queryData? {
        
        var qData: eBirdQuery.queryData?
        
        if (queryType == .MAPPOINT) {
            if (cell2Selected) {
                selectedPoint = currentLocation;
            }
            
            var lat:Double! = selectedPoint?.latitude
            var lng:Double! = selectedPoint?.longitude
            var pt = eBirdQuery.MapPoint(lng: lng, lat: lat)
            
            if (speciesType == .ALL || speciesType == .NOTABLE) {
                qData = eBirdQuery.queryData.MAP(coord: pt, radius: Int(radiusSlider.value), type: speciesType!, lookBackDays: Int(dateRangeSlider.value))
                return qData;
            }
            else if (speciesType == .LIST) {
                qData = eBirdQuery.queryData.MAP_SPECIES(coord: pt, radius: Int(radiusSlider.value), species: selectedSpecies!, lookBackDays: Int(dateRangeSlider.value))
                return qData;
                
            }
        }
        return nil;
    }
    
    @IBAction func didPressSearch(sender: AnyObject) {
        var appDel = (UIApplication.sharedApplication().delegate as AppDelegate)
        var resultsView = appDel.resultsViewController
        var query: eBirdQuery.queryData? = buildQueryData();
        if (query != nil) {
            resultsView?.setQueryToRun(query!);
            (UIApplication.sharedApplication().delegate as AppDelegate).activateResultsViewController();
        }
        else {
            // fail/error
        }
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "selectMapPoint") {
            var mppvc = segue.destinationViewController as? MapPointPickerViewController
            if mppvc != nil {
                mppvc?.delegate = self;
            }
        }
        else if (segue.identifier == "launchSpeciesPicker") {
            let dest = segue.destinationViewController as? CompositePickerViewController
            if dest != nil {
                dest!.delegate = self;
                dest!.rowTitles = eBirdSpeciesList
            }
        }
    }
    
    @IBAction func dateRangeSliderValueChanged(sender: AnyObject) {
        var slider = sender as? UISlider;
        if (slider != nil) {
            dateRangeLabel!.text = String(format: "%.0f", slider!.value)
        }
    }
    
    
    func onMapPointPickerCancel() {
        cell1.selected = false // not working as expected
        cell1.accessoryType = .None
    }
    
    func onMapPointPickerDone(selectedPoint: CLLocationCoordinate2D) {
        self.selectedPoint = selectedPoint;
        println("The selected point is \(selectedPoint.longitude), \(selectedPoint.latitude)")
    }
    
    func didSelectCompositePickerRow(rowId: String) {
        selectedSpecies = rowId;
        //selectedSpeciesLabel.text = "(" + rowId + ")"
        cellParticularSpecies.detailTextLabel?.text = "(" + rowId + ")"
    }
    
    func didPressCompositePickerCancel() {
        
    }
    
    func setCurrentLocation() {
        locationManager.delegate = self;
        if (!CLLocationManager.locationServicesEnabled()) {
            println("Location services are not enabled");
        }
    
        // should be in AppDelegate -- see http://stackoverflow.com/questions/24252645/how-to-get-location-user-whith-cllocationmanager-in-swift
        locationManager.requestWhenInUseAuthorization();
        locationManager.pausesLocationUpdatesAutomatically = false;
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func didPressSave(sender: AnyObject) {
        var alert = UIAlertController(title: "Save Query",
            message: "Enter a title for this query",
            preferredStyle: .Alert)
        
        let saveAction = UIAlertAction(title: "Save",
            style: .Default) { (action: UIAlertAction!) -> Void in
                
                let textField = alert.textFields![0] as UITextField
                var queryData = self.buildQueryData();
                
                theDataManager.saveAsManagedObject(query: queryData!, queryTitle: textField.text, app: (UIApplication.sharedApplication().delegate) as AppDelegate);
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
            style: .Default) { (action: UIAlertAction!) -> Void in
        }
        
        alert.addTextFieldWithConfigurationHandler {
            (textField: UITextField!) -> Void in
        }
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        presentViewController(alert,
            animated: true,
            completion: nil)
    }
    
    
    //-- CLLocationManagerDelegate functions
    
    func locationManager(locationManager:CLLocationManager, didUpdateLocations locations:[AnyObject]) {
        var myLoc: CLLocation! = locationManager.location;
        if (myLoc != nil) {
            currentLocation = myLoc!.coordinate
        }
        locationManager.stopUpdatingLocation();
    }
}

