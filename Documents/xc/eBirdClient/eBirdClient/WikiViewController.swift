//
//  WikiViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/14/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

class WikiViewContoller : UIViewController {

    var speciesScientificName: String?
    
    @IBOutlet weak var webView: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if speciesScientificName == nil {
            println("Wiki view: no string was supplied");
            return
        }
        
        var name = speciesScientificName!.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding);
        
        var url : NSURL! = NSURL(string: "https://en.wikipedia.org/wiki/" + name!)
        var request = NSURLRequest(URL: url)
        println("Wiki request is" + url.absoluteString!);
        webView.loadRequest(request)
    }
}
