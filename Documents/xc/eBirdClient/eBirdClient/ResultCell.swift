//
//  ResultCell.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/12/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

protocol ResultCellDelegate {
    func didTapResultCellLocation(sender: UITableViewCell)
    func didTapResultCellSpecies(sender: UITableViewCell)
    func didTapResultCellDate(sender: UITableViewCell)
}

class ResultCell : UITableViewCell {
    enum TagFields: Int {case SPECIES=1, DATE, LOCATION}

    var delegate: ResultCellDelegate?
    
    @IBOutlet weak var speciesLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    
    func initialize () {
        speciesLabel.font = UIFont.boldSystemFontOfSize(17.0)
        dateLabel.font = UIFont.systemFontOfSize(14.0);
        locationLabel.font = UIFont.systemFontOfSize(14.0);

        locationLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "didTapLocation:"));
        locationLabel.userInteractionEnabled = true;
        locationLabel.textColor = (UIApplication.sharedApplication().delegate as AppDelegate).appClickableColor;
        
        dateLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "didTapDate:"))
        dateLabel.userInteractionEnabled = true;
        
        speciesLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "didTapSpecies:"))
        speciesLabel.userInteractionEnabled = true;
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder);
    }
    
    @IBAction func didTapSpecies(sender: AnyObject) {
        if delegate != nil {
            delegate?.didTapResultCellSpecies(self);
        }
    }

    @IBAction func didTapLocation(sender: AnyObject) {
        if delegate != nil {
            delegate?.didTapResultCellLocation(self);
        }
    }

    @IBAction func didTapDate(sender: AnyObject) {
        if delegate != nil {
            delegate?.didTapResultCellDate(self);
        }
    }

    
    
    
}
