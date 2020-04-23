//
//  OogieShape.swift
//  oogie2D
//
//  Created by Dave Scruton on 1/21/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//
//  4/22 add getParam func

import Foundation
class OogieShape: NSObject {

   var uid  = ""
   var OOS  = OSStruct()  // codable struct for i/o
   var inPipes = Set<String>()   //use insert and remove to manage...
    //-----------(oogieShape)=============================================
    override init() {
        super.init()
        uid = ProcessInfo.processInfo.globallyUniqueString
    }
    
    //-----------(oogieShape)=============================================
    // 4/22/20 gets param named "whatever", returns tuple
    func getParam(named name : String) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = "empty"
        switch (name)
        {
        case "texture" :     sp = OOS.texture
        case "rotation":     dp = OOS.rotSpeed
        case "rotationtype": dp = OOS.rotation
        case "xpos":         dp = OOS.xPos
        case "ypos":         dp = OOS.yPos
        case "zpos":         dp = OOS.zPos
        case "texxoffset":   dp = OOS.uCoord
        case "texyoffset":   dp = OOS.vCoord
        case "texxscale":    dp = OOS.uScale
        case "texyscale":    dp = OOS.vScale
        case "name":         sp = OOS.name
        case "comment":      sp = OOS.comment
        default:print("Error:Bad shape param")
        }
        return(name , dp , sp)
    } //end param


}
