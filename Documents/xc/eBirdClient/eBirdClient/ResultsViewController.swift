//
//  FirstViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 12/29/14.
//  Copyright (c) 2014 Appleton Software. All rights reserved.
//

import UIKit
import MapKit

protocol ExpandableTableHeaderDelegate {
    func didRequestSectionExpansion(section: Int)
    func didRequestSectionCollapse(section: Int)
}

class ExpandableTableHeader : UIView {
    var label: UILabel!
    var section: Int!
    var delegate: ExpandableTableHeaderDelegate?
    
    let CLOSED: Character = "\u{25b8}"
    let OPEN: Character = "\u{25be}"
    
    init(title: String, width: CGFloat, height: CGFloat, section: Int, isExpanded: Bool) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: height))
        self.section = section;
        label = UILabel(frame: CGRect(x: 10, y: 3, width: width, height: height))
        if (countElements(title) > 0) {
            label.text = (isExpanded ? String(OPEN) : String(CLOSED)) + "  " + title;
        }
        else {
            label.text = ""
        }
        label.font = UIFont.boldSystemFontOfSize(17.0)
        self.addSubview(label);
        self.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0);
        var tap = UITapGestureRecognizer(target: self, action: "didTapHeader:")
        self.addGestureRecognizer(tap)
    }
    
    var expanded: Bool {
        get {
            var first = Array(label.text!)[0];
            return first == OPEN;
        }
        set(value) {
            println("enter expand header arg=\(value) current is \(self.expanded)")
            //if (value != self.expanded) {
                var end = label.text!.startIndex.successor();
                var range = Range<String.Index>(start: label.text!.startIndex, end: end)
                
                if value {
                    label.text?.replaceRange(range, with: String(OPEN))
                }
                else {
                    label.text?.replaceRange(range, with: String(CLOSED));
                }
                
            //}
        }
    }
    
    
    @IBAction func didTapHeader(sender: AnyObject) {
        if (expanded) {
            if (delegate != nil) {
                delegate?.didRequestSectionCollapse(section)
            }
        }
        else {
            if (delegate != nil) {
                delegate?.didRequestSectionExpansion(section)
            }
        }
    }
    
    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
}


class ResultsViewController: UIViewController, eBirdQueryClient, UITableViewDelegate, UITableViewDataSource, ExpandableTableHeaderDelegate, ResultCellDelegate, LocationViewControllerDelegate {
    
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
    
    let okColor: UIColor = UIColor(red: 0.25, green: 0.6, blue: 0.25, alpha: 1.0);
    let unverifiedColor: UIColor = UIColor.orangeColor()
    let rejectedColor: UIColor = UIColor.redColor();
    
    let HEADER_ROW_HEIGHT: Int = 35
    
    @IBOutlet var theView: UITableView!
    @IBOutlet weak var groupingSelector: UISegmentedControl!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        theView.delegate = self;
        theView.dataSource = self;
        
        headers = Dictionary<Int, ExpandableTableHeader>();
    }
    
    override func viewDidAppear(animated: Bool) {
        if (suppressReload) {
            suppressReload = false;
            
            if (scrollToIndexPath != nil) {
                var ip : NSIndexPath! = NSIndexPath(forRow: scrollToIndexPath!.row, inSection: scrollToIndexPath!.section)
                scrollToIndexPath = nil
                theView.scrollToRowAtIndexPath(ip, atScrollPosition: UITableViewScrollPosition(rawValue: 0)!, animated: true)
            }
            
            return;
        }
        var appDel = (UIApplication.sharedApplication().delegate as AppDelegate)

        if (appDel.queryToRun != nil) {
            theView.superview!.bringSubviewToFront(activityIndicatorView)
            activityIndicatorView.startAnimating()
            
            getGroupingModeFromControl()
            // need to show busy indicator here!
            var queryToRun = eBirdQuery(locale: "en_us", format: .JSON, maxResults: 500, includeProvisional: true);
            var url = queryToRun.buildQueryURL(appDel.queryToRun!, fullDetail: false)
            println(url!.absoluteString);
            queryToRun.runQuery(url!, delegate: self)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        activityIndicatorView.stopAnimating()
        println("animation stopped 1")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // --- eBirdQueryClient methods --
    
    func querySucceeded(results: [eBirdSighting]) {
        activityIndicatorView.stopAnimating()
        println("animation stopped 2")
        
        queryResults = results
        theView.reloadData()
        self.setUpGrouping(groupingMode)
    }
    
    func queryFailed(error: NSError) {
        activityIndicatorView.stopAnimating()
        println("query failed: \(error.description)")
        
        // turn off busy indicator
    }
    func detailedSightingFound(sighting: eBirdSightingDetail) {
            self.displayDetails(sighting);
    }
    
    func detailedSightingError(error: NSError) {
        let dict = error.userInfo;
        let msg = dict!["message"] as String;
        println(" \(msg)");
        if selectedAccessoryPath != nil {
            let sighting = groups![selectedAccessoryPath!.section][selectedAccessoryPath!.row]
            var detailSighting = eBirdSightingDetail()
            detailSighting.basic = sighting;
            self.displayDetails(detailSighting);
        }
    }
    
    func displayDetails(sighting: eBirdSightingDetail) {
        suppressReload = true;
        currentDetailSighting = sighting
        dispatch_async(dispatch_get_main_queue(), {
            self.performSegueWithIdentifier("launchDetailsView", sender: self.theView);
        })
    }

    // -- UITableViewDelegate methods --
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let r = queryResults {
            if groups == nil || groups!.count == 0 {
                return r.count;
            }
            else {
                var h: ExpandableTableHeader! = headers![section];
                if (section < groups!.count && (headerExpansionVector![section] ||
                    ((countElements(groups!) == 1) && autoHeaderExpandEnabled))) {
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
        let cell = theView.dequeueReusableCellWithIdentifier("ResultCell", forIndexPath: indexPath) as ResultCell;
        
        cell.initialize()
        
        var sighting: eBirdSighting?
        
        if groups == nil {
            sighting = queryResults![indexPath.row];
        }
        else {
            sighting = groups![indexPath.section][indexPath.row];
        }
        
        var df: NSDateFormatter = NSDateFormatter();
        df.dateStyle = NSDateFormatterStyle.ShortStyle
        var dateString = df.stringFromDate(sighting!.date)
        
        cell.dateLabel.text = dateString
        cell.locationLabel.text = sighting!.locationName
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
        
        //cell.detailTextLabel?.text = sighting!.commonName + ", " + sighting!.locationName + ", " + dateString
        
        return cell
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if groups != nil && section == groups!.count {
            let rect = CGRect(x: 0.0, y: 0.0, width: tableView.frame.size.width, height: 30.0)
            let lbl = UILabel(frame: rect)
            lbl.font = UIFont.italicSystemFontOfSize(12.0)
            lbl.textAlignment = NSTextAlignment.Center
            lbl.textColor = UIColor.grayColor()
            
            var lblText = NSAttributedString(string: "Sighting data from eBird.org");

            
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
            default:
                break;
            }

            let n = groups![section].count;
            
            text = name + " (" + String(n) + ")";
        }
        let expanded = groups == nil ? false : countElements(groups!) == 1
        var view = ExpandableTableHeader(title: text, width: theView.frame.size.width, height: CGFloat(HEADER_ROW_HEIGHT), section: section, isExpanded: expanded);
        view.delegate = self;
        
        headers![section] = view;
        
        return view;
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        if ((groups == nil) || (groups!.count <= indexPath.section) || (groups![indexPath.section].count <= indexPath.row) ) {
            println("cannot find sighting for accessory tap")
            return;
        }
        let sighting = groups![indexPath.section][indexPath.row]
        selectedAccessoryPath = indexPath
        var queryToRun = eBirdQuery(locale: "en_us", format: .JSON, maxResults: 250, includeProvisional: true);

        queryToRun.findDetailedSighting(sighting, delegate: self) //optimize lookback
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
        var desc = date.description;
        var range = Range<String.Index>(start: desc.startIndex, end: advance(desc.startIndex, 10))
        return desc.substringWithRange(range)
    }
    
    func locationStringFromSighting(s: eBirdSighting) -> String {
        var result = ""
        if (countElements(s.locationName) > 0) {
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
            queryResults!.sort( { r1, r2 in
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
            queryResults!.sort( { r1, r2 in
                return self.dayStringFromDate(r1.date) > self.dayStringFromDate(r2.date); // descending
            })
            
            var curGroup: [eBirdSighting]?
            var lastSeen = ""
            for sighting in queryResults! {
                var dayDateString = self.dayStringFromDate(sighting.date)
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
            queryResults!.sort( { r1, r2 in
                return self.locationStringFromSighting(r1) < self.locationStringFromSighting(r2)
                })
            
            var curGroup: [eBirdSighting]?
            var lastSeen = ""
            for sighting in queryResults! {
                var locString = self.locationStringFromSighting(sighting)
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
        default:
            break;
        }
        headers = Dictionary<Int, ExpandableTableHeader>();
        headerExpansionVector = [Bool](count: groups!.count, repeatedValue: false);
        
        autoHeaderExpandEnabled = true
        theView.reloadData()
        theView.setContentOffset(CGPointZero, animated: true) // scroll to top
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
        theView.reloadSections(iSet, withRowAnimation: UITableViewRowAnimation.Bottom)
    }
    func didRequestSectionCollapse(section: Int) {
        headerExpansionVector![section] = false
        
        if section < headers?.count {
            if let h = headers![section] {
                h.expanded = false
            }
        }
        
        let iSet = NSIndexSet(index: section);
        theView.reloadSections(iSet, withRowAnimation: UITableViewRowAnimation.Bottom)
    }

    // ResultCellDelegate
    func didTapResultCellLocation(sender: UITableViewCell) {
        let indexPath = theView.indexPathForCell(sender as UITableViewCell)
        if (groups != nil && indexPath != nil && indexPath!.section < groups!.count) {
            let sighting: eBirdSighting = groups![indexPath!.section][indexPath!.row];
        }
        
        self.performSegueWithIdentifier("sightingLocationSegue", sender: sender)
    }
    
    func didTapResultCellSpecies(sender: UITableViewCell) {
        let indexPath = theView.indexPathForCell(sender as UITableViewCell)
        if (groups != nil && indexPath != nil && indexPath!.section < groups!.count) {
            let sighting: eBirdSighting = groups![indexPath!.section][indexPath!.row];
            self.wikiScientificName = sighting.scientificName
            self.performSegueWithIdentifier("launchWikiView", sender: sender)
        }
    }
    
    func didTapResultCellDate(sender: UITableViewCell) {
        
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "sightingLocationSegue")   {
            var locationViewController = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? LocationViewController
            if locationViewController != nil && groups != nil {
                locationViewController!.delegate = self
                if sender is UITableViewCell {
                    let indexPath = theView.indexPathForCell(sender as UITableViewCell)
                    if (groups != nil && indexPath != nil && indexPath!.section < groups!.count) {
                        let sighting: eBirdSighting = groups![indexPath!.section][indexPath!.row];
                        suppressReload = true;
                        let lat = sighting.coordinates.lat
                        let lng = sighting.coordinates.lng
                        println("\(lat)   \(lng)")
                        locationViewController?.targets = [[sighting]]
                    }
                }
            }
        }
        else if (segue.identifier == "mapSightingLocationSegue") {
            var locationViewController = (segue.destinationViewController as? UINavigationController)?.viewControllers[0] as? LocationViewController
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
            let navController = segue.destinationViewController as? UINavigationController
            let detailsViewController = navController?.viewControllers[0] as? DetailsViewController
            detailsViewController?.sighting = currentDetailSighting
            
            dispatch_async(dispatch_get_main_queue(), {
                println("STARTING activity (2)")
                self.activityIndicatorView.startAnimating()
            })

        }
        
        else if (segue.identifier == "launchWikiView") {
            let navController = segue.destinationViewController as? UINavigationController
            let wikiViewController = navController?.viewControllers[0]  as? WikiViewContoller
            wikiViewController?.speciesScientificName = self.wikiScientificName
            suppressReload = true
            dispatch_async(dispatch_get_main_queue(), {
                self.activityIndicatorView.startAnimating()
            })
        }
        
    }
    
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




