//
//  DetailsViewController.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/13/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

var htmlDetailsTemplate: String?

class DetailsViewController : UIViewController {

    var sighting: eBirdSightingDetail?
    
    @IBOutlet weak var textView: UITextView!
    
    class func initHTMLTemplate() {
        let layoutName = "detailView";
        let path = NSBundle.mainBundle().pathForResource(layoutName, ofType: "html")
        
        htmlDetailsTemplate = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: NSErrorPointer())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();

        var markup = htmlDetailsTemplate;

        if (sighting != nil && htmlDetailsTemplate != nil) {
            var df1: NSDateFormatter = NSDateFormatter();
            df1.dateStyle = NSDateFormatterStyle.LongStyle
            var dateString = df1.stringFromDate(sighting!.basic.date)
           
            var df2: NSDateFormatter = NSDateFormatter();
            df2.timeStyle = NSDateFormatterStyle.LongStyle
            var timeString = df2.stringFromDate(sighting!.basic.date)
            
            var userName: String!
            if countElements(sighting!.userName) == 0 {
                userName = "&lt;unavailable&gt;"
            }
            else {
                userName = sighting!.userName
            }
            var count: String!
            if (sighting!.basic.count? > 0) {
                count = String(sighting!.basic.count!)
            }
            else if (sighting!.presenceOnly) {
                count = "&lt;presence noted&gt;"
            }
            else {
                count = "&lt;unspecified&gt"
            }
            
            var locString = sighting!.basic.locationName
            let br = "<br>"

            if (!sighting!.subnational2Name.isEmpty) {
                locString += br + sighting!.subnational2Name
                if (!sighting!.subnational1Name.isEmpty) {
                    locString += br + sighting!.subnational1Name
                }
                 if !sighting!.countryName.isEmpty {
                    locString += br + sighting!.countryName
                }
            }
            locString += br +
                "(" + String(format: "%.4f", sighting!.basic.coordinates.lng) + ", " + String(format: "%.4f", sighting!.basic.coordinates.lat) + ")"

            var status = getStatus(sighting!.basic)
            
            markup = markup!.stringByReplacingOccurrencesOfString("scientific-name", withString: sighting!.basic.scientificName);
            markup = markup!.stringByReplacingOccurrencesOfString("common-name", withString: sighting!.basic.commonName);
            markup = markup!.stringByReplacingOccurrencesOfString("user-name", withString: userName);
            markup = markup!.stringByReplacingOccurrencesOfString("date-string", withString: dateString)
            markup = markup!.stringByReplacingOccurrencesOfString("time-string", withString: timeString)
            markup = markup!.stringByReplacingOccurrencesOfString("count-string", withString: count!)
            markup = markup!.stringByReplacingOccurrencesOfString("loc-string", withString: locString)
            markup = markup!.stringByReplacingOccurrencesOfString("status-string", withString: status)
        }

        var attribString = NSAttributedString(data: markup!.dataUsingEncoding(NSUnicodeStringEncoding, allowLossyConversion: false)!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil, error: nil)

        dispatch_async(dispatch_get_main_queue(), {
            self.textView.attributedText = attribString;
        })
    }
    
    @IBAction func copyToClipboard(sender: AnyObject) {
        UIPasteboard.generalPasteboard().string = textView.text;
        shareTextImageAndURL(sharingText: textView.text, sharingImage: nil, sharingURL: nil)
    }
    
    func getStatus(sighting: eBirdSighting) -> String {
        var status: String!
        if (sighting.validated) {
            status = stringInSpan("Validated", withColor: "#449b44", isBold: true);
        }
        else if (!sighting.reviewed) {
            status = stringInSpan("Not reviewed", withColor: "#FF8205", isBold: true)
        }
        else {
            status = stringInSpan("Rejected by reviewer", withColor: "#EE1111", isBold: true)
        }
        return status;
    }
        
    func stringInSpan(string: String,  withColor colorCode: String, isBold: Bool) -> String {
        let bold = isBold ? ";font-weight:bold" : ""
        var result = "<span style=\"color:" + colorCode + bold + "\">" + string + "</span>"
        return result;
    }

    func shareTextImageAndURL(#sharingText: String?, sharingImage: UIImage?, sharingURL: NSURL?) {
        var sharingItems = [AnyObject]()
        
        if let text = sharingText {
            sharingItems.append(text)
        }
        if let image = sharingImage {
            sharingItems.append(image)
        }
        if let url = sharingURL {
            sharingItems.append(url)
        }
        
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
        self.presentViewController(activityViewController, animated: true, completion: nil)
    }

}
