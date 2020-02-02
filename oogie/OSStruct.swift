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

import SceneKit

//Parameter area...
let maxMeters = 10.0

let TexParams : [Any] = ["Texture", "texture", "mt"]
let RotParams : [Any] = ["Rotation" , "double", 0.0  , 100.0   , 10.0, 1.0, 0.0 ]
let RotTypeParams  : [Any] = ["RotationType", "string" , "Manual", "BPMX1", "BPMX2", "BPMX3", "BPMX4", "BPMX5", "BPMX6", "BPMX7", "BPMX8" ]
let XParams   : [Any] = ["XPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let YParams   : [Any] = ["YPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let ZParams   : [Any] = ["ZPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let UParams   : [Any] = ["TexXoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
let VParams   : [Any] = ["TexYoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
let USParams   : [Any] = ["TexXscale" , "double", 0.1 , 10.0 , 1.0, 1.0, 0.0 ]
let VSParams   : [Any] = ["TexYscale" , "double", 0.1 , 10.0 , 1.0, 1.0, 0.0 ]

let shapeParamNames : [String] = ["Texture", "Rotation","RotationType",
"XPos","YPos","ZPos","TexXoffset","TexYoffset","TexXscale","TexYscale"]
let shapeParamNamesOKForPipe : [String] = ["Rotation","RotationType","TexXoffset",
                                           "TexYoffset","TexXscale","TexYscale"]

var shapeParamsDictionary = Dictionary<String, [Any]>()

import Foundation
struct OSStruct : Codable {
    var name         : String
    var primitive    : String
    var texture      : String
    var uid          : String
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
    var shapeCount   : Int  //auto increment for each shape?
    

    //======(OSStruct)=============================================
    init()
    {
        shapeCount = 0
        name      = "sphere"
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
        //9/8 unique ID for tab
        uid = ProcessInfo.processInfo.globallyUniqueString
        getNewShape()
        setupParams()
    }
    
    //-----------(oogieVoice)=============================================
    mutating func setupParams()
    {
        // Load up params dictionary with string / array combos
        shapeParamsDictionary["00"] = TexParams
        shapeParamsDictionary["01"] = RotParams
        shapeParamsDictionary["02"] = RotTypeParams
        shapeParamsDictionary["03"] = XParams
        shapeParamsDictionary["04"] = YParams
        shapeParamsDictionary["05"] = ZParams
        shapeParamsDictionary["06"] = UParams
        shapeParamsDictionary["07"] = VParams
        shapeParamsDictionary["08"] = USParams
        shapeParamsDictionary["09"] = VSParams
    } //end setupParams
        
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= shapeParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return shapeParamsDictionary[key]!
    }
    
    //======(OSStruct)=============================================
    func getParamCount() -> Int
    {
        return shapeParamNames.count
    }
    
    //======(OSStruct)=============================================
    mutating func getNewShape()
    {
        shapeCount = shapeCount + 1
        name = "shape" + String(format: "%03d", shapeCount)
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
