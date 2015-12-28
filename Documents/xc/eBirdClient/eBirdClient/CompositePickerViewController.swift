//
//  CompositePickerViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/7/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

protocol CompositePickerViewControllerDelegate {
    func didSelectCompositePickerRow(rowId: String, sender: UIViewController)
    func didMultiSelectCompositePickerRow(rowIds: [String], sender: UIViewController)
    func didPressCompositePickerCancel(#sender: UIViewController)
}

class CompositePickerViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {

    var delegate: CompositePickerViewControllerDelegate?
    var rowTitles: [String]?
    var maxEntriesToShowInTable = 250;
    
    var filteredRows: [String]?
    
    @IBOutlet weak var textInput: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self;
        tableView.delegate = self;
        textInput.becomeFirstResponder();
        textInput.autocorrectionType = UITextAutocorrectionType.No
        
        var attrStr: NSAttributedString = NSAttributedString(string: "Begin typing species name", attributes: [
            NSForegroundColorAttributeName: UIColor.lightGrayColor()
        ])
        textInput.attributedPlaceholder = attrStr
    }
    
    override func viewWillAppear(animated: Bool) {
        if rowTitles != nil && rowTitles!.count < maxEntriesToShowInTable {
            filteredRows = rowTitles
            tableView.reloadData()
        }
    }

    @IBAction func textFieldDidChange(sender: AnyObject) {
        if countElements(textInput.text) > 0 {
            filteredRows = filter(rowTitles!, mustContain: textInput.text);
            if (countElements(filteredRows!) <= maxEntriesToShowInTable) {
                tableView.reloadData();
            }
        }
    }
    
    func filter(stringSet: [String], mustContain: String) -> [String] {
        var result = [String]();
        
        for s in stringSet {
            if s.lowercaseString.rangeOfString(mustContain.lowercaseString) != nil {
                result.append(s);
            }
        }
        
        return result;
    }
    
    
    // table view
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if rowTitles != nil {
            return countElements(rowTitles!)
        }
        else {
            return 0;
        }
    }
    
    // Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    // Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "reuse-me")
        
        if (filteredRows != nil && indexPath.row < countElements(filteredRows!)) {
            cell.textLabel?.text = filteredRows?[indexPath.row];
        }
        
        return cell;
    }

    func findCellForTitle(title: String) -> UITableViewCell? {
        var cell: UITableViewCell?
        
        for (var i=0; i < filteredRows!.count; ++i) {
            
            if filteredRows![i] == title {
                let path = NSIndexPath(forRow: i, inSection: 0)
                return tableView.cellForRowAtIndexPath(path);
            }
        }
        return nil;
    }

    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        delegate?.didSelectCompositePickerRow(filteredRows![indexPath.row], sender: self);
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        // handle deselect here
    }
    
    @IBAction func didPressCancel(sender: AnyObject) {
        delegate?.didPressCompositePickerCancel(sender: self)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
