//
//  CompositePickerViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/7/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

protocol CompositePickerViewControllerDelegate {
    func compositePicker(picker view: CompositePickerViewController, didSelectRowWithTitle rowId: String)
    func compositePicker(picker view: CompositePickerViewController, didSelectMultipleRows rowIds: [String])
    func compositePicker(picker view: CompositePickerViewController, didCancel: Bool)
}

class CompositePickerViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {

    var delegate: CompositePickerViewControllerDelegate?
    var rowTitles: [String?]?
    var maxEntriesToShowInTable = 250;
    
    var filteredRows: [String?]?
    
    @IBOutlet weak var textInput: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self;
        tableView.delegate = self;
        textInput.becomeFirstResponder();
        textInput.autocorrectionType = UITextAutocorrectionType.No
        
        let attrStr: NSAttributedString = NSAttributedString(string: "Begin typing species name", attributes: [
            NSForegroundColorAttributeName: UIColor.lightGrayColor()
        ])
        textInput.attributedPlaceholder = attrStr
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if rowTitles != nil && rowTitles!.count < maxEntriesToShowInTable {
            filteredRows = rowTitles
        }
    }
    
    @IBAction func textFieldDidChange(sender: AnyObject) {
        if textInput.text?.characters.count > 0 {
            filteredRows = filter(rowTitles, mustContain: textInput.text);
            if (filteredRows!.count <= maxEntriesToShowInTable) {
                tableView.reloadData();
            }
        }
    }
    
    func filter(stringSet: [String?]?, mustContain: String?) -> [String?] {
        var result = [String?]();
        let mustContainLower = mustContain!.lowercaseString
        
        for s in stringSet! {
            if (s != nil) && s!.lowercaseString.rangeOfString(mustContainLower) != nil {
                result.append(s!);
            }
        }
        
        return result;
    }
    
    
    // table view
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if rowTitles != nil {
            return rowTitles!.count
        }
        else {
            return 0;
        }
    }
    
    // Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
    // Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "reuse-me")
        
        if (filteredRows != nil && indexPath.row < filteredRows!.count) {
            cell.textLabel?.text = filteredRows?[indexPath.row];
        }

        return cell;
    }

    func findCellForTitle(title: String) -> UITableViewCell? {
        for (var i=0; i < filteredRows!.count; ++i) {
            
            if filteredRows![i] == title {
                let path = NSIndexPath(forRow: i, inSection: 0)
                return tableView.cellForRowAtIndexPath(path);
            }
        }
        return nil;
    }

    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        delegate?.compositePicker(picker: self, didSelectRowWithTitle: filteredRows![indexPath.row]!);
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        // handle deselect here
    }
    
    @IBAction func didPressCancel(sender: AnyObject) {
        delegate?.compositePicker(picker: self, didCancel: true)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
