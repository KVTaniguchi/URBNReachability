//
//  ViewController.swift
//  URBNReachability
//
//  Created by Kevin Taniguchi on 4/19/17.
//  Copyright © 2017 URBN. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var reachable: Reachability? = Reachability.internetReachabilty()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachableChanged) , name: NSNotification.Name.reachability, object: nil)
     
        view.backgroundColor = .red
        
        _ = reachable?.startNotifiying()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateReachable()
    }
    
    func reachableChanged() {
        updateReachable()
    }
    
    func updateReachable() {
        guard let r = reachable else { return }
        view.backgroundColor = r.isReachable ? .green : .red
    }
    
    deinit {
        reachable?.stopNotifying()
    }
}

