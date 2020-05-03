//   _          _    __     ______
//  | |__   ___| |_ _\ \   / / ___|
//  | '_ \ / _ \ | '_ \ \ / / |
//  | | | |  __/ | |_) \ V /| |___
//  |_| |_|\___|_| .__/ \_/  \____|
//               |_|
//
//  helpVC.swift
//  Oogie2D
//
//  Created by Dave Scruton on 11/8/19.
//  Copyright © 2020 fractallonomy. All rights reserved.
//

import UIKit
import WebKit

class helpVC:   UIViewController,WKUIDelegate {
    @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var webView: WKWebView!
    var anchor = "" 
    override func viewDidLoad() {
        super.viewDidLoad()
        print("help, anchor \(anchor)")
        loadHelpHTML()
    }
    
    
    //=============Help VC=====================================================
    func loadHelpHTML()
    {
        
    }
 
    //=============Help VC=====================================================
    @IBAction func backSelect(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
