//
//  PagingMenuController.swift
//  PagingMenuController
//
//  Created by Yusuke Kita on 3/18/15.
//  Copyright (c) 2015 kitasuke. All rights reserved.
//

import UIKit

@objc public protocol PagingMenuControllerDelegate: class {
	@objc optional func didBeginScrollingHorizontally()
	@objc optional func didEndScrollingHorizontally()
	@objc optional func didLoadPageController(_ viewController:UIViewController)
	@objc optional func willMoveToMenuPage(_ viewController:UIViewController, page: Int)
	@objc optional func didMoveToMenuPage(_ viewController:UIViewController, page: Int)
}

open class PagingMenuController: UIViewController, UIScrollViewDelegate {

	open weak var delegate: PagingMenuControllerDelegate?
	fileprivate var options: PagingMenuOptions!
	open var menuView: MenuView! {
		didSet {
			addTapGestureHandlers()
			addSwipeGestureHandlersIfNeeded()
		}
	}
	open var contentScrollView: UIScrollView!
	open var contentView: UIView!
	open var pagingViewControllers = [UIViewController]() {
		willSet {
			options.menuItemCount = newValue.count
		}
	}
	open var visiblePagingViewControllers = [UIViewController]()
	open var currentPage: Int = 0
	open var currentViewController: UIViewController!
	fileprivate var menuItemTitles: [String] {
		get {
			return pagingViewControllers.map {
				return $0.title ?? "Menu"
			}
		}
	}
	fileprivate enum PagingViewPosition {
		case left
		case center
		case right
		case unknown

		init(order: Int) {
			switch order {
			case 0: self = .left
			case 1: self = .center
			case 2: self = .right
			default: self = .unknown
			}
		}
	}
	fileprivate var scrollBegan = false {
		didSet {
			if scrollBegan {
				self.delegate?.didBeginScrollingHorizontally?()
			} else {
				self.delegate?.didEndScrollingHorizontally?()
			}
		}
	}
	fileprivate var currentPosition: PagingViewPosition = .left
	fileprivate let visiblePagingViewNumber: Int = 3
	fileprivate var previousIndex: Int {
		if case .infinite(_) = options.menuDisplayMode {
			return currentPage - 1 < 0 ? options.menuItemCount - 1 : currentPage - 1
		}
		return currentPage - 1
	}
	fileprivate var nextIndex: Int {
		if case .infinite(_) = options.menuDisplayMode {
			return currentPage + 1 > options.menuItemCount - 1 ? 0 : currentPage + 1
		}
		return currentPage + 1
	}

	fileprivate let ExceptionName = "PMCException"

	// MARK: - Lifecycle

	public init(viewControllers: [UIViewController], options: PagingMenuOptions) {
		super.init(nibName: nil, bundle: nil)

		setup(viewControllers: viewControllers, options: options)
	}

	convenience public init(viewControllers: [UIViewController]) {
		self.init(viewControllers: viewControllers, options: PagingMenuOptions())
	}

	convenience public init() {
		self.init(viewControllers: [], options: PagingMenuOptions())
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)


		//		moveToMenuPage(currentPage, animated: false)
	}

	override open func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		// fix unnecessary inset for menu view when implemented by programmatically
		if let menuView =  menuView {
			menuView.contentInset.top = 0
		}

		// position paging views correctly after view size is decided
		if let currentViewController = currentViewController {
			contentScrollView.contentOffset.x = currentViewController.view!.frame.minX
		}
	}

	override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		if let menuView =  menuView {
			menuView.updateMenuViewConstraints(size: size)
		}

		coordinator.animate(alongsideTransition: { [unowned self] (_) -> Void in
			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()

			// reset selected menu item view position
			switch self.options.menuDisplayMode {
			case .standard(_, _, _), .infinite(_):
				self.menuView.moveToMenu(page: self.currentPage, animated: true)
			default: break
			}
			}, completion: nil)
	}

	open func setup(viewControllers: [UIViewController], options: PagingMenuOptions) {
		if viewControllers.count == 0 { return }

		self.options = options
		pagingViewControllers = viewControllers
		visiblePagingViewControllers.reserveCapacity(visiblePagingViewNumber)

		// validate
		validateDefaultPage()
		validatePageNumbers()

		// cleanup
		cleanup()

		currentPage = options.defaultPage


		if options.menuPosition != .standalone {constructMenuView()}
		constructContentScrollView()
		if options.menuPosition != .standalone {layoutMenuView()}
		layoutContentScrollView()
		constructContentView()
		layoutContentView()
		constructPagingViewControllers()
		layoutPagingViewControllers()

		currentPosition = currentPagingViewPosition()
		currentViewController = pagingViewControllers[currentPage]

	}

	open func rebuild(_ viewControllers: [UIViewController], options: PagingMenuOptions) {
		setup(viewControllers: viewControllers, options: options)

		view.setNeedsLayout()
		view.layoutIfNeeded()
	}

	// MARK: - UISCrollViewDelegate

	open func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if !scrollView.isEqual(contentScrollView) || !scrollView.isDragging {
			return
		}

		if !scrollBegan {
			scrollBegan = true
		}

		// calculate current direction
		let position = currentPagingViewPosition()
		if currentPosition != position {
			let newPage: Int
			switch position {
			case .left: newPage = previousIndex
			case .right: newPage = nextIndex
			default: newPage = currentPage
			}

			if let menuView = menuView {
				menuView.moveToMenu(page: newPage, animated: true)
			}
		}
	}

	open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		if !scrollView.isEqual(contentScrollView) {
			return
		}

		let position = currentPagingViewPosition()

		// go back to starting position if it's same page after all
		if let menuView = menuView , currentPosition == position {
			menuView.moveToMenu(page: currentPage, animated: true)
			return
		}

		// set new page number according to current moving direction
		switch position {
		case .left: currentPage = previousIndex
		case .right: currentPage = nextIndex
		default: return
		}

		if scrollBegan {
			scrollBegan = false
		}

		currentViewController = pagingViewControllers[currentPage]
		delegate?.willMoveToMenuPage?(currentViewController, page: currentPage)
		contentScrollView.contentOffset.x = currentViewController.view!.frame.minX

		constructPagingViewControllers()
		layoutPagingViewControllers()
		view.setNeedsLayout()
		view.layoutIfNeeded()

		currentPosition = currentPagingViewPosition()
		delegate?.didMoveToMenuPage?(currentViewController, page: currentPage)
	}

	// MARK: - UIGestureRecognizer

	internal func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
		let tappedMenuView = recognizer.view as! MenuItemView
		guard let tappedPage = menuView.menuItemViews.index(of: tappedMenuView) , tappedPage != currentPage else { return }



		let page = targetPage(tappedPage: tappedPage)
		moveToMenuPage(page, animated: true)
	}

	internal func handleSwipeGesture(_ recognizer: UISwipeGestureRecognizer) {
		var newPage = currentPage
		if recognizer.direction == .left {
			newPage = min(nextIndex, menuView.menuItemViews.count - 1)
		} else if recognizer.direction == .right {
			newPage = max(previousIndex, 0)
		} else {
			return
		}

		moveToMenuPage(newPage, animated: true)
	}

	// MARK: - Constructor

	fileprivate func constructMenuView() {
		menuView = MenuView(menuItemTitles: menuItemTitles, options: options)
		menuView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(menuView)
	}

	fileprivate func layoutMenuView() {

		let viewsDictionary = ["menuView": menuView]
		let metrics = ["height": options.menuHeight]
		let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[menuView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		let verticalConstraints: [NSLayoutConstraint]
		switch options.menuPosition {
		case .top:
			verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[menuView(height)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: metrics, views: viewsDictionary)
		case .bottom:
			verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[menuView(height)]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: metrics, views: viewsDictionary)
		default:
			verticalConstraints = []
		}

		NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)

		menuView.setNeedsLayout()
		menuView.layoutIfNeeded()
	}

	fileprivate func constructContentScrollView() {
		contentScrollView = UIScrollView(frame: CGRect.zero)
		contentScrollView.delegate = self
		contentScrollView.isPagingEnabled = true
		contentScrollView.showsHorizontalScrollIndicator = false
		contentScrollView.showsVerticalScrollIndicator = false
		contentScrollView.scrollsToTop = false
		contentScrollView.bounces = false
		contentScrollView.isScrollEnabled = options.scrollEnabled
		contentScrollView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(contentScrollView)
	}

	fileprivate func layoutContentScrollView() {


		var viewsDictionary:[String:AnyObject]
		if options.menuPosition != .standalone {
			viewsDictionary = ["contentScrollView": contentScrollView, "menuView": menuView]

		} else {
			viewsDictionary = ["contentScrollView": contentScrollView]
		}

		let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentScrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		let verticalConstraints: [NSLayoutConstraint]
		switch options.menuPosition {
		case .top:
			verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[menuView][contentScrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		case .bottom:
			verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentScrollView][menuView]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		case .standalone:
			verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentScrollView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		}

		NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
	}

	fileprivate func constructContentView() {
		contentView = UIView(frame: CGRect.zero)
		contentView.translatesAutoresizingMaskIntoConstraints = false
		contentScrollView.addSubview(contentView)
	}

	open func layoutContentView() {
		let viewsDictionary = ["contentView": contentView, "contentScrollView": contentScrollView]
		let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
		let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView(==contentScrollView)]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)

		NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
	}

	fileprivate func constructPagingViewControllers() {
		for (index, pagingViewController) in pagingViewControllers.enumerated() {
			// construct three child view controllers at a maximum, previous(optional), current and next(optional)
			if !shouldLoadPage(index) {
				// remove unnecessary child view controllers
				if isVisiblePagingViewController(pagingViewController) {
					pagingViewController.willMove(toParentViewController: nil)
					pagingViewController.view!.removeFromSuperview()
					pagingViewController.removeFromParentViewController()

					if let viewIndex = visiblePagingViewControllers.index(of: pagingViewController) {
						visiblePagingViewControllers.remove(at: viewIndex)
					}
				}
				continue
			}

			// ignore if it's already added
			if isVisiblePagingViewController(pagingViewController) {
				continue
			}

			// TODO: ViewDidLoad
			pagingViewController.view!.frame = CGRect.zero
			pagingViewController.view!.translatesAutoresizingMaskIntoConstraints = false

			self.delegate?.didLoadPageController?(pagingViewController)

			contentView.addSubview(pagingViewController.view!)
			addChildViewController(pagingViewController as UIViewController)
			pagingViewController.didMove(toParentViewController: self)

			visiblePagingViewControllers.append(pagingViewController)
		}
	}

	fileprivate func layoutPagingViewControllers() {
		// cleanup
		NSLayoutConstraint.deactivate(contentView.constraints)

		var viewsDictionary: [String: AnyObject] = ["contentScrollView": contentScrollView]
		for (index, pagingViewController) in pagingViewControllers.enumerated() {
			if !shouldLoadPage(index) {
				continue
			}

			viewsDictionary["pagingView"] = pagingViewController.view!
			var horizontalVisualFormat = String()

			// only one view controller
			if (options.menuItemCount == options.minumumSupportedViewCount) {
				horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]|"
			} else {
				if case .infinite(_) = options.menuDisplayMode {
					if index == currentPage {
						viewsDictionary["previousPagingView"] = pagingViewControllers[previousIndex].view
						viewsDictionary["nextPagingView"] = pagingViewControllers[nextIndex].view
						horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)][nextPagingView]"
					} else if index == previousIndex {
						horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]"
					} else if index == nextIndex {
						horizontalVisualFormat = "H:[pagingView(==contentScrollView)]|"
					}
				} else {
					if index == 0 || index == previousIndex {
						horizontalVisualFormat = "H:|[pagingView(==contentScrollView)]"
					} else {
						viewsDictionary["previousPagingView"] = pagingViewControllers[index - 1].view
						if index == pagingViewControllers.count - 1 || index == nextIndex {
							horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)]|"
						} else {
							horizontalVisualFormat = "H:[previousPagingView][pagingView(==contentScrollView)]"
						}
					}
				}
			}

			let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: horizontalVisualFormat, options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)
			let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[pagingView(==contentScrollView)]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: viewsDictionary)

			NSLayoutConstraint.activate(horizontalConstraints + verticalConstraints)
		}

		view.setNeedsLayout()
		view.layoutIfNeeded()
	}

	// MARK: - Cleanup

	fileprivate func cleanup() {
		if let menuView = self.menuView, let contentScrollView = self.contentScrollView {
			menuView.removeFromSuperview()
			contentScrollView.removeFromSuperview()
		}
		currentPage = options.defaultPage
	}

	// MARK: - Gesture handler

	fileprivate func addTapGestureHandlers() {
		menuView.menuItemViews.forEach { $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(PagingMenuController.handleTapGesture(_:)))) }
	}

	fileprivate func addSwipeGestureHandlersIfNeeded() {
		switch options.menuDisplayMode {
		case .standard(_, _, let scrollingMode):
			switch scrollingMode {
			case .pagingEnabled: break
			default: return
			}
		case .segmentedControl: return
		case .infinite(_): break
		}

		let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(PagingMenuController.handleSwipeGesture(_:)))
		leftSwipeGesture.direction = .left
		menuView.panGestureRecognizer.require(toFail: leftSwipeGesture)
		menuView.addGestureRecognizer(leftSwipeGesture)
		let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(PagingMenuController.handleSwipeGesture(_:)))
		rightSwipeGesture.direction = .right
		menuView.panGestureRecognizer.require(toFail: rightSwipeGesture)
		menuView.addGestureRecognizer(rightSwipeGesture)
	}

	// MARK: - Page controller

	open func moveToMenuPage(_ page: Int, animated: Bool, completion: (()->Void)?  = nil) {

		let lastPage = currentPage
		currentPage = page
		currentViewController = pagingViewControllers[page]
		let _ = currentViewController.view

		if let menuView = menuView {
			menuView.moveToMenu(page: currentPage, animated: animated)
		}
		delegate?.willMoveToMenuPage?(currentViewController, page: currentPage)

		// hide paging views if it's moving to far away
		hidePagingViewsIfNeeded(lastPage)

		let duration = animated ? options.animationDuration : 0
		UIView.animate(withDuration: duration, animations: {
			[unowned self] () -> Void in
			self.contentScrollView.contentOffset.x = self.currentViewController.view!.frame.minX
			}, completion: { [unowned self] (_) -> Void in
				// show paging views
				self.visiblePagingViewControllers.forEach { $0.view.alpha = 1 }

				// reconstruct visible paging views
				self.constructPagingViewControllers()
				self.layoutPagingViewControllers()
				self.view.setNeedsLayout()
				self.view.layoutIfNeeded()

				self.currentPosition = self.currentPagingViewPosition()
				self.delegate?.didMoveToMenuPage?(self.currentViewController, page: self.currentPage)

				completion?()
			})
	}

	fileprivate func hidePagingViewsIfNeeded(_ lastPage: Int) {
		if lastPage == previousIndex || lastPage == nextIndex {
			return
		}
		visiblePagingViewControllers.forEach { $0.view.alpha = 0 }
	}

	fileprivate func shouldLoadPage(_ index: Int) -> Bool {
		if case .infinite(_) = options.menuDisplayMode {
			if index != currentPage && index != previousIndex && index != nextIndex {
				return false
			}
		} else {
			if index < previousIndex || index > nextIndex {
				return false
			}
		}
		return true
	}

	fileprivate func isVisiblePagingViewController(_ pagingViewController: UIViewController) -> Bool {
		return childViewControllers.contains(pagingViewController)
	}

	// MARK: - Page calculator

	fileprivate func currentPagingViewPosition() -> PagingViewPosition {
		let pageWidth = contentScrollView.frame.width
		let order = Int(ceil((contentScrollView.contentOffset.x - pageWidth / 2) / pageWidth))

		if case .infinite(_) = options.menuDisplayMode {
			return PagingViewPosition(order: order)
		}

		// consider left edge menu as center position
		if currentPage == 0 &&
			contentScrollView.contentSize.width < (pageWidth * CGFloat(visiblePagingViewNumber)) {
			return PagingViewPosition(order: order + 1)
		}
		return PagingViewPosition(order: order)
	}

	fileprivate func targetPage(tappedPage: Int) -> Int {
		switch options.menuDisplayMode {
		case .standard(_, _, let scrollingMode):
			if case .pagingEnabled = scrollingMode {
				return tappedPage < currentPage ? currentPage-1 : currentPage+1
			}
		default:
			return tappedPage
		}
		return tappedPage
	}

	// MARK: - Validator

	fileprivate func validateDefaultPage() {
		if options.defaultPage >= options.menuItemCount || options.defaultPage < 0 {
			NSException(name: NSExceptionName(rawValue: ExceptionName), reason: "default page is invalid", userInfo: nil).raise()
		}
	}

	fileprivate func validatePageNumbers() {
		if case .infinite(_) = options.menuDisplayMode {
			if options.menuItemCount < visiblePagingViewNumber {
				NSException(name: NSExceptionName(rawValue: ExceptionName), reason: "the number of view controllers should be more than three with Infinite display mode", userInfo: nil).raise()
			}
		}
	}
}
