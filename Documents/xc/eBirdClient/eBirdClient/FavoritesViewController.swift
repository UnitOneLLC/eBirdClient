//
//  FavoritesViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/9/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit


class FavoritesViewController : UITableViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var editButton: UIBarButtonItem!

    var savedQueries: [Query]?
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "FavCell")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        var error: NSError? = NSError(domain: "", code: 0, userInfo: Dictionary<NSObject, AnyObject>())
        let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        
        savedQueries = theDataManager.fetchAllQueryObjects(appDelegate.managedObjectContext, error: &error)
        
        if error!.code != 0 || error!.domain != "" {
            println("Could not fetch \(error), \(error!.userInfo)")
        }
        refreshNavPrompt()
    }
    
    
    @IBAction func didPressEdit(sender: UIBarButtonItem) {
        if (!tableView.editing) {
            tableView.editing = true
            editButton.title = "Done"
        }
        else {
            tableView.editing = false
            editButton.title = "Edit"
        }
        refreshNavPrompt()
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (savedQueries != nil) {
            return savedQueries!.count;
        }
        else {
            return 0;
        }
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {

            let title = tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.text
            if title != nil {
                let appDelegate = UIApplication.sharedApplication().delegate as AppDelegate
                var error = theDataManager.deleteQueryObjectByTitle(appDelegate.managedObjectContext!, title: title!)
                
                if error == nil {
                    savedQueries!.removeAtIndex(indexPath.row)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                }
                else {
                    println("failed to delete row")
                }
            }
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("FavCell") as UITableViewCell?
        if (cell == nil) {
            cell = UITableViewCell()
        }
        
        let q = savedQueries![indexPath.row]
        cell!.textLabel!.text = q.title
        
        return cell!
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var query = savedQueries![indexPath.row];
        var qData = theDataManager.getQueryData(fromManagedObject: query);
        
        if (qData != nil) {
            var appDel = (UIApplication.sharedApplication().delegate as AppDelegate)
            appDel.queryToRun = qData
            appDel.savedQueryWasRun = qData
            appDel.activateResultsViewController();
        }
        else {
            println("failed to convert managed object to query data");
        }
    }
    
    func refreshNavPrompt() {
        if tableView.editing {
            navigationItem.prompt = ""
        }
        else if savedQueries == nil {
            navigationItem.prompt = "There was a problem fetching the saved searches"
        }
        else if savedQueries!.count == 0 {
            navigationItem.prompt = "You have no saved searches"
        }
        else {
            navigationItem.prompt = "Click on a saved search to execute it"
        }
    }
    
    
    
    
}
