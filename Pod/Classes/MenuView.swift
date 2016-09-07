//
//  MenuView.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 5/9/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

open class MenuView: UIScrollView {
    
    open var menuItemViews = [MenuItemView]()
    fileprivate var sortedMenuItemViews = [MenuItemView]()
    fileprivate var options: PagingMenuOptions!
    fileprivate var contentView: UIView!
    fileprivate var underlineView: UIView!
    fileprivate var roundRectView: UIView!
    fileprivate var currentPage: Int = 0
    
    // MARK: - Lifecycle
    
    public init(menuItemTitles: [String], options: PagingMenuOptions) {
        super.init(frame: CGRect.zero)
        
        self.options = options
		options.menuItemCount = menuItemTitles.count
        
        setupScrollView()
        constructContentView()
        layoutContentView()
        constructRoundRectViewIfNeeded()
        constructMenuItemViews(titles: menuItemTitles)
        layoutMenuItemViews()
        constructUnderlineViewIfNeeded()
    }
	
	public init(menuItemTitles: [NSAttributedString], menuItemTitlesSelected: [NSAttributedString], options: PagingMenuOptions) {
		
		super.init(frame: CGRect.zero)
		
		self.options = options
		options.menuItemCount = menuItemTitles.count
		
		setupScrollView()
		constructContentView()
		layoutContentView()
		constructRoundRectViewIfNeeded()
		constructAttributedMenuItemViews(titles: menuItemTitles, selectedTitles: menuItemTitlesSelected)
		layoutMenuItemViews()
		constructUnderlineViewIfNeeded()
	}
	
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
		
        adjustmentContentInsetIfNeeded()
    }
	
    // MARK: - Public method
    
    open func moveToMenu(page: Int, animated: Bool) {
		
        let duration = animated ? options.animationDuration : 0
        currentPage = page
        
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: options.springWithDamping, initialSpringVelocity: options.initialSpringVelocity , options: UIViewAnimationOptions.curveEaseOut,  animations: { [unowned self] () -> Void in
            self.focusMenuItem()
            self.positionMenuItemViews()
        }) { [unowned self] (_) in
            // relayout menu item views dynamically
            if case .infinite(_) = self.options.menuDisplayMode {
                self.relayoutMenuItemViews()
            }
            self.positionMenuItemViews()
        }
    }
    
    internal func updateMenuViewConstraints(size: CGSize) {
        if case .segmentedControl = options.menuDisplayMode {
            menuItemViews.forEach { $0.updateLabelConstraints(size: size) }
        }
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()

        animateUnderlineViewIfNeeded()
        animateRoundRectViewIfNeeded()
    }
    
    // MARK: - Private method
    
    fileprivate func setupScrollView() {
        if case .roundRect(_, _, _, _) = options.menuItemMode {
            backgroundColor = UIColor.clear
        } else {
            backgroundColor = options.backgroundColor
        }
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = bounces()
        isScrollEnabled = scrollEnabled()
        scrollsToTop = false
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    fileprivate func constructContentView() {
        contentView = UIView(frame: CGRect.zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
    }
    
    fileprivate func layoutContentView() {
        let viewsDictionary = ["contentView": contentView, "scrollView": self]
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView(==scrollView)]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
        
        NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
    }
    
    fileprivate func constructMenuItemViews(titles: [String]) {
        for i in 0..<options.menuItemCount {
            let menuItemView = MenuItemView(title: titles[i], options: options)
			menuItemView.index = i
            menuItemView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(menuItemView)
            
            menuItemViews.append(menuItemView)
        }
        
        sortMenuItemViews()
    }
	
	fileprivate func constructAttributedMenuItemViews(titles: [NSAttributedString], selectedTitles: [NSAttributedString]) {
		for i in 0..<options.menuItemCount {
			let menuItemView = MenuItemView(title: titles[i], selectedTitle: selectedTitles[i] ,options: options)
			menuItemView.index = i
			menuItemView.translatesAutoresizingMaskIntoConstraints = false
			contentView.addSubview(menuItemView)
			
			menuItemViews.append(menuItemView)
		}
		
		sortMenuItemViews()
	}
	
    fileprivate func sortMenuItemViews() {
        if sortedMenuItemViews.count > 0 {
            sortedMenuItemViews.removeAll()
        }
        
        if case .infinite(_) = options.menuDisplayMode {
            for i in 0..<options.menuItemCount {
                let index = rawIndex(i)
                sortedMenuItemViews.append(menuItemViews[index])
            }
        } else {
            sortedMenuItemViews = menuItemViews
        }
    }
    
    fileprivate func layoutMenuItemViews() {
        NSLayoutConstraint.deactivate(contentView.constraints)
        
        for (index, menuItemView) in sortedMenuItemViews.enumerated() {
            let visualFormat: String;
            var viewsDicrionary = ["menuItemView": menuItemView]
            if index == 0 {
                visualFormat = "H:|[menuItemView]"
            } else  {
                viewsDicrionary["previousMenuItemView"] = sortedMenuItemViews[index - 1]
                if index == sortedMenuItemViews.count - 1 {
                    visualFormat = "H:[previousMenuItemView][menuItemView]|"
                } else {
                    visualFormat = "H:[previousMenuItemView][menuItemView]"
                }
            }
            let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: visualFormat, options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDicrionary)
            let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[menuItemView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDicrionary)
            
            NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    fileprivate func constructUnderlineViewIfNeeded() {
        if case .underline(let height, let color, let horizontalPadding, let verticalPadding) = options.menuItemMode {
            let width = menuItemViews[currentPage].bounds.width - horizontalPadding * 2
            underlineView = UIView(frame: CGRect(x: horizontalPadding, y: options.menuHeight - (height + verticalPadding), width: width, height: height))
            underlineView.backgroundColor = color
            contentView.addSubview(underlineView)
        }
    }
    
    fileprivate func constructRoundRectViewIfNeeded() {
        if case .roundRect(let radius, _, let verticalPadding, let selectedColor) = options.menuItemMode {
            let height = options.menuHeight - verticalPadding * 2
            roundRectView = UIView(frame: CGRect(x: 0, y: verticalPadding, width: 0, height: height))
            roundRectView.frame.origin.y = verticalPadding
            roundRectView.isUserInteractionEnabled = true
            roundRectView.layer.cornerRadius = radius
            roundRectView.backgroundColor = selectedColor
            contentView.addSubview(roundRectView)
        }
    }
    
    fileprivate func animateUnderlineViewIfNeeded() {
        if case .underline(_, _, let horizontalPadding, _) = options.menuItemMode {
            if let underlineView = underlineView {
                let targetFrame = menuItemViews[currentPage].frame
                underlineView.frame.origin.x = targetFrame.minX + horizontalPadding
                underlineView.frame.size.width = targetFrame.width - horizontalPadding * 2
            }
        }
    }
    
    fileprivate func animateRoundRectViewIfNeeded() {
        if case .roundRect(_, let horizontalPadding, _, _) = options.menuItemMode {
            if let roundRectView = roundRectView {
                let targetFrame = menuItemViews[currentPage].frame
                roundRectView.frame.origin.x = targetFrame.minX + horizontalPadding
                roundRectView.frame.size.width = targetFrame.width - horizontalPadding * 2
            }
        }
    }

    fileprivate func relayoutMenuItemViews() {
        sortMenuItemViews()
        layoutMenuItemViews()
    }

    fileprivate func positionMenuItemViews() {
        contentOffset.x = targetContentOffsetX()
        animateUnderlineViewIfNeeded()
        animateRoundRectViewIfNeeded()
    }
    
    fileprivate func bounces() -> Bool {
        if case .standard(_, _, let scrollingMode) = options.menuDisplayMode {
            if case .scrollEnabledAndBouces = scrollingMode {
                return true
            }
        }
        return false
    }
    
    fileprivate func scrollEnabled() -> Bool {
        if case .standard(_, _, let scrollingMode) = options.menuDisplayMode {
            switch scrollingMode {
            case .scrollEnabled, .scrollEnabledAndBouces: return true
            case .pagingEnabled: return false
            }
        }
        return false
    }
    
    fileprivate func adjustmentContentInsetIfNeeded() {
        switch options.menuDisplayMode {
        case .standard(_, let centerItem, _) where centerItem: break
        default: return
        }
        
        let firstMenuView = menuItemViews.first!
        let lastMenuView = menuItemViews.last!
        
        var inset = contentInset
        let halfWidth = frame.width / 2
        inset.left = halfWidth - firstMenuView.frame.width / 2
        inset.right = halfWidth - lastMenuView.frame.width / 2
        contentInset = inset
    }
    
    fileprivate func targetContentOffsetX() -> CGFloat {
        switch options.menuDisplayMode {
        case .standard(_, let centerItem, _) where centerItem:
            return centerOfScreenWidth()
        case .segmentedControl:
            return contentOffset.x
        case .infinite(_):
            return centerOfScreenWidth()
        default:
            return contentOffsetXForCurrentPage()
        }
    }
    
    fileprivate func centerOfScreenWidth() -> CGFloat {
        return menuItemViews[currentPage].frame.midX - UIScreen.main.bounds.width / 2
    }
    
    fileprivate func contentOffsetXForCurrentPage() -> CGFloat {
        if menuItemViews.count == options.minumumSupportedViewCount {
            return 0.0
        }
        let ratio = CGFloat(currentPage) / CGFloat(menuItemViews.count - 1)
        return (contentSize.width - frame.width) * ratio
    }
    
    fileprivate func focusMenuItem() {
        // make selected item focused
        menuItemViews.forEach { $0.focusLabel(menuItemViews.index(of: $0) == currentPage) }

        // make selected item foreground
        sortedMenuItemViews.forEach { $0.layer.zPosition = menuItemViews.index(of: $0) == currentPage ? 0 : -1 }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    fileprivate func rawIndex(_ sortedIndex: Int) -> Int {
        let count = options.menuItemCount
        let startIndex = currentPage - count / 2
        return (startIndex + sortedIndex + count) % count
    }
}
