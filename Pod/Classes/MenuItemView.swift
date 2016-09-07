//
//  MenuItemView.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 5/9/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

open class MenuItemView: UIView {
    
    fileprivate var options: PagingMenuOptions!
	
	open var titleAttributed: NSAttributedString! {
		didSet {
			if titleLabel != nil {
				titleLabel.attributedText = titleAttributed
				layoutLabel()
			}
		}
	}
	open var titleSelectedAttributed: NSAttributedString! {
		didSet {
			if titleLabel != nil && selected {
				titleLabel.attributedText = titleSelectedAttributed
				layoutLabel()
			}
		}
	}
	
	open var index:Int = 0
	
	fileprivate var title:String!
    fileprivate var titleLabel: UILabel!
    fileprivate var titleLabelFont: UIFont!
    fileprivate var widthLabelConstraint: NSLayoutConstraint!
	fileprivate var selected:Bool = false
	
    // MARK: - Lifecycle
	
	internal init(title: String, options: PagingMenuOptions) {
		super.init(frame: CGRect.zero)
		
		self.options = options
		self.title = title
		
		setupView()
		constructLabel()
		layoutLabel()
	}

	internal init(title: NSAttributedString, selectedTitle: NSAttributedString, options: PagingMenuOptions) {
        super.init(frame: CGRect.zero)
        
        self.options = options
        self.titleAttributed = title
		self.titleSelectedAttributed = selectedTitle
        
        setupView()
        constructLabel()
        layoutLabel()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    // MARK: - Constraints manager
    
    internal func updateLabelConstraints(size: CGSize) {
        // set width manually to support ratotaion
        if case .segmentedControl = options.menuDisplayMode {
            let labelSize = calculateLableSize(size)
            widthLabelConstraint.constant = labelSize.width
        }
    }
    
    // MARK: - Label changer
    
    internal func focusLabel(_ selected: Bool) {
		
		self.selected = selected
		
        if case .roundRect(_, _, _, _) = options.menuItemMode {
            backgroundColor = UIColor.clear
        } else {
            backgroundColor = selected ? options.selectedBackgroundColor : options.backgroundColor
        }
		
		if titleAttributed != nil {
			titleLabel.attributedText = selected ? titleSelectedAttributed : titleAttributed
		} else {
			titleLabel.textColor = selected ? options.selectedTextColor : options.textColor
			titleLabelFont = selected ? options.selectedFont : options.font
		}
		
        // adjust label width if needed
        let labelSize = calculateLableSize()
        widthLabelConstraint.constant = labelSize.width
    }
    
    // MARK: - Constructor
    
    fileprivate func setupView() {
        if case .roundRect(_, _, _, _) = options.menuItemMode {
            backgroundColor = UIColor.clear
        } else {
            backgroundColor = options.backgroundColor
        }
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    fileprivate func constructLabel() {
        titleLabel = UILabel()
		if titleAttributed != nil {
			titleLabel.attributedText = titleAttributed
			titleLabel.numberOfLines = 0
		} else {
			titleLabel.text = title
			titleLabel.textColor = options.textColor
			titleLabelFont = options.font
			titleLabel.font = titleLabelFont
			titleLabel.numberOfLines = 1
		}
		
        titleLabel.textAlignment = NSTextAlignment.center
        titleLabel.isUserInteractionEnabled = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
    }
    
    fileprivate func layoutLabel() {
        let viewsDictionary = ["label": titleLabel]
        
        let labelSize = calculateLableSize()

        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[label]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        
        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
        
        widthLabelConstraint = NSLayoutConstraint(item: titleLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1.0, constant: labelSize.width)
        widthLabelConstraint.isActive = true
    }
    
    // MARK: - Size calculator
    
    fileprivate func calculateLableSize(_ size: CGSize = UIScreen.main.bounds.size) -> CGSize {
		var labelSize:CGSize!
		if titleAttributed != nil {
			labelSize = titleAttributed.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil).size
		} else {
			labelSize = NSString(string: title).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSFontAttributeName: titleLabelFont], context: nil).size
		}
        let itemWidth: CGFloat
        switch options.menuDisplayMode {
        case .standard(let widthMode, _, _):
            itemWidth = labelWidth(labelSize, widthMode: widthMode)
        case .segmentedControl:
            itemWidth = size.width / CGFloat(options.menuItemCount)
        case .infinite(let widthMode):
            itemWidth = labelWidth(labelSize, widthMode: widthMode)
        }
        
        let itemHeight = floor(labelSize.height)
        return CGSize(width: itemWidth + calculateHorizontalMargin() * 2, height: itemHeight)
    }
    
    fileprivate func labelWidth(_ labelSize: CGSize, widthMode: PagingMenuOptions.MenuItemWidthMode) -> CGFloat {
        switch widthMode {
        case .flexible: return ceil(labelSize.width)
        case .fixed(let width): return width
        }
    }
    
    fileprivate func calculateHorizontalMargin() -> CGFloat {
        if case .segmentedControl = options.menuDisplayMode {
            return 0.0
        }
        return options.menuItemMargin
    }
}
