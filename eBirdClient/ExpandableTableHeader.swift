//
//  ExpandableTableHeader.swift
//  BirdScene
//
//  Created by Fred Hewett on 2/3/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

import UIKit

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
        if (title.characters.count > 0) {
            label.text = (isExpanded ? String(OPEN) : String(CLOSED)) + "  " + title;
        }
        else {
            label.text = ""
        }
        label.font = UIFont.boldSystemFontOfSize(17.0)
        
        addSubview(label);
        backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0);
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: "didTapHeader:"))
    }
    
    var expanded: Bool {
        get {
            let first = Array((label.text!).characters)[0];
            return first == OPEN;
        }
        set(value) {
            //if (value != self.expanded) {
            let end = label.text!.startIndex.successor();
            let range = Range<String.Index>(start: label.text!.startIndex, end: end)
            
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
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
}


