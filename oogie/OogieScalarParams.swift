//
//    ___              _      ____            _            ____
//   / _ \  ___   __ _(_) ___/ ___|  ___ __ _| | __ _ _ __|  _ \ __ _ _ __ __ _ _ __ ___  ___
//  | | | |/ _ \ / _` | |/ _ \___ \ / __/ _` | |/ _` | '__| |_) / _` | '__/ _` | '_ ` _ \/ __|
//  | |_| | (_) | (_| | |  __/___) | (_| (_| | | (_| | |  |  __/ (_| | | | (_| | | | | | \__ \
//   \___/ \___/ \__, |_|\___|____/ \___\__,_|_|\__,_|_|  |_|   \__,_|_|  \__,_|_| |_| |_|___/
//               |___/
//
//  OogieScalarParams.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/13/21
//  Copyright © 2019 fractallonomy. All rights reserved.
//  Params for oogieScalar objects: a scalar generates a numeric control signal
//   for other objects, much like a pipe but only upon user interaction

import Foundation
import SceneKit


@objc class OogieScalarParams: NSObject {

    static let sharedInstance = OogieScalarParams()
    //Output params depend on object scalar is hooked up to...
    let OutputParamParams    : [Any] = ["OutputParam",  "string","mt"]
    let XParams              : [Any] = ["XPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ] //10/3 changed default
    let YParams              : [Any] = ["YPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ]
    let ZParams              : [Any] = ["ZPos" , "double", -maxMeters , maxMeters , 0.0, 10.0, -5.0 ]
    let ScalarLoRangeParams  : [Any] = ["LoRange" , "double", 0.0 , 1.0 , 0.5, 1.0, 0.0 ] //10/17 redo ranges
    let ScalarHiRangeParams  : [Any] = ["HiRange" , "double", 0.0 , 1.0 , 0.5, 1.0, 0.0 ]
    let InvertParams         : [Any] = ["Invert",  "string","off","on"]
    let ScalarNameParams     : [Any] = ["Name",         "text", "mt"]
    let ScalarCommParams     : [Any] = ["Comment",      "text", "mt"]
    // This is an array of all parameter names...
    let scalarParamNames     : [String] = ["OutputParam","LoRange","HiRange","Name","Comment"]

    var scalarParamsDictionary = Dictionary<String, [Any]>()

    //======(OogieScalarParams)=============================================
    override init() {
        super.init()
        setupScalarParams()
    }

    
    //-----------(OogieScalarParams)=============================================
    func setupScalarParams()
    {
        scalarParamsDictionary["outputparam"]  = OutputParamParams
        scalarParamsDictionary["xpos"]         = XParams
        scalarParamsDictionary["ypos"]         = YParams
        scalarParamsDictionary["zpos"]         = ZParams
        scalarParamsDictionary["lorange"]      = ScalarLoRangeParams
        scalarParamsDictionary["hirange"]      = ScalarHiRangeParams
        scalarParamsDictionary["invert"]       = InvertParams
        scalarParamsDictionary["name"]         = ScalarNameParams
        scalarParamsDictionary["comment"]      = ScalarCommParams
    } //end setupParams
    
    //-----------(oogieScalarParams)=============================================
    func getParamType(pname:String) -> String
    {
        //quick check for param type
        if let params = scalarParamsDictionary[pname]
        {
            let ptype  = params[1] as! String
            return ptype
        }
        return ""
    }

     
} //end OogieScalar struct

