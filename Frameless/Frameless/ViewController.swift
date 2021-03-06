//
//  ViewController.swift
//  Unframed
//
//  Created by Jay Stakelon on 10/23/14.
//  Copyright (c) 2014 Jay Stakelon. All rights reserved.
//

import UIKit
import WebKit

protocol ScanViewControllerDelegate {
    func scanSucceed(scanValue:String)
}

class ViewController: UIViewController, UISearchBarDelegate, FramelessSearchBarDelegate, UIGestureRecognizerDelegate, WKNavigationDelegate, FramerBonjourDelegate {
    
    @IBOutlet weak var _searchBar: FramelessSearchBar!
    @IBOutlet weak var _progressView: UIProgressView!
    @IBOutlet weak var _loadingErrorView: UIView!
    
    var _webView: WKWebView?
    var _isMainFrameNavigationAction: Bool?
    var _loadingTimer: NSTimer?
    
    var _tapRecognizer: UITapGestureRecognizer?
    var _threeFingerTapRecognizer: UITapGestureRecognizer?
    var _panFromBottomRecognizer: UIScreenEdgePanGestureRecognizer?
    var _panFromRightRecognizer: UIScreenEdgePanGestureRecognizer?
    var _panFromLeftRecognizer: UIScreenEdgePanGestureRecognizer?
    var _areControlsVisible = true
    var _isFirstRun = true
    var _effectView: UIVisualEffectView?
    var _errorView: UIView?
    var _settingsBarView: UIView?
    var _defaultsObject: NSUserDefaults?
    var _onboardingViewController: OnboardingViewController?
    var _isCurrentPageLoaded = false
    
    
    var _framerBonjour = FramerBonjour()
    var _framerAddress: String?
    
    var _alertBuilder: JSSAlertView = JSSAlertView()
    
    // Loading progress? Fake it till you make it.
    var _progressTimer: NSTimer?
    var _isWebViewLoading = false
    
    
    var _collectedButtonLongPressRecognizer: UILongPressGestureRecognizer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var webViewConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
        webViewConfiguration.mediaPlaybackRequiresUserAction = false
        
        _webView = WKWebView(frame: self.view.frame, configuration: webViewConfiguration)
        
        self.view.addSubview(_webView!)
        //        _webView!.scalesPageToFit = true
        _webView!.navigationDelegate = self
        self.view.sendSubviewToBack(_webView!)
        
        _defaultsObject = NSUserDefaults.standardUserDefaults()
        
        _loadingErrorView.hidden = true
        
        _tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("hideSearch"))
        
        _threeFingerTapRecognizer = UITapGestureRecognizer(target: self, action: Selector("handleThreeFingerTap:"))
        _threeFingerTapRecognizer?.numberOfTouchesRequired = 3
        self.view.addGestureRecognizer(_threeFingerTapRecognizer!)
        
        _panFromBottomRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: Selector("handleBottomEdgePan:"))
        _panFromBottomRecognizer!.edges = UIRectEdge.Bottom
        _panFromBottomRecognizer!.delegate = self
        self.view.addGestureRecognizer(_panFromBottomRecognizer!)
        
        _panFromLeftRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: Selector("handleGoBackPan:"))
        _panFromLeftRecognizer!.edges = UIRectEdge.Left
        _panFromLeftRecognizer!.delegate = self
        self.view.addGestureRecognizer(_panFromLeftRecognizer!)
        
        _panFromRightRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: Selector("handleGoForwardPan:"))
        _panFromRightRecognizer!.edges = UIRectEdge.Right
        _panFromRightRecognizer!.delegate = self
        self.view.addGestureRecognizer(_panFromRightRecognizer!)
        
        _searchBar.delegate = self
        _searchBar.framelessSearchBarDelegate = self
        _searchBar.showsCancelButton = false
        _searchBar.becomeFirstResponder()
        AppearanceBridge.setSearchBarTextInputAppearance()
        
        _settingsBarView = UIView(frame: CGRectMake(0, self.view.frame.height, self.view.frame.width, 44))
        //设置
        var settingsButton = UIButton(frame: CGRectMake(7, 0, 36, 36))
        var buttonImg = UIImage(named: "settings-icon")
        settingsButton.setImage(buttonImg, forState: .Normal)
        var buttonHighlightImg = UIImage(named: "settings-icon-highlighted")
        settingsButton.setImage(buttonHighlightImg, forState: .Highlighted)
        settingsButton.addTarget(self, action: "presentSettingsView:", forControlEvents: .TouchUpInside)
        _settingsBarView?.addSubview(settingsButton)
        
        //扫描
        var scanButton = UIButton(frame: CGRectMake(50, 0, 36, 36))
        var scanButtonNormalImg = UIImage(named: "scan-icon")
        scanButton.setImage(scanButtonNormalImg, forState: .Normal)
        var scanButtonHighlightImg = UIImage(named: "scan-icon-highlighted")
        scanButton.setImage(scanButtonHighlightImg, forState: .Highlighted)
        scanButton.addTarget(self, action: "presentScanViewController:", forControlEvents: .TouchUpInside)
        _settingsBarView?.addSubview(scanButton)
        
        //收藏
        var collectButton = UIButton(frame: CGRectMake(93, 0, 36, 36))
        var collectButtonNormalImg = UIImage(named: "collect-icon")
        collectButton.setImage(collectButtonNormalImg, forState: .Normal)
        var collectButtonHighlightImg = UIImage(named: "collect-icon-highlighted")
        collectButton.setImage(collectButtonHighlightImg, forState: .Highlighted)
        collectButton.addTarget(self, action: "presentCollectListViewController:", forControlEvents: .TouchUpInside)
        _settingsBarView?.addSubview(collectButton)
        
        //长按手势
        _collectedButtonLongPressRecognizer = UILongPressGestureRecognizer(target: self, action: "collectedButtonLongPressRecognizer:")
        collectButton.addGestureRecognizer(_collectedButtonLongPressRecognizer!)
        
        self.view.addSubview(_settingsBarView!)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name:UIKeyboardWillShowNotification, object: nil);
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name:UIKeyboardWillHideNotification, object: nil);
        
        _framerBonjour.delegate = self
        if NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.FramerBonjour.rawValue) as! Bool == true {
            _framerBonjour.start()
        }
        
        _progressView.hidden = true
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func introCompletion() {
        _onboardingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    //MARK: - UI show/hide
    
    func keyboardWillShow(sender: NSNotification) {
        if _searchBar.isFirstResponder() {
            let dict:NSDictionary = sender.userInfo! as NSDictionary
            let s:NSValue = dict.valueForKey(UIKeyboardFrameEndUserInfoKey) as! NSValue
            let rect :CGRect = s.CGRectValue()
            _settingsBarView!.frame.origin.y = self.view.frame.height - rect.height - _settingsBarView!.frame.height
            _settingsBarView!.alpha = 1
        }
    }
    
    func keyboardWillHide(sender: NSNotification) {
        _settingsBarView!.frame.origin.y = self.view.frame.height
        _settingsBarView!.alpha = 0
    }
    
    func handleBottomEdgePan(sender: AnyObject) {
        if NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.PanFromBottomGesture.rawValue) as! Bool == true {
            showSearch()
        }
    }
    
    func handleThreeFingerTap(sender: AnyObject) {
        if NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.TripleTapGesture.rawValue) as! Bool == true {
            showSearch()
        }
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent) {
        if let isShakeActive:Bool = NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.ShakeGesture.rawValue) as? Bool {
            if(event.subtype == UIEventSubtype.MotionShake && isShakeActive == true) {
                if (!_areControlsVisible) {
                    showSearch()
                } else {
                    hideSearch()
                }
            }
        }
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func hideSearch() {
        _searchBar.resignFirstResponder()
        UIView.animateWithDuration(0.5, delay: 0.05, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: nil, animations: {
            self._searchBar.transform = CGAffineTransformMakeTranslation(0, -44)
            }, completion:  nil)
        _areControlsVisible = false
        removeBackgroundBlur()
    }
    
    func showSearch() {
        if let urlString = _webView?.URL?.absoluteString {
            _searchBar.text = urlString
        }
        UIView.animateWithDuration(0.5, delay: 0.05, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: nil, animations: {
            self._searchBar.transform = CGAffineTransformMakeTranslation(0, 0)
            }, completion: nil)
        _areControlsVisible = true
        _searchBar.selectAllText()
        _searchBar.becomeFirstResponder()
        blurBackground()
    }
    
    func blurBackground() {
        if !_isFirstRun {
            if _effectView == nil {
                var blur:UIBlurEffect = UIBlurEffect(style: UIBlurEffectStyle.Light)
                _effectView = UIVisualEffectView(effect: blur)
                var size = _webView!.frame.size
                _effectView!.frame = CGRectMake(0,0,size.width,size.height)
                _effectView!.alpha = 0
                _effectView?.addGestureRecognizer(_tapRecognizer!)
                
                _webView!.addSubview(_effectView!)
                _webView!.alpha = 0.25
                UIView.animateWithDuration(0.25, animations: {
                    self._effectView!.alpha = 1
                    }, completion: nil)
            }
        }
    }
    
    func removeBackgroundBlur() {
        if _effectView != nil {
            UIView.animateWithDuration(0.25, animations: {
                self._effectView!.alpha = 0
                }, completion: { finished in
                    self._effectView = nil
            })
            _webView!.alpha = 1
        }
    }
    
    func focusOnSearchBar() {
        _searchBar.becomeFirstResponder()
    }
    
    
    //MARK: -  Settings view
    
    func presentSettingsView(sender:UIButton!) {
        
        let settingsNavigationController = storyboard?.instantiateViewControllerWithIdentifier("settingsController") as! UINavigationController
        
        let settingsTableViewController = settingsNavigationController.topViewController as! SettingsTableViewController
        settingsTableViewController.delegate = self
        
        // Animated form sheet presentation was crashing on regular size class (all iPads, and iPhone 6+ landscape).
        // Disabling the animation until the root cause of that crash is found.
        let shouldAnimateSettingsPresentation: Bool = self.traitCollection.horizontalSizeClass != .Regular
        
        self.presentViewController(settingsNavigationController, animated: shouldAnimateSettingsPresentation, completion: nil)
    }
    
    /**
    扫描二维码
    
    :param: sender 二维码按钮
    */
    func presentScanViewController(sender: UIButton!){
        let scanNavigationController = storyboard?.instantiateViewControllerWithIdentifier("scanController") as! UINavigationController
        
        let scanViewController = scanNavigationController.topViewController as! ScanViewController
        scanViewController.delegate = self
        
        // Animated form sheet presentation was crashing on regular size class (all iPads, and iPhone 6+ landscape).
        // Disabling the animation until the root cause of that crash is found.
        let shouldAnimateSettingsPresentation: Bool = self.traitCollection.horizontalSizeClass != .Regular
        
        self.presentViewController(scanNavigationController, animated: shouldAnimateSettingsPresentation, completion: nil)
    }
    
    /**
    收藏按钮
    
    :param: sender 收藏按钮
    */
    func presentCollectListViewController(sender: UIButton!){
        if _searchBar.text.isEmpty{
            let collectNavigationController = storyboard?.instantiateViewControllerWithIdentifier("collectController") as! UINavigationController
            
            let collectViewController = collectNavigationController.topViewController as! CollectListViewController
            collectViewController.delegate = self
            
            // Animated form sheet presentation was crashing on regular size class (all iPads, and iPhone 6+ landscape).
            // Disabling the animation until the root cause of that crash is found.
            let shouldAnimateSettingsPresentation: Bool = self.traitCollection.horizontalSizeClass != .Regular
            
            self.presentViewController(collectNavigationController, animated: shouldAnimateSettingsPresentation, completion: nil)
            
        }else{
            var collectedArray = NSArray(contentsOfURL: NSURL(fileURLWithPath: collectedFilePath())!)
            
            var collectedMutableArray: NSMutableArray?
            if collectedArray?.count > 0{
                collectedMutableArray = NSMutableArray(array: collectedArray!)
            }else{
                collectedMutableArray = NSMutableArray()
            }
            
            if (!collectedMutableArray!.containsObject(_searchBar.text)){
                collectedMutableArray!.addObject(_searchBar.text)
                
                collectedMutableArray?.writeToFile(collectedFilePath(), atomically: true)
            }
            
            var alertView = UIAlertView(title: "collect succeed", message: nil, delegate: nil, cancelButtonTitle: "确定")
            alertView.show()
        }
    }
    func collectedButtonLongPressRecognizer(sender: UILongPressGestureRecognizer){
        if sender.state == UIGestureRecognizerState.Began{
            let collectNavigationController = storyboard?.instantiateViewControllerWithIdentifier("collectController") as! UINavigationController
            
            let collectViewController = collectNavigationController.topViewController as! CollectListViewController
            collectViewController.delegate = self
            
            // Animated form sheet presentation was crashing on regular size class (all iPads, and iPhone 6+ landscape).
            // Disabling the animation until the root cause of that crash is found.
            let shouldAnimateSettingsPresentation: Bool = self.traitCollection.horizontalSizeClass != .Regular
            
            self.presentViewController(collectNavigationController, animated: shouldAnimateSettingsPresentation, completion: nil)
        }
    }
    
    //收藏文件路径
    func collectedFilePath() -> String{
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! NSString
        return (documentsPath as String) + "/collect.dat"
    }
    
    
    //MARK: -  Web view
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        _searchBar.showsCancelButton = true
        _loadingErrorView.hidden = true
        _isFirstRun = false
        _isWebViewLoading = true
        _progressView.hidden = false
        _progressView.progress = 0
        _progressTimer = NSTimer.scheduledTimerWithTimeInterval(0.01667, target: self, selector: "progressTimerCallback", userInfo: nil, repeats: true)
        _loadingTimer = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: "loadingTimeoutCallback", userInfo: nil, repeats: false)
    }
    
    func loadingTimeoutCallback() {
        _webView?.stopLoading()
        handleWebViewError()
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        _isCurrentPageLoaded = true
        _loadingTimer!.invalidate()
        _isWebViewLoading = false
    }
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        if let newFrameLoading = _isMainFrameNavigationAction {
            // do nothing, I'm pretty sure it's a new page load into target="_blank" before the old one's subframes are finished
        } else {
            handleWebViewError()
        }
    }
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        if let newFrameLoading = _isMainFrameNavigationAction {
            // do nothing, it's a new page load before the old one's subframes are finished
        } else {
            handleWebViewError()
        }
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        if (navigationAction.targetFrame == nil && navigationAction.navigationType == .LinkActivated) {
            _webView!.loadRequest(navigationAction.request)
        }
        _isMainFrameNavigationAction = navigationAction.targetFrame?.mainFrame
        decisionHandler(.Allow)
    }
    
    func handleWebViewError() {
        _loadingTimer!.invalidate()
        _isCurrentPageLoaded = false
        _isWebViewLoading = false
        showSearch()
        displayLoadingErrorMessage()
    }
    
    func progressTimerCallback() {
        if (!_isWebViewLoading) {
            if (_progressView.progress >= 1) {
                _progressView.hidden = true
                _progressTimer?.invalidate()
            } else {
                _progressView.progress += 0.2
            }
        } else {
            _progressView.progress += 0.003
            if (_progressView.progress >= 0.95) {
                _progressView.progress = 0.95
            }
        }
    }
    
    func loadURL(inputString: String) {
        let addrStr = urlifyUserInput(inputString)
        let addr = NSURL(string: addrStr)
        if let webAddr = addr {
            let req = NSURLRequest(URL: webAddr)
            _webView!.loadRequest(req)
        } else {
            displayLoadingErrorMessage()
        }
        
    }
    
    func displayLoadingErrorMessage() {
        _loadingErrorView.hidden = false
    }
    
    func handleGoBackPan(sender: UIScreenEdgePanGestureRecognizer) {
        if NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.ForwardBackGesture.rawValue) as! Bool == true {
            if (sender.state == .Began) {
                _webView!.goBack()
            }
        }
    }
    
    func handleGoForwardPan(sender: AnyObject) {
        if NSUserDefaults.standardUserDefaults().objectForKey(AppDefaultKeys.ForwardBackGesture.rawValue) as! Bool == true {
            if (sender.state == .Began) {
                _webView!.goForward()
            }
        }
    }
    
    // Framer.js Bonjour Integration
    
    func didResolveAddress(address: String) {
        if !_alertBuilder.isAlertOpen {
            var windowCount = UIApplication.sharedApplication().windows.count
            var targetView = UIApplication.sharedApplication().windows[windowCount-1].rootViewController!
            _framerAddress = address
            var alert = _alertBuilder.show(targetView as UIViewController!, title: "Connect to Framer?", text: "Looks like you (or someone on your network) is running Framer Studio. Want to connect?", cancelButtonText: "Nope", buttonText: "Sure!", color: UIColorFromHex(0x9178E2))
            alert.addAction(handleAlertConfirmTap)
            alert.setTextTheme(.Light)
            alert.setTitleFont("ClearSans")
            alert.setTextFont("ClearSans")
            alert.setButtonFont("ClearSans")
        }
    }
    
    func handleAlertConfirmTap() {
        loadFramer(_framerAddress!)
    }
    
    func loadFramer(address: String) {
        hideSearch()
        loadURL(address)
    }
    
    func startSearching() {
        _framerBonjour.start()
    }
    
    func stopSearching() {
        _framerBonjour.stop()
    }
    
    
    
    //MARK: -  Search bar
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        hideSearch()
        loadURL(searchBar.text)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        hideSearch()
    }
    
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        var enable = false
        if (count(_searchBar.text) > 0 && _isCurrentPageLoaded) {
            enable = true
        }
        _searchBar.refreshButton().enabled = enable
        return true
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        _searchBar.refreshButton().enabled = false
    }
    
    func searchBarRefreshWasPressed() {
        hideSearch()
        if let urlString = _webView?.URL?.absoluteString {
            _searchBar.text = urlString
        }
        loadURL(_searchBar.text)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animateAlongsideTransition({ context in
            self._webView!.frame = CGRectMake(0, 0, size.width, size.height)
            }, completion: nil)
    }
    
    /**
    扫描成功
    
    :param: result 扫描结果
    */
    func scanSucceed(result: String){
        hideSearch()
        _searchBar.text = result
        loadURL(_searchBar.text)
    }
    
    /**
    选择收藏条目成功
    
    :param: urlStr 链接地址
    */
    func selectCollectItemSucceed(urlStr: String){
        hideSearch()
        _searchBar.text = urlStr
        loadURL(_searchBar.text)
    }
    
}

