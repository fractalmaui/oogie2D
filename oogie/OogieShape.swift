//
//  OogieShape.swift
//  oogie2D
//
//  Created by Dave Scruton on 1/21/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//

import Foundation
class OogieShape: NSObject {

   var uid  = ""
   var OOS  = OSStruct()  // codable struct for i/o
   var inPipes = Set<String>()   //use insert and remove to manage...
    //-----------(oogieVoice)=============================================
    override init() {
        super.init()
        uid = ProcessInfo.processInfo.globallyUniqueString
    }

}
