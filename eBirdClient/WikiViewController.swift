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
            Logger.log(fromSource: self, level: .ERROR, message: "no string was supplied");
            return
        }

        let name = speciesScientificName!.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())
        let url : NSURL! = NSURL(string: "https://en.wikipedia.org/wiki/" + name!)
        let request = NSURLRequest(URL: url)
        Logger.log(fromSource: self, level: .INFO, message: "Wiki request is" + url.absoluteString);
        webView.loadRequest(request)
    }
}
