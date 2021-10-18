//
//    ___  ____ ____  _                   _
//   / _ \/ ___/ ___|| |_ _ __ _   _  ___| |_
//  | | | \___ \___ \| __| '__| | | |/ __| __|
//  | |_| |___) |__) | |_| |  | |_| | (__| |_
//   \___/|____/____/ \__|_|   \__,_|\___|\__|
//
//  OSStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 8/16/19.
//
//  9/10 add shapeParamsDictionary et al
//  9/15 add dump
//  10/18 add shape params
//  10/21 add getPosition
//  10/25 change rotParams
//  1/21  change to OSStruct for symmetry w/ OVStruct
//  2/3   add comment field
//  10/7  change name default
import SceneKit

//Parameter area...
let maxMeters = 10.0


import Foundation
struct OSStruct : Codable {
    var key          : String //4/30 stored in dictionary under this key
    var name         : String
    var comment      : String    //2/3 new field
    var primitive    : String
    var texture      : String
    var xPos         : Double
    var yPos         : Double
    var zPos         : Double
    var uCoord       : Double
    var vCoord       : Double
    var uScale       : Double
    var vScale       : Double
    var rotation     : Double
    var rotSpeed     : Double
    var rotXaxis     : Double
    var rotYaxis     : Double
    var rotZaxis     : Double
    var uid          : String


    //======(OSStruct)=============================================
    init()
    {
        key       = ""
        name      = "shape_00001"  //10/7 for new scene...
        comment   = COMMENT_DEFAULT //2/3 from appDelegate
        primitive = "sphere"
        texture   = "default"
        xPos      = 0.0
        yPos      = 0.0
        zPos      = 0.0
        uCoord    = 0.0
        vCoord    = 0.0
        uScale    = 1.0
        vScale    = 1.0
        rotation  = 0.0
        rotSpeed  = 8.0  //Canned, must match sphereShape
        //Start rotation about Y axis (should point up)
        rotXaxis  = 0.0
        rotZaxis  = 0.0
        rotYaxis  = 1.0
        uid = "shape_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(OSStruct)=============================================
    func getNewUID() -> String
    {
        return "shape_" + ProcessInfo.processInfo.globallyUniqueString
    }

    //======(OSStruct)=============================================
    func getPosition() ->SCNVector3
    {
        return SCNVector3(xPos,yPos,zPos)
    }
    
    //======(OSStruct)=============================================
    // Shape gets saved by name
    func saveItem() {
        DataManager.saveShape(self, with: name) //itemIdentifier.uuidString)
    }
    
    //======(OSStruct)=============================================
    func dump()
    {
        DataManager.dump(self)
    }

    
}
