//
//  SearchViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

class SearchViewController: UITableViewController, CLLocationManagerDelegate, MapPointPickerDelegate, CompositePickerViewControllerDelegate, eBirdHotspotManagerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UIGestureRecognizerDelegate {

    enum DistanceUnitMode {
        case MILES
        case KM
    }
    
    var currentLocSelected: Bool = false;
    
    @IBOutlet var queryView: UITableView!
    
    @IBOutlet weak var cellAtCurrentLoc: UITableViewCell!
    @IBOutlet weak var cellAtMapPoint: UITableViewCell!
    @IBOutlet weak var cellAtHotspot: UITableViewCell!
    @IBOutlet weak var cellHotspotPicker: UITableViewCell!

    @IBOutlet weak var cellAllSpecies: UITableViewCell!
    @IBOutlet weak var cellNotableSpecies: UITableViewCell!
    @IBOutlet weak var cellParticularSpecies: UITableViewCell!
    
    @IBOutlet weak var selectedSpeciesLabel: UILabel!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var radiusValueLabel: UILabel!
    @IBOutlet weak var mapPointPicker: MapPointPickerViewController!
    @IBOutlet weak var dateRangeSlider: UISlider!
    @IBOutlet weak var dateRangeLabel: UILabel!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var distanceUnitsLabel: UILabel!
    @IBOutlet weak var hotspotPicker: UIPickerView!

    var queryType: eBirdQuery.queryType?
    var speciesType: eBirdQuery.speciesType?
    var selectedPoint: CLLocationCoordinate2D?;
    var currentLocation: CLLocationCoordinate2D?;
    var selectedSpecies: String?
    var locationManager: CLLocationManager!
    var unitMode: DistanceUnitMode!
    
    var hotspotsLoaded: Bool = false
    var hotspotPickerVisible: Bool = false
    var hotspotList: [Hotspot]?
    var hotspotPickerRowSelection: [Bool]?
    var currentlySelectedHotspotRow: Int?
    var hotspotPickerCloseTapper: UITapGestureRecognizer?
    var hotspotPickerClearSelectionOnNextShow: Bool = false
    
    var savedRadiusSliderValue: Float?
    var geoCoder: CLGeocoder!
    var mapPointName: String?
    var initialUseMetric: Bool?
    
    var cleanupTimer: NSTimer?
    var cleanupTimerCount: Int = 0
    
    let DEFAULT_ROW_HEIGHT: Double = 35.0;
    let EXPANDED_ROW_HEIGHT: Double = 80.0;
    let HOTSPOT_PICKER_ROW_HEIGHT: Double = 120.0;
    let PICKER_VIEW_ROW_HEIGHT: Double = 25.0
    let USE_METRIC_UNITS = "useMetricUnits"
    let HOTSPOT_TAP_QUEUE_NAME = "ebird_hotspot_tap_queue"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        geoCoder = CLGeocoder()
        locationManager = CLLocationManager();
        
        initDistanceUnitsLabel();
        
        onRadiusChanged(radiusSlider);
        dateRangeSliderValueChanged(dateRangeSlider)

        initHotspotPicker()
        clearSubtitles();

    }
    
    func initDistanceUnitsLabel() {
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        var n: NSNumber?
        n = theDataManager.getAppParameter(parameter: USE_METRIC_UNITS, moc: appDel.managedObjectContext!)
        initialUseMetric = n as? Bool
        
        distanceUnitsLabel.userInteractionEnabled = true
        let unitTap = UITapGestureRecognizer(target: self, action: "didTapDistanceUnitLabel:");
        distanceUnitsLabel.addGestureRecognizer(unitTap);
        
        if falsey(initialUseMetric) {
            distanceUnitsLabel.text = "miles"
            radiusSlider.maximumValue = 30.0
            unitMode = .MILES
        }
        else {
            distanceUnitsLabel.text = "km"
            radiusSlider.maximumValue = 50.0
            unitMode = .KM
        }
        
        distanceUnitsLabel.attributedText = getDistanceUnitsLabelAttributedString(distanceUnitsLabel.text!)
    }
    
    func didTapDistanceUnitLabel(sender: AnyObject) {
        let current = distanceUnitsLabel.text
        let newText = current == "miles" ? "km" : "miles"
        distanceUnitsLabel.attributedText = getDistanceUnitsLabelAttributedString(newText);

        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate

        if current == "miles" {
            radiusSlider.maximumValue = 50.0
            theDataManager.setAppParameter(parameter: USE_METRIC_UNITS, value: NSNumber(bool: true), moc: appDel.managedObjectContext!)
        }
        else {
            radiusSlider.maximumValue = 30.0
            theDataManager.setAppParameter(parameter: USE_METRIC_UNITS, value: NSNumber(bool: false), moc: appDel.managedObjectContext!)
        }
        onRadiusChanged(radiusSlider);
    }
    
    func getDistanceUnitsLabelAttributedString(plain: String) -> NSAttributedString {
        let text : NSAttributedString = NSMutableAttributedString(string: plain, attributes : [
         //   NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
              NSForegroundColorAttributeName: (UIApplication.sharedApplication().delegate as! AppDelegate).appClickableColor]
        );

        return text;
    }
    
    override func viewDidAppear(animated: Bool) {
        cleanUpSubtitles()
    }
    
    override func viewWillDisappear(animated: Bool) {
        if hotspotPickerVisible {
            didTapPseudoButton(nil)
        }
        
        let appDel = (UIApplication.sharedApplication().delegate as! AppDelegate)
        let query: eBirdQuery.queryData? = buildQueryData();
        if (query != nil) {
            appDel.queryToRun = query;
            hotspotPickerClearSelectionOnNextShow = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selected = queryView.cellForRowAtIndexPath(indexPath)
        if (indexPath.section == 0) {
            currentLocSelected = (cellAtCurrentLoc == selected!)
            
            switch selected! {
            case _ where selected == cellAtCurrentLoc:
                queryType = eBirdQuery.queryType.MAPPOINT;
                cellAtHotspot.selected = false
                cellAtMapPoint.selected = false
                showHotspotPicker(visible: false)
                enableDistanceSlider(true)
            case _ where selected == cellAtMapPoint:
                queryType = eBirdQuery.queryType.MAPPOINT
                cellAtCurrentLoc.selected = false
                cellAtHotspot.selected = false
                enableDistanceSlider(true)
                showHotspotPicker(visible: false)
            case _ where selected == cellAtHotspot:
                queryType = eBirdQuery.queryType.HOTSPOT;
                cellAtMapPoint.selected = false
                cellAtCurrentLoc.selected = false
                showHotspotPicker(visible: true);
                enableDistanceSlider(false)
            default:
                self.queryType = eBirdQuery.queryType.HOTSPOT; //fix
            }
        }
        else if indexPath.section == 1 {
            
            switch selected! {
            case _ where selected == cellAllSpecies:
                speciesType = eBirdQuery.speciesType.ALL;
                cellNotableSpecies.selected = false
                cellParticularSpecies.selected = false
            case _ where selected == cellNotableSpecies:
                speciesType = eBirdQuery.speciesType.NOTABLE;
                cellAllSpecies.selected = false
                cellParticularSpecies.selected = false
            case _ where selected == cellParticularSpecies:
                speciesType = eBirdQuery.speciesType.SPECIFIC;
                cellAllSpecies.selected = false
                cellNotableSpecies.selected = false
            default:
                speciesType = nil;
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        setCurrentLocation();
        restoreControlsForSavedQuery()
        
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        if let alert = getAlertIfNoInternet()  {
            if appDel.countOfNetworkAlertsIssued++ < appDel.MAX_ALERTS {
                presentViewController(alert, animated: true, completion: nil)
            }
        }
        
    }
    
    @IBAction func onRadiusChanged(sender: AnyObject) {
        let slider = sender as? UISlider;
        if (slider != nil) {
            radiusValueLabel!.text = String(format: "%.0f", slider!.value)
        }
    }

    func showPseudoDoneButton(visible visible: Bool) {
        if (visible) {
            let blue = (UIApplication.sharedApplication().delegate as! AppDelegate).appClickableColor;
            let range = NSMakeRange(30,4)
            let aText = NSMutableAttributedString(string: "At nearby birding hotspots    Done", attributes: nil)
            aText.addAttribute(NSForegroundColorAttributeName, value: blue, range: range)
            cellAtHotspot.textLabel!.attributedText = aText
            
            hotspotPickerCloseTapper = UITapGestureRecognizer(target: self, action: "didTapPseudoButton:")
            cellAtHotspot.textLabel?.addGestureRecognizer(hotspotPickerCloseTapper!);
        }
        else {
            let aText = NSMutableAttributedString(string: "At nearby birding hotspots", attributes: nil)
            cellAtHotspot.textLabel!.attributedText = aText
        }
    }
    
    func didTapPseudoButton(recognizer: AnyObject?) {
        cellAtHotspot.textLabel!.removeGestureRecognizer(hotspotPickerCloseTapper!);
        showHotspotPicker(visible: false)
        if currentlySelectedHotspotRow != nil {
            cellAtHotspot.detailTextLabel!.text = getSelectedHotspotNames()
            cleanUpSubtitles()
        }
    }
    
    func cleanUpSubtitles() {
        cleanupTimerCount = 0
        cleanupTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("cleanupDelegate"), userInfo: nil, repeats: true)
    }
    
    func cleanupDelegate() {
        cellAtHotspot.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
        cellAtHotspot.accessoryType = UITableViewCellAccessoryType.None
        
        cellAtMapPoint.accessoryType = UITableViewCellAccessoryType.None
        cellAtMapPoint.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator

        cellParticularSpecies.accessoryType = UITableViewCellAccessoryType.None
        cellParticularSpecies.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator

        cleanupTimerCount++
        if (cleanupTimerCount > 20) {
            dispatch_async(dispatch_get_main_queue(), {
                self.cleanupTimer!.invalidate()
            });
        }
    }
    
    func clearSubtitles() {
        cellAtMapPoint.detailTextLabel?.text = ""
        cellAtCurrentLoc.detailTextLabel?.text = ""
        cellAtHotspot.detailTextLabel?.text = ""

        cellAllSpecies.detailTextLabel?.text = ""
        cellNotableSpecies.detailTextLabel?.text = ""
        cellParticularSpecies.detailTextLabel?.text = ""
    }

    func buildQueryData()-> eBirdQuery.queryData? {
        
        var qData: eBirdQuery.queryData?
        
        if queryType == nil {
            tableView(tableView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 0))
            cellAtCurrentLoc.selected = true
        }
        if speciesType == nil {
            tableView(tableView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1))
            cellAllSpecies.selected = true
        }
        
        if (queryType == .MAPPOINT) {
            if (currentLocSelected) {
                selectedPoint = currentLocation;
            }
            
            if selectedPoint == nil {
                return nil
            }
            
            let lat:Double! = selectedPoint?.latitude
            let lng:Double! = selectedPoint?.longitude
            let pt = eBirdQuery.MapPoint(lng: lng, lat: lat)
            
            var distanceKm = Int(radiusSlider.value)
            if unitMode == .MILES {
                distanceKm = Int(Double(distanceKm) * 1.6)
            }
            
            if (speciesType == .ALL || speciesType == .NOTABLE) {
                qData = eBirdQuery.queryData.MAP(coord: pt, radius: distanceKm, type: speciesType!, lookBackDays: Int(dateRangeSlider.value))
                return qData;
            }
            else if (speciesType == .SPECIFIC) {
                if (selectedSpecies != nil) {
                    qData = eBirdQuery.queryData.MAP_SPECIES(coord: pt, radius: distanceKm, species: selectedSpecies!, lookBackDays: Int(dateRangeSlider.value))
                    return qData;
                }
                
            }
        }
        else if (queryType == .HOTSPOT && currentlySelectedHotspotRow != nil) {
            if (speciesType == .ALL || speciesType == .NOTABLE) {
                qData = eBirdQuery.queryData.HOTSPOT(getSelectedHotspotNames(true), type: speciesType!, lookBackDays: Int(dateRangeSlider.value))
                return qData;
            }
            else if (speciesType == .SPECIFIC) {
                if (selectedSpecies != nil) {
                    qData = eBirdQuery.queryData.HOTSPOT_SPECIES(getSelectedHotspotNames(true), species: selectedSpecies!, lookBackDays: Int(dateRangeSlider.value))
                    return qData;
                }
            }
        }
        
        return nil;
    }
    
    @IBAction func didPressSearch(sender: AnyObject) {
        (UIApplication.sharedApplication().delegate as! AppDelegate).activateResultsViewController();
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 2 && indexPath.row == 0 {
            return CGFloat(EXPANDED_ROW_HEIGHT)
        }
        else if indexPath.section == 0 && indexPath.row == 3 {
            if hotspotPickerVisible {
                return CGFloat(HOTSPOT_PICKER_ROW_HEIGHT)
            }
            else {
                return 1;
            }
        }
        else {
            return CGFloat(DEFAULT_ROW_HEIGHT)
        }
    }
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "selectMapPoint") {
            let mppvc = segue.destinationViewController as? MapPointPickerViewController
            if mppvc != nil {
                mppvc?.delegate = self;
                mppvc?.initialPoint = (selectedPoint != nil) ? selectedPoint : currentLocation
            }
        }
        else if (segue.identifier == "launchSpeciesPicker") {
            let dest = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? CompositePickerViewController
            if dest != nil {
                dest!.delegate = self;
                dest!.rowTitles = eBirdQuery.getSpeciesNames()
            }
        }
    }
    
    @IBAction func dateRangeSliderValueChanged(sender: AnyObject) {
        let slider = sender as? UISlider;
        if (slider != nil) {
            dateRangeLabel!.text = String(format: "%.0f", slider!.value)
        }
    }
    
    func mapPointPicker(mapPointPicker viewController: MapPointPickerViewController, didCancel: Bool ) {
        cellAtMapPoint.selected = false // not working as expected
    }
    
    func mapPointPicker(mapPointPicker viewController: MapPointPickerViewController, pickedCoordinate coord: CLLocationCoordinate2D) {
        selectedPoint = coord;
        enableDistanceSlider(true);
        
        setMapPointSubtitle(latitude: coord.latitude, longitude: coord.longitude);
    }

    
    
    func setCurrentLocation() {
        locationManager.delegate = self;
        if (!CLLocationManager.locationServicesEnabled()) {
            Logger.log(fromSource: self, level: .ERROR, message: "Location services are not enabled");
            return
        }
    
        // should be in AppDelegate -- see http://stackoverflow.com/questions/24252645/how-to-get-location-user-whith-cllocationmanager-in-swift
        locationManager.requestWhenInUseAuthorization();
        locationManager.pausesLocationUpdatesAutomatically = false;
        locationManager.startUpdatingLocation()
        
    }
    
    @IBAction func didPressSave(sender: AnyObject) {
        let alert = UIAlertController(title: "Save Search",
            message: "Enter a title for this search",
            preferredStyle: .Alert)
        
        let saveAction = UIAlertAction(title: "Save",
            style: .Default) { (action: UIAlertAction) -> Void in
                let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
                let textField = alert.textFields![0] as UITextField
                let queryData = self.buildQueryData();
                
                if queryData == nil {
                    simpleAlert("Warning", message: "You cannot save the current search", controller: self)
                }
                else if textField.text!.isEmpty {
                    simpleAlert("Warning", message: "Not saved \u{2013} no name supplied", controller: self)
                }
                else if theDataManager.savedQueryExists(name: textField.text!, moc: appDel.managedObjectContext!) {
                    simpleAlert("Warning", message: "Not saved \u{2013} you already have a search saved with the name \"\(textField.text)\"", controller: self)
                }
                else {
                    theDataManager.saveAsManagedObject(query: queryData!, queryTitle: textField.text!, moc: ((UIApplication.sharedApplication().delegate) as! AppDelegate).managedObjectContext!);
                }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
            style: .Default) { (action: UIAlertAction) -> Void in
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
    
    func hotspotLoadSuccess(list: [Hotspot]) {
        Logger.log(fromSource: self, level: .INFO, message: "creating a new hotspot cache entry for current location with \(list.count) entries")
        HotspotCache.theHotspotCache.createHotspotCacheEntryForLocation(currentLocation!, hotspots: list)
        hotspotList = list;
        hotspotPickerRowSelection = [Bool]()
        
        hotspotPicker.reloadAllComponents()
    }

    func hotspotLoadFail() {
        Logger.log(fromSource: self, level: .ERROR, message: "hotspots failed to load!")
    }
    
    
    //-- CLLocationManagerDelegate functions

    func locationManager(locationManager:CLLocationManager, didUpdateLocations locations:[CLLocation]) {
        let myLoc: CLLocation! = locationManager.location;
        if (myLoc != nil) {
            currentLocation = myLoc!.coordinate
            let hsm = eBirdHotspotManager.theHotspotManager;
            
            if (!hotspotsLoaded) {

                if let spots = HotspotCache.theHotspotCache.getHotspotCacheEntryForLocation(currentLocation!, withinKm: 5) {
                    Logger.log(fromSource: self, level: .INFO, message: "found hotspots in cache")
                    hotspotList = spots
                    hotspotsLoaded = true
                    hotspotPickerRowSelection = [Bool]()
                    hotspotPicker.reloadAllComponents()
                    
                }
                else {
                    Logger.log(fromSource: self, level: .INFO, message: "did not find hotspots in cache")
                    hsm.loadHotspotsForGeo((lat: myLoc!.coordinate.latitude, lng: myLoc!.coordinate.longitude), delegate: self)
                    hotspotsLoaded = true;
                }
            }
            
            
        }

        locationManager.stopUpdatingLocation();
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        if let alert = getAlertIfNoLocationServices() {
            if appDel.countOfLocationAlertsIssued++ < appDel.MAX_ALERTS {
                presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    // HotspotPicker 
    
    
    func initHotspotPicker() {
        hotspotPickerVisible = false
        hotspotPicker.delegate = self
        hotspotPicker.dataSource = self
        let tapper = UITapGestureRecognizer(target: self, action: "didTapPickerCell:")
        tapper.delegate = self
        hotspotPicker.addGestureRecognizer(tapper)
    }
    
    func showHotspotPicker(visible visible: Bool) {
        if hotspotPickerClearSelectionOnNextShow {
            hotspotPickerClearSelectionOnNextShow = false
            clearHotspotPickerSelection()
        }
        
        if visible && !hotspotPickerVisible {
            hotspotPickerVisible = true
            
            queryView.beginUpdates()
            
            cellHotspotPicker.hidden = false
            cellHotspotPicker.frame.size.height = CGFloat(HOTSPOT_PICKER_ROW_HEIGHT)
            dispatch_async(dispatch_get_main_queue(), {
                if (self.cellAtHotspot.detailTextLabel != nil) {
                    self.cellAtHotspot.detailTextLabel!.text = ""
                }
            })
            showPseudoDoneButton(visible: true)
            
            queryView.endUpdates();
        }
        else if !visible && hotspotPickerVisible {
            hotspotPickerVisible = false;
            
            queryView.beginUpdates()
            
            cellHotspotPicker.hidden = true
            cellHotspotPicker.frame.size.height = CGFloat(1.0);
            showPseudoDoneButton(visible: false)
            
            queryView.endUpdates();
        }
    }
    
    func getSelectedHotspotNames(getIds: Bool = false) -> String {
        if (!hotspotsLoaded || hotspotList == nil) {
            return ""
        }
        
        var result = ""
        for (var i=0; i < hotspotPickerRowSelection!.count; ++i) {
            if (hotspotPickerRowSelection![i]) {
                if !result.isEmpty {
                    result += ","
                }
                if (getIds) {
                    result += hotspotList![i].id
                }
                else {
                    result += hotspotList![i].name
                }
            }
        }
        
        return result
    }

    func clearHotspotPickerSelection() {
        if hotspotList != nil && hotspotList!.count > 0 {
            cellAtHotspot!.detailTextLabel!.text = ""
            hotspotPickerRowSelection = [Bool](count: hotspotList!.count, repeatedValue: false)
            dispatch_async(dispatch_get_main_queue()) {
                self.hotspotPicker.reloadAllComponents()
            }
        }
    }
    
    // picker view datasource
    
    // returns the number of 'columns' to display.
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // returns the # of rows in each component..
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if hotspotList != nil {
            return hotspotList!.count
        }
        else {
            return 0;
        }
    }
    
    func pickerView(pickerView: UIPickerView,rowHeightForComponent component: Int) -> CGFloat  {
        return CGFloat(PICKER_VIEW_ROW_HEIGHT)
    }
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView?) -> UIView {
        
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        cell.textLabel!.text = hotspotList![row].name
        cell.textLabel!.textAlignment = NSTextAlignment.Center
        
        if (row == hotspotPickerRowSelection!.count) {
            hotspotPickerRowSelection!.append(false)
            cell.accessoryType = UITableViewCellAccessoryType.None
        }
        else  {
            if (hotspotPickerRowSelection![row]) {
                cell.accessoryType = UITableViewCellAccessoryType.Checkmark
            }
            else {
                cell.accessoryType = UITableViewCellAccessoryType.None
            }
        }
        
        // add tap recognizer
        let tapper = UITapGestureRecognizer(target: self, action: "didTapPickerCell:")
        tapper.delegate = self
        cell.addGestureRecognizer(tapper)
        
        return cell
    }
    
    func indexForHotspotName(name: String) -> Int? {
        if hotspotList != nil {
            var counter = 0
            for hs in hotspotList! {
                if hs.name == name {
                    return counter
                }
                counter++
            }
        }
        return nil
    }
    
    
    var cancelPendingSelect = false
    
    @IBAction func didTapPickerCell(sender: AnyObject) {
        if let tapper = sender as? UITapGestureRecognizer {
            let point = tapper.locationInView(hotspotPicker);
            
            // determine if the tap was on the currently centered row
            // --- if it is call pickerSelect immediately
            let r = point.y/hotspotPicker.frame.height
            if 0.45 <= r  && r <= 0.55 {
                dispatch_async(dispatch_get_main_queue()) {
                    self.pickerSelect()
                }
            }
            else { // otherwise delay half a second
                cancelPendingSelect = false
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(500)*1000*1000), dispatch_get_main_queue()) {
                    if (!self.cancelPendingSelect) {
                        self.pickerSelect()
                    }
                }
            }
        }
    }

    func pickerSelect()->Void {
        cancelPendingSelect = true
        let row = hotspotPicker!.selectedRowInComponent(0);
        let state = hotspotPickerRowSelection![row]
        Logger.log(fromSource: self, level: .INFO, message: "In pickerSelect(), row=\(row) and state=\(state)")
        hotspotPickerRowSelection![row] = !state
        
        hotspotPicker.reloadAllComponents()
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
    }

    // picker view delegate
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentlySelectedHotspotRow = row;
        Logger.log(fromSource: self, level: .INFO, message: ("hotspot selection: " + String(row)))
    }

    func enableDistanceSlider(state: Bool) {
        if (state && !radiusSlider.enabled) {
            radiusSlider.enabled = true
            radiusSlider.minimumValue = 1.0
            radiusSlider.value = savedRadiusSliderValue!
            distanceUnitsLabel.textColor = (UIApplication.sharedApplication().delegate as! AppDelegate).appClickableColor
            radiusValueLabel.textColor = UIColor.blackColor()
            radiusLabel.textColor = UIColor.blackColor()
            onRadiusChanged(radiusSlider)
        }
        else if !state && radiusSlider.enabled {
            savedRadiusSliderValue = radiusSlider.value
            radiusSlider.enabled = false
            radiusSlider.minimumValue = 0.0
            radiusSlider.value = 0.0
            distanceUnitsLabel.textColor = UIColor.lightGrayColor()
            radiusValueLabel.textColor = UIColor.lightGrayColor()
            radiusLabel.textColor = UIColor.lightGrayColor()
            onRadiusChanged(radiusSlider)
        }
    }

    
    func setMapPointSubtitle(latitude latitude: Double, longitude: Double) {
        let mapLocation = CLLocation(latitude: latitude, longitude: longitude);
        geoCoder.reverseGeocodeLocation(mapLocation, completionHandler: {
            (placemarks, error) in
            let pm = placemarks! as [CLPlacemark]
            if (pm.count > 0) {
                let p = placemarks![0] as CLPlacemark
                self.mapPointName = "\(p.name!), \(p.locality!)"
                self.cellAtMapPoint.detailTextLabel!.text = self.mapPointName;
                self.cleanUpSubtitles()
            }
        })
    }
    
    
    func restoreControlsForSavedQuery() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        if (appDelegate.savedQueryWasRun != nil) {
            let savedQuery: eBirdQuery.queryData! = appDelegate.savedQueryWasRun
            appDelegate.savedQueryWasRun = nil
            
            switch savedQuery! {
            case .MAP(let coord, let radius, let speciesType, let lookBackDays) :
                cellAtMapPoint.selected = true
                tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 1, inSection: 0));
                
                selectedPoint = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
                setMapPointSubtitle(latitude: coord.lat, longitude: coord.lng)

                switch speciesType {
                case eBirdQuery.speciesType.ALL:
                    cellAllSpecies.selected = true
                    tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1));

                case eBirdQuery.speciesType.NOTABLE:
                    cellNotableSpecies.selected = true
                    tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 1, inSection: 1));
                    
                default:
                    break;
                }
                
                restoreSliderState(enableRadius: true, radiusKm: radius, lookBackDays: lookBackDays)
                
            case .MAP_SPECIES(let coord, let radius, let species, let lookBackDays):
                cellAtMapPoint.selected = true
                tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 1, inSection: 0));
                
                selectedPoint = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
                setMapPointSubtitle(latitude: coord.lat, longitude: coord.lng)
                
                tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 2, inSection: 1));
                selectedSpecies = species
                cellParticularSpecies.selected = true
                cellParticularSpecies.detailTextLabel!.text = species
                
                restoreSliderState(enableRadius: true, radiusKm: radius, lookBackDays: lookBackDays)
                
            case .HOTSPOT(let hotspots, let speciesType, let lookBackDays):
                cellAtHotspot.selected = true
                cellAtMapPoint.selected = false
                cellAtCurrentLoc.selected = false
                
                queryType = eBirdQuery.queryType.HOTSPOT;

                switch speciesType {
                case eBirdQuery.speciesType.ALL:
                    cellAllSpecies.selected = true
                    tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 0, inSection: 1));
                    
                case eBirdQuery.speciesType.NOTABLE:
                    cellNotableSpecies.selected = true
                    tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 1, inSection: 1));
                    
                default:
                    break
                }
                
                restoreHotspotState(hotspots)
                restoreSliderState(enableRadius: false, radiusKm: 0, lookBackDays: lookBackDays)
                
            case .HOTSPOT_SPECIES(let hotspots, let species, let lookBackDays):
                cellAtHotspot.selected = true
                cellAtMapPoint.selected = false
                cellAtCurrentLoc.selected = false
                
                queryType = eBirdQuery.queryType.HOTSPOT;
                
                selectedSpecies = species
                cellParticularSpecies.selected = true
                cellParticularSpecies.detailTextLabel!.text = species
                tableView(queryView, didSelectRowAtIndexPath: NSIndexPath(forRow: 2, inSection: 1));
                
                restoreHotspotState(hotspots)
                restoreSliderState(enableRadius: false, radiusKm: 0, lookBackDays: lookBackDays)
                
            default:
                break;
            }

        }
    }
    
    func restoreHotspotState(hotspotsCsv: String) {
        if hotspotList == nil {
            return
        }
        
        let ids = hotspotsCsv.componentsSeparatedByString(",").map { String($0) }
        let hsm = eBirdHotspotManager.theHotspotManager;
        
        hotspotPickerRowSelection = [Bool](count: hotspotList!.count, repeatedValue: false)
        
        var subtitle = ""
        var count = 0
        for id in ids {
            if let hs = hsm.getHotspotById(id) {
                currentlySelectedHotspotRow = count
                if !subtitle.isEmpty {
                    subtitle += ","
                }
                subtitle += hs.name
                
                hotspotPickerRowSelection![count] = true
                ++count
            }
        }
        if !subtitle.isEmpty {
            cellAtHotspot.detailTextLabel!.text = subtitle
            cleanUpSubtitles()
        }
    }
    
    
    func restoreSliderState(enableRadius enableRadius: Bool, radiusKm: Int, lookBackDays: Int) {
        if (enableRadius) {
            enableDistanceSlider(true)
            var r: Float = Float(radiusKm)
            if distanceUnitsLabel.text == "miles" {
                r /= 1.6
            }
            radiusSlider.value = r
            onRadiusChanged(radiusSlider)
        }
        else {
            enableDistanceSlider(false)
        }
        
        dateRangeSlider.value = Float(lookBackDays)
        dateRangeSliderValueChanged(dateRangeSlider)
    }
    
    // Composite Picker (species picker) delegate
    
    func compositePicker(picker view: CompositePickerViewController, didSelectRowWithTitle rowId: String) {
        if view.title != nil && view.title! == "Species Picker" {
            selectedSpecies = rowId;
            cellParticularSpecies.detailTextLabel!.text = rowId
            cleanUpSubtitles()
        }
    }
    func compositePicker(picker view: CompositePickerViewController, didSelectMultipleRows rowIds: [String]) {
    }
    func compositePicker(picker view: CompositePickerViewController, didCancel: Bool) {
    }
    
    
    
}

