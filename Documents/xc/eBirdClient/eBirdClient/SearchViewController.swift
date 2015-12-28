//
//  SearchViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

class SearchViewController: UITableViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, MapPointPickerDelegate, CompositePickerViewControllerDelegate, eBirdHotspotManagerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UIGestureRecognizerDelegate {

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
    var currentlySelectedHotspot: Hotspot?
    var hotspotPickerCloseTapper: UITapGestureRecognizer?
    var hotspotPickerClearSelectionOnNextShow: Bool = false
    
    var savedRadiusSliderValue: Float?
    var geoCoder: CLGeocoder!
    var mapPointName: String?
    
    var cleanupTimer: NSTimer?
    var cleanupTimerCount: Int = 0
    
    let DEFAULT_ROW_HEIGHT: Double = 35.0;
    let EXPANDED_ROW_HEIGHT: Double = 80.0;
    let HOTSPOT_PICKER_ROW_HEIGHT: Double = 120.0;
    let PICKER_VIEW_ROW_HEIGHT: Double = 25.0
    
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
        distanceUnitsLabel.userInteractionEnabled = true
        var unitTap = UITapGestureRecognizer(target: self, action: "didTapDistanceUnitLabel:");
        distanceUnitsLabel.addGestureRecognizer(unitTap);
        distanceUnitsLabel.attributedText = getDistanceUnitsLabelAttributedString(distanceUnitsLabel.text!)

        if (distanceUnitsLabel.text == "miles") {
            unitMode = .MILES
        }
        else {
            unitMode = .KM
        }
    }
    
    func didTapDistanceUnitLabel(sender: AnyObject) {
        let current = distanceUnitsLabel.text
        var newText = current == "miles" ? "km" : "miles"
        distanceUnitsLabel.attributedText = getDistanceUnitsLabelAttributedString(newText);
        
        if current == "miles" {
            radiusSlider.maximumValue = 50.0
        }
        else {
             radiusSlider.maximumValue = 30.0
        }
        onRadiusChanged(radiusSlider);
    }
    
    func getDistanceUnitsLabelAttributedString(plain: String) -> NSAttributedString {
        var text : NSAttributedString = NSMutableAttributedString(string: plain, attributes : [
         //   NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
              NSForegroundColorAttributeName: (UIApplication.sharedApplication().delegate as AppDelegate).appClickableColor]
        );

        return text;
    }
    
    override func viewDidAppear(animated: Bool) {
        cleanUpSubtitles()
    }
    
    override func viewWillDisappear(animated: Bool) {
        showHotspotPicker(visible: false)
        
        var appDel = (UIApplication.sharedApplication().delegate as AppDelegate)
        var query: eBirdQuery.queryData? = buildQueryData();
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
        var selected = queryView.cellForRowAtIndexPath(indexPath)
        if (indexPath.section == 0) {
            currentLocSelected = (cellAtCurrentLoc == selected!)
            
            switch selected! {
            case let cell where selected == cellAtCurrentLoc:
                queryType = eBirdQuery.queryType.MAPPOINT;
                cellAtHotspot.selected = false
                cellAtMapPoint.selected = false
                showHotspotPicker(visible: false)
                enableDistanceSlider(true)
            case let cell where selected == cellAtMapPoint:
                queryType = eBirdQuery.queryType.MAPPOINT
                cellAtCurrentLoc.selected = false
                cellAtHotspot.selected = false
                enableDistanceSlider(true)
                showHotspotPicker(visible: false)
            case let cell where selected == cellAtHotspot:
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
            case let cell where selected == cellAllSpecies:
                speciesType = eBirdQuery.speciesType.ALL;
                cellNotableSpecies.selected = false
                cellParticularSpecies.selected = false
            case let cell where selected == cellNotableSpecies:
                speciesType = eBirdQuery.speciesType.NOTABLE;
                cellAllSpecies.selected = false
                cellParticularSpecies.selected = false
            case let cell where selected == cellParticularSpecies:
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
    }
    
    @IBAction func onRadiusChanged(sender: AnyObject) {
        var slider = sender as? UISlider;
        if (slider != nil) {
            radiusValueLabel!.text = String(format: "%.0f", slider!.value)
        }
    }

    func showPseudoDoneButton(#visible: Bool) {
        if (visible) {
            let blue = (UIApplication.sharedApplication().delegate as AppDelegate).appClickableColor;
            let range = NSMakeRange(30,4)
            var aText = NSMutableAttributedString(string: "At nearby birding hotspots    Done", attributes: nil)
            aText.addAttribute(NSForegroundColorAttributeName, value: blue, range: range)
            cellAtHotspot.textLabel!.attributedText = aText
            
            hotspotPickerCloseTapper = UITapGestureRecognizer(target: self, action: "didTapPseudoButton:")
            cellAtHotspot.textLabel?.addGestureRecognizer(hotspotPickerCloseTapper!);
        }
        else {
            var aText = NSMutableAttributedString(string: "At nearby birding hotspots", attributes: nil)
            cellAtHotspot.textLabel!.attributedText = aText
        }
    }
    
    func didTapPseudoButton(recognizer: UITapGestureRecognizer) {
        cellAtHotspot.textLabel!.removeGestureRecognizer(hotspotPickerCloseTapper!);
        showHotspotPicker(visible: false)
        if currentlySelectedHotspot != nil {
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
            
            var lat:Double! = selectedPoint?.latitude
            var lng:Double! = selectedPoint?.longitude
            var pt = eBirdQuery.MapPoint(lng: lng, lat: lat)
            
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
        else if (queryType == .HOTSPOT && currentlySelectedHotspot != nil) {
            if (speciesType == .ALL || speciesType == .NOTABLE) {
                qData = eBirdQuery.queryData.HOTSPOT(getSelectedHotspotNames(getIds: true), type: speciesType!, lookBackDays: Int(dateRangeSlider.value))
                return qData;
            }
            else if (speciesType == .SPECIFIC) {
                if (selectedSpecies != nil) {
                    qData = eBirdQuery.queryData.HOTSPOT_SPECIES(getSelectedHotspotNames(getIds: true), species: selectedSpecies!, lookBackDays: Int(dateRangeSlider.value))
                    return qData;
                }
            }
        }
        
        return nil;
    }
    
    @IBAction func didPressSearch(sender: AnyObject) {
        
        
        
        

        (UIApplication.sharedApplication().delegate as AppDelegate).activateResultsViewController();
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
            var mppvc = segue.destinationViewController as? MapPointPickerViewController
            if mppvc != nil {
                mppvc?.delegate = self;
                mppvc?.initialPoint = (selectedPoint != nil) ? selectedPoint : currentLocation
            }
        }
        else if (segue.identifier == "launchSpeciesPicker") {
            let dest = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? CompositePickerViewController
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
        cellAtMapPoint.selected = false // not working as expected
        cellAtMapPoint.accessoryType = .None
    }
    
    func onMapPointPickerDone(selectedPoint: CLLocationCoordinate2D) {
        self.selectedPoint = selectedPoint;
        self.enableDistanceSlider(true);
        
        setMapPointSubtitle(latitude: selectedPoint.latitude, longitude: selectedPoint.longitude);
    }

    func didSelectCompositePickerRow(rowId: String, sender: UIViewController) {
        if sender.title? == "Species Picker" {
            selectedSpecies = rowId;
            cellParticularSpecies.detailTextLabel!.text = rowId
            cleanUpSubtitles()
        }
    }
    
    func didMultiSelectCompositePickerRow(rowIds: [String], sender: UIViewController) {
        if sender.title? == "Hotspot Picker" {
            println("found \(rowIds.count)")
        }
    }
    
    
    func didPressCompositePickerCancel(#sender: UIViewController) {
    }
    
    func setCurrentLocation() {
        locationManager.delegate = self;
        if (!CLLocationManager.locationServicesEnabled()) {
            println("Location services are not enabled");
            return
        }
    
        // should be in AppDelegate -- see http://stackoverflow.com/questions/24252645/how-to-get-location-user-whith-cllocationmanager-in-swift
        locationManager.requestWhenInUseAuthorization();
        locationManager.pausesLocationUpdatesAutomatically = false;
        locationManager.startUpdatingLocation()
        
    }
    
    @IBAction func didPressSave(sender: AnyObject) {
        var alert = UIAlertController(title: "Save Search",
            message: "Enter a title for this search",
            preferredStyle: .Alert)
        
        let saveAction = UIAlertAction(title: "Save",
            style: .Default) { (action: UIAlertAction!) -> Void in
                
                let textField = alert.textFields![0] as UITextField
                var queryData = self.buildQueryData();
                
                if queryData != nil {
                    theDataManager.saveAsManagedObject(query: queryData!, queryTitle: textField.text, moc: ((UIApplication.sharedApplication().delegate) as AppDelegate).managedObjectContext!);
                }
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
    
    func hotspotLoadSuccess(list: [Hotspot]) {
        println("creating a new hotspot cache entry for current location with \(list.count) entries")
        HotspotCache.theHotspotCache.createHotspotCacheEntryForLocation(currentLocation!, hotspots: list)
        hotspotList = list;
        hotspotPickerRowSelection = [Bool]()
        
        hotspotPicker.reloadAllComponents()
    }

    func hotspotLoadFail(error: NSError) {
        println("ERROR: hotspots failed to load")
    }
    
    
    //-- CLLocationManagerDelegate functions

    func locationManager(locationManager:CLLocationManager, didUpdateLocations locations:[AnyObject]) {
        var myLoc: CLLocation! = locationManager.location;
        if (myLoc != nil) {
            currentLocation = myLoc!.coordinate
            let hsm = eBirdHotspotManager.theHotspotManager;
            
            if (!hotspotsLoaded) {
                var loadedFromCache = false
                
                if let spots = HotspotCache.theHotspotCache.getHotspotCacheEntryForLocation(currentLocation!, withinKm: 5) {
                    println("found hotspots in cache")
                    hotspotList = spots
                    hotspotsLoaded = true
                    hotspotPickerRowSelection = [Bool]()
                    hotspotPicker.reloadAllComponents()
                    
                }
                else {
                    println("did not find hotspots in cache")
                    hsm.loadHotspotsForGeo((lat: myLoc!.coordinate.latitude, lng: myLoc!.coordinate.longitude), delegate: self)
                    hotspotsLoaded = true;
                }
            }
            
            
        }
        println("updated location")
        locationManager.stopUpdatingLocation();
    }
    
    
    // HotspotPicker 
    
    
    func initHotspotPicker() {
        hotspotPickerVisible = false
        hotspotPicker.delegate = self
        hotspotPicker.dataSource = self
        var tapper = UITapGestureRecognizer(target: self, action: "didTapPickerCell:")
        tapper.delegate = self
        hotspotPicker.addGestureRecognizer(tapper)
    }
    
    func showHotspotPicker(#visible: Bool) {
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
            hotspotPicker.reloadAllComponents()
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
    
    func pickerView(pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusingView view: UIView!) -> UIView {
        
        var cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        cell.textLabel!.text = hotspotList![row].name
        cell.textLabel?.textAlignment = NSTextAlignment.Center
        
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
        
        return cell
    }
    
    @IBAction func didTapPickerCell(sender: AnyObject) {
        let timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("pickerSelect"), userInfo: nil, repeats: false)
    }
    
    func pickerSelect() {
        let row = self.hotspotPicker!.selectedRowInComponent(0);
        let state = hotspotPickerRowSelection![row]
        hotspotPickerRowSelection![row] = !state
        
        hotspotPicker.reloadAllComponents()
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
    }

    // picker view delegate
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentlySelectedHotspot = hotspotList![row];
    }

    func enableDistanceSlider(state: Bool) {
        if (state && !radiusSlider.enabled) {
            radiusSlider.enabled = true
            radiusSlider.minimumValue = 1.0
            radiusSlider.value = savedRadiusSliderValue!
            distanceUnitsLabel.textColor = (UIApplication.sharedApplication().delegate as AppDelegate).appClickableColor
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

    
    func setMapPointSubtitle(#latitude: Double, longitude: Double) {
        var mapLocation = CLLocation(latitude: latitude, longitude: longitude);
        geoCoder.reverseGeocodeLocation(mapLocation, completionHandler: {
            (placemarks, error) in
            let pm = placemarks as? [CLPlacemark]
            if (pm != nil && pm!.count > 0) {
                var p = placemarks[0] as? CLPlacemark
                self.mapPointName = "\(p!.name), \(p!.locality)"
                println(self.mapPointName!);
                self.cellAtMapPoint.detailTextLabel!.text = self.mapPointName;
                self.cleanUpSubtitles()
            }
        })
    }
    
    
    func restoreControlsForSavedQuery() {
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
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
        
        let ids = split(hotspotsCsv, {(c:Character)->Bool in return c==","}, allowEmptySlices: false)
        var hsm = eBirdHotspotManager.theHotspotManager;
        
        hotspotPickerRowSelection = [Bool](count: hotspotList!.count, repeatedValue: false)
        
        var subtitle = ""
        var count = 0
        for id in ids {
            if let hs = hsm.getHotspotById(id) {
                currentlySelectedHotspot = hs
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
    
    
    func restoreSliderState(#enableRadius: Bool, radiusKm: Int, lookBackDays: Int) {
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
    
}

