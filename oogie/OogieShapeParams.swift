//
//    ___              _      ____  _                      ____
//   / _ \  ___   __ _(_) ___/ ___|| |__   __ _ _ __   ___|  _ \ __ _ _ __ __ _ _ __ ___  ___
//  | | | |/ _ \ / _` | |/ _ \___ \| '_ \ / _` | '_ \ / _ \ |_) / _` | '__/ _` | '_ ` _ \/ __|
//  | |_| | (_) | (_| | |  __/___) | | | | (_| | |_) |  __/  __/ (_| | | | (_| | | | | | \__ \
//   \___/ \___/ \__, |_|\___|____/|_| |_|\__,_| .__/ \___|_|   \__,_|_|  \__,_|_| |_| |_|___/
//               |___/                         |_|
//  OogieShapeParams.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/19/21
//  Copyright © 2020 fractallonomy. All rights reserved.
//  Params for oogieShape objects. singleton, created once
//  9/28 pulled numeric param dict entries
//  10/3 NOTE defaults (field 4) are in slider units! WTF???

import Foundation

class OogieShapeParams: NSObject {
    
    static let sharedInstance = OogieShapeParams()
 
    //Parmas: Name,Type,Min,Max,Default,DisplayMult,DisplayOffset?? (string params need a list of items)
    let TexParams   : [Any] = ["Texture", "texture", "mt"]
    let RotParams   : [Any] = ["Rotation" , "double", 0.0  , 100.0   , 1.0, 10.0, 0.0 ]
    let RotTypeParams  : [Any] = ["RotationType", "string" , "Manual", "BPMX1", "BPMX2", "BPMX3", "BPMX4", "BPMX5", "BPMX6", "BPMX7", "BPMX8" ]
    let XParams     : [Any] = ["XPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ] //10/3 changed default
    let YParams     : [Any] = ["YPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ]
    let ZParams     : [Any] = ["ZPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ]
    let UParams     : [Any] = ["TexXoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
    let VParams     : [Any] = ["TexYoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
    let USParams    : [Any] = ["TexXscale" , "double", 0.1 , 10.0 , 1.0, 10.0, 0.0 ]
    let VSParams    : [Any] = ["TexYscale" , "double", 0.1 , 10.0 , 1.0, 10.0, 0.0 ]
    let SNameParams : [Any] = ["Name",      "text", "mt"]
    let SCommParams : [Any] = ["Comment",   "text", "mt"]

    let shapeParamNames : [String] = ["Texture", "Rotation","RotationType",
    "XPos","YPos","ZPos","TexXoffset","TexYoffset","TexXscale","TexYscale","Name","Comment"]
    let shapeParamNamesOKForPipe : [String] = ["Rotation","RotationType","TexXoffset",
                                               "TexYoffset","TexXscale","TexYscale"]
    var shapeParamsDictionary = Dictionary<String, [Any]>()


    //-----------(oogieShape)=============================================
    override init() {
        super.init()
        setupShapeParams()
    }
    
     //-----------(oogieVoice)=============================================
    func setupShapeParams()
    {
        // 9/18/21 add named keys too
        shapeParamsDictionary["texture"] = TexParams
        shapeParamsDictionary["rotation"] = RotParams
        shapeParamsDictionary["rotationtype"] = RotTypeParams
        shapeParamsDictionary["xpos"] = XParams
        shapeParamsDictionary["ypos"] = YParams
        shapeParamsDictionary["zpos"] = ZParams
        shapeParamsDictionary["texxoffset"] = UParams
        shapeParamsDictionary["texyoffset"] = VParams
        shapeParamsDictionary["texxscale"] = USParams
        shapeParamsDictionary["texyscale"] = VSParams
        shapeParamsDictionary["name"] = SNameParams
        shapeParamsDictionary["comment"] = SCommParams
    } //end setupShapeParams
        
    //-----------(oogieShapeParams)=============================================
    func getParamType(pname:String) -> String
    {
        //quick check for param type
        if let params = shapeParamsDictionary[pname]
        {
            let ptype  = params[1] as! String
            return ptype
        }
        return ""
    }

    
}
