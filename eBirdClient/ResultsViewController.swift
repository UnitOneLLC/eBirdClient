//
//  ResultsViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import UIKit
import MapKit


class ResultsViewController: UIViewController, eBirdQueryDelegate, UITableViewDelegate, UITableViewDataSource, ExpandableTableHeaderDelegate, ResultCellDelegate, LocationViewControllerDelegate {
    
    enum GroupingMode: Int { case DATE=0, LOCATION=1, SPECIES=2 }
    
    var queryResults : [eBirdSighting]?
    var groupingMode : GroupingMode = .DATE
    var groups: [[eBirdSighting]]?
    var headers: Dictionary<Int, ExpandableTableHeader>?
    var suppressReload: Bool = false;
    var currentDetailSighting: eBirdSightingDetail?
    var selectedAccessoryPath: NSIndexPath?
    var wikiScientificName: String?
    var headerExpansionVector: [Bool]?
    var autoHeaderExpandEnabled: Bool = false
    var scrollToIndexPath: NSIndexPath?
    var infoInProgressFlag: Int = 0
    
    let okColor: UIColor = UIColor(red: 0.25, green: 0.6, blue: 0.25, alpha: 1.0);
    let unverifiedColor: UIColor = UIColor.orangeColor()
    let rejectedColor: UIColor = UIColor.redColor();
    let localeString = NSLocale.currentLocale().localeIdentifier
    
    let HEADER_ROW_HEIGHT: Int = 35
    let BIT_NO: UInt32 = 7
    
    @IBOutlet weak var theTableView: UITableView!
    @IBOutlet weak var groupingSelector: UISegmentedControl!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var mapButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        theTableView.delegate = self;
        theTableView.dataSource = self;
        
        headers = Dictionary<Int, ExpandableTableHeader>();
    }
    
    override func viewDidAppear(animated: Bool) {
        if (suppressReload) {
            suppressReload = false;
            
            if (scrollToIndexPath != nil) {
                let ip : NSIndexPath! = NSIndexPath(forRow: scrollToIndexPath!.row, inSection: scrollToIndexPath!.section)
                scrollToIndexPath = nil
                theTableView.scrollToRowAtIndexPath(ip, atScrollPosition: UITableViewScrollPosition(rawValue: 0)!, animated: true)
            }
            
            if queryResults != nil && queryResults!.count > 0 {
                mapButton.enabled = true
            }
            
            
            return;
        }
        
        let appDel = (UIApplication.sharedApplication().delegate as! AppDelegate)
        if (appDel.queryToRun != nil) {
            theTableView.superview!.bringSubviewToFront(activityIndicatorView)
            activityIndicatorView.startAnimating()
            
            getGroupingModeFromControl()

            let queryToRun = eBirdQuery(locale: localeString, format: .JSON, maxResults: 500, includeProvisional: true);
            let url = queryToRun.buildQueryURL(appDel.queryToRun!, fullDetail: false)
            Logger.log(fromSource: self, level: .INFO, message: url!.absoluteString);
            if isInternetConnected() {
                queryToRun.runQuery(url!, delegate: self)
            }
        }
        else {
            if queryResults != nil && queryResults!.count > 0 {
                mapButton.enabled = true
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        activityIndicatorView.stopAnimating()
        
        let appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        if let alert = getAlertIfNoInternet()  {
            if appDel.countOfNetworkAlertsIssued++ < appDel.MAX_ALERTS {
                presentViewController(alert, animated: true, completion: nil)
            }
        }
        
        if let alert = getAlertIfNoLocationServices() {
            if appDel.countOfLocationAlertsIssued++ < appDel.MAX_ALERTS {
                presentViewController(alert, animated: true, completion: nil)
            }
        }
        
        mapButton.enabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // --- eBirdQueryDelegate methods --
    
    func querySucceeded(results: [eBirdSighting]) {
        activityIndicatorView.stopAnimating()
        
        queryResults = results
        mapButton.enabled = queryResults!.count > 0
        theTableView.reloadData()
        setUpGrouping(groupingMode)
    }
    
    func queryFailed() {
        activityIndicatorView.stopAnimating()
        simpleAlert("Network Error", message: "Unable to access sighting database", controller: self)
        Logger.log(fromSource: self, level: .ERROR, message: "query failed: )")
        
        // turn off busy indicator
    }
    func detailedSightingFound(sighting: eBirdSightingDetail) {
        displayDetails(sighting);
    }
    
    func detailedSightingError() {
        if selectedAccessoryPath != nil {
            let sighting = groups![selectedAccessoryPath!.section][selectedAccessoryPath!.row]
            var detailSighting = eBirdSightingDetail()
            detailSighting.basic = sighting;
            displayDetails(detailSighting);
        }
        else {
            OSAtomicTestAndClear(BIT_NO, &infoInProgressFlag)
        }
    }
    
    func displayDetails(sighting: eBirdSightingDetail) {
        suppressReload = true;
        currentDetailSighting = sighting
        dispatch_async(dispatch_get_main_queue(), {
            self.performSegueWithIdentifier("launchDetailsView", sender: self.theTableView);
        })
    }

    // -- UITableViewDelegate methods --
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let r = queryResults {

            if suppressReload && groups != nil && groups!.count == 1 && section == 0 {
                autoHeaderExpandEnabled = true
            }
            
            if groups == nil || groups!.count == 0 {
                return r.count;
            }
            else {

                if (section < groups!.count && (headerExpansionVector![section] ||
                    ((groups!.count == 1) && autoHeaderExpandEnabled))) {
                        autoHeaderExpandEnabled = false
                        return groups![section].count;
                }
                else {
                    return 0;
                }
            }
        }
        else {
            return 0
        }
        
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = theTableView.dequeueReusableCellWithIdentifier("ResultCell", forIndexPath: indexPath) as! ResultCell;
        
        cell.initialize()
        
        var sighting: eBirdSighting?
        
        if groups == nil {
            sighting = queryResults![indexPath.row];
        }
        else {
            sighting = groups![indexPath.section][indexPath.row];
        }
        
        let df: NSDateFormatter = NSDateFormatter();
        df.dateStyle = NSDateFormatterStyle.ShortStyle
        let dateString = df.stringFromDate(sighting!.date)
        
        cell.dateLabel.text = dateString
        cell.locationLabel.text = "\u{1f4cd}" + sighting!.locationName
        if sighting!.count != nil && sighting!.count > 1 {
            cell.speciesLabel.text = sighting!.commonName + " (" + String(sighting!.count!) + ")"
        }
        else {
            cell.speciesLabel.text = sighting!.commonName
        }
        cell.delegate = self;
        
        if sighting!.reviewed && !sighting!.validated {
            cell.speciesLabel.textColor = rejectedColor;
        }
        else if !sighting!.reviewed && !sighting!.validated {
            cell.speciesLabel.textColor = unverifiedColor
        }
        else if sighting!.validated {
            cell.speciesLabel.textColor = okColor
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if groups != nil && section == groups!.count {
            let rect = CGRect(x: 0.0, y: 0.0, width: tableView.frame.size.width, height: 30.0)
            let lbl = UILabel(frame: rect)
            lbl.font = UIFont.italicSystemFontOfSize(12.0)
            lbl.textAlignment = NSTextAlignment.Center
            lbl.textColor = UIColor.grayColor()
            
            let lblText = NSAttributedString(string: "Sighting data from eBird.org");

            
            lbl.attributedText = lblText
            
            return lbl
            
        }
        
        if headers != nil && headers![section] != nil {
            return headers![section]!
        }
        
        var text = ""
        if groups != nil {
            var name: String = ""
            switch groupingMode {
            case .SPECIES:
                name = groups![section][0].commonName;
            case .LOCATION:
                name = groups![section][0].locationName
            case .DATE:
                let df = NSDateFormatter()
                df.dateStyle = NSDateFormatterStyle.LongStyle;
                name = df.stringFromDate(groups![section][0].date)
            }

            let n = groups![section].count;
            
            text = name + " (" + String(n) + ")";
        }
        let expanded = groups == nil ? false : groups!.count == 1
        let view = ExpandableTableHeader(title: text, width: theTableView.frame.size.width, height: CGFloat(HEADER_ROW_HEIGHT), section: section, isExpanded: expanded);
        view.delegate = self;
        
        headers![section] = view;
        
        return view;
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        if ((groups == nil) || (groups!.count <= indexPath.section) || (groups![indexPath.section].count <= indexPath.row) ) {
            Logger.log(fromSource: self, level: .ERROR, message: "cannot find sighting for accessory tap")
            return;
        }
        
        if !OSAtomicTestAndSet(BIT_NO, &infoInProgressFlag) {
            let sighting = groups![indexPath.section][indexPath.row]
            selectedAccessoryPath = indexPath
            let queryToRun = eBirdQuery(locale: localeString, format: .JSON, maxResults: 250, includeProvisional: true);
            dispatch_async(dispatch_get_main_queue()) {
                self.activityIndicatorView.startAnimating()
            }

            queryToRun.findDetailedSighting(sighting, delegate: self)
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if groups == nil {
            return 1
        }
        else {
            return groups!.count + 1;
        }
    }
    
    @IBAction func didPressGroupingSelector(sender: AnyObject) {
        if (queryResults != nil && queryResults!.count != 0) {
            getGroupingModeFromControl();
            setUpGrouping(groupingMode);
        }
    }
    
    func getGroupingModeFromControl() {
        if (groupingSelector == nil) {
            return
        }
        let selected: Int? = groupingSelector!.selectedSegmentIndex;
        if (selected == nil) {
            return
        }
        else {
            switch selected! {
            case GroupingMode.SPECIES.rawValue:
                groupingMode = .SPECIES
            case GroupingMode.LOCATION.rawValue:
                groupingMode = .LOCATION
            case GroupingMode.DATE.rawValue:
                groupingMode = .DATE
            default:
                return;
            }
        }
    }
    
    func dayStringFromDate(date: NSDate) -> String {
        let desc = date.description;
        let range = Range<String.Index>(start: desc.startIndex, end: desc.startIndex.advancedBy(10))
        return desc.substringWithRange(range)
    }
    
    func locationStringFromSighting(s: eBirdSighting) -> String {
        if (s.locationName.characters.count > 0) {
            return s.locationName
        }
        else {
            return "(" + String(format: "%.4f", s.coordinates.lng) + ", " + String(format: "%.4f", s.coordinates.lat)
        }
    }

    func setUpGrouping(mode: GroupingMode ) {
        groups = [[eBirdSighting]]()
        groupingMode = mode

        switch mode {
        case .SPECIES:
            queryResults!.sortInPlace( { r1, r2 in
                return r1.commonName < r2.commonName;
            })

            var curGroup: [eBirdSighting]?
            var lastSeen = ""
            for sighting in queryResults! {
                if sighting.commonName != lastSeen {
                    if (curGroup != nil) {
                        groups!.append(curGroup!)
                    }
                    curGroup = [eBirdSighting]();
                }
                curGroup!.append(sighting);
                lastSeen = sighting.commonName
            }
            if (curGroup != nil) {
                groups!.append(curGroup!);
            }

            
        case .DATE:
            queryResults!.sortInPlace( { r1, r2 in
                return self.dayStringFromDate(r1.date) > self.dayStringFromDate(r2.date); // descending
            })
            
            var curGroup: [eBirdSighting]?
            var lastSeen = ""
            for sighting in queryResults! {
                let dayDateString = self.dayStringFromDate(sighting.date)
                if dayDateString != lastSeen {
                    if (curGroup != nil) {
                        groups!.append(curGroup!)
                    }
                    curGroup = [eBirdSighting]();
                }
                curGroup!.append(sighting);
                lastSeen = dayDateString
            }
            if (curGroup != nil) {
                groups!.append(curGroup!);
            }
            
        case .LOCATION:
            queryResults!.sortInPlace( { r1, r2 in
                return self.locationStringFromSighting(r1) < self.locationStringFromSighting(r2)
                })
            
            var curGroup: [eBirdSighting]?
            var lastSeen = ""
            for sighting in queryResults! {
                let locString = self.locationStringFromSighting(sighting)
                if locString != lastSeen {
                    if (curGroup != nil) {
                        groups!.append(curGroup!)
                    }
                    curGroup = [eBirdSighting]();
                }
                curGroup!.append(sighting);
                lastSeen = locString
            }
            if curGroup != nil {
                groups!.append(curGroup!);
            }
        }
        headers = Dictionary<Int, ExpandableTableHeader>();
        headerExpansionVector = [Bool](count: groups!.count, repeatedValue: false);
        autoHeaderExpandEnabled = true
        theTableView.reloadData()
        theTableView.setContentOffset(CGPointZero, animated: true) // scroll to top
    }
    
    // ExpandableTableHeaderDelegate
    func didRequestSectionExpansion(section: Int) {
        headerExpansionVector![section] = true
        
        if section < headers?.count {
            if let h = headers![section] {
                h.expanded = true
            }
        }
        
        let iSet = NSIndexSet(index: section);
        theTableView.reloadSections(iSet, withRowAnimation: UITableViewRowAnimation.Bottom)
    }
    func didRequestSectionCollapse(section: Int) {
        headerExpansionVector![section] = false
        
        if section < headers?.count {
            if let h = headers![section] {
                h.expanded = false
            }
        }
        
        let iSet = NSIndexSet(index: section);
        theTableView.reloadSections(iSet, withRowAnimation: UITableViewRowAnimation.Bottom)
    }

    //
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "sightingLocationSegue")   {
            let locationViewController = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? LocationViewController
            if locationViewController != nil && groups != nil {
                locationViewController!.delegate = self
                if sender is UITableViewCell {
                    let indexPath = theTableView.indexPathForCell(sender as! UITableViewCell)
                    if (groups != nil && indexPath != nil && indexPath!.section < groups!.count) {
                        let sighting: eBirdSighting = groups![indexPath!.section][indexPath!.row];
                        suppressReload = true;
                        locationViewController?.targets = [[sighting]]
                    }
                }
            }
        }
        else if (segue.identifier == "mapSightingLocationSegue") {
            let locationViewController = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? LocationViewController
            if locationViewController != nil && groups != nil {
                suppressReload = true
                locationViewController!.delegate = self
                groupingSelector.selectedSegmentIndex = 1
                groupingMode = .LOCATION
                setUpGrouping(.LOCATION)
                if groups != nil {
                    var targets : [[Locatable]] = [[Locatable]]()
                    for g in groups! {
                        var t = [Locatable]()
                        for sighting in g {
                            t.append(sighting)
                        }
                        targets.append(t)
                    }
                    locationViewController!.targets = targets
                }
            }
        }
        else if (segue.identifier == "launchDetailsView") {
            let detailsViewController = segue.destinationViewController as? DetailsViewController
            detailsViewController?.sighting = currentDetailSighting
            OSAtomicTestAndClear(BIT_NO, &infoInProgressFlag)
        }
            
        else if (segue.identifier == "launchWikiView") {
            let wikiViewController = segue.destinationViewController  as? WikiViewContoller
            wikiViewController?.speciesScientificName = self.wikiScientificName
            suppressReload = true
            dispatch_async(dispatch_get_main_queue(), {
                self.activityIndicatorView.startAnimating()
            })
        }
        
    }
    
    // ResultCellDelegate
    func resultCell(didTapLocation cell: UITableViewCell) {
        self.performSegueWithIdentifier("sightingLocationSegue", sender: cell)
    }
    
    func resultCell(didTapSpecies cell: UITableViewCell) {
        let indexPath = theTableView.indexPathForCell(cell)
        if (groups != nil && indexPath != nil && indexPath!.section < groups!.count) {
            let sighting: eBirdSighting = groups![indexPath!.section][indexPath!.row];
            self.wikiScientificName = sighting.scientificName
            self.performSegueWithIdentifier("launchWikiView", sender: cell)
        }
    }
    func resultCell(didTapDate cell: UITableViewCell) {}

    // LocationViewControllerDelegate
    func locationViewController(sender: LocationViewController, didSelectAnnotation selection: LocationViewController.Selection) {
    }
    
    func locationViewController(sender: LocationViewController, didTapOnAnnotationView selection: LocationViewController.Selection) {
        switch selection {
        case .SELECTED_GROUP(let group):
            var g: [Locatable] = group
            if let sighting = g[0] as? eBirdSighting {
                let locName = sighting.locationName
                var i: Int = 0
                for (i = 0; i < groups!.count; ++i) {
                    if groups![i].count > 0 {
                        let thisGroup = groups![i][0].locationName
                        if thisGroup == locName {
                            scrollToIndexPath = NSIndexPath(forRow: 0, inSection: i)
                            didRequestSectionExpansion(scrollToIndexPath!.section)
                        }
                    }
                }
            }
        default:
            break
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            sender.dismissViewControllerAnimated(true, completion: nil)
        })
    }
}




