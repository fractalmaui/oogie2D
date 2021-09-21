//
//    ___              _      ____  _            ____
//   / _ \  ___   __ _(_) ___|  _ \(_)_ __   ___|  _ \ __ _ _ __ __ _ _ __ ___  ___
//  | | | |/ _ \ / _` | |/ _ \ |_) | | '_ \ / _ \ |_) / _` | '__/ _` | '_ ` _ \/ __|
//  | |_| | (_) | (_| | |  __/  __/| | |_) |  __/  __/ (_| | | | (_| | | | | | \__ \
//   \___/ \___/ \__, |_|\___|_|   |_| .__/ \___|_|   \__,_|_|  \__,_|_| |_| |_|___/
//               |___/               |_|
//
//  OogiePipeParams.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/19/21
//  Copyright © 2019 fractallonomy. All rights reserved.
//  Params for oogiePipe objects. singleton, created once

import Foundation
import SceneKit


@objc class OogiePipeParams: NSObject {

    static let sharedInstance = OogiePipeParams()


    //12/1 add params
    let InputChanParams      : [Any]   = ["InputChannel", "string", "Red", "Green", "Blue", "Hue",
                                      "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow"]
    let OutputParamParams    : [Any] = ["OutputParam",  "string","mt"]
    //Not confusing at all, huh? This is the param where the pipename is entered
    let PipeLoRangeParams    : [Any] = ["LoRange" , "double", 0.0 , 255.0 , 128.0, 255.0, 0.0 ]
    let PipeHiRangeParams    : [Any] = ["HiRange" , "double", 0.0 , 255.0 , 128.0, 255.0, 0.0 ]
    let PipeNameParams       : [Any] = ["Name",         "text", "mt"]
    let PipeCommParams       : [Any] = ["Comment",      "text", "mt"]
    // This is an array of all parameter names...
    let pipeParamNames : [String] = ["InputChannel", "OutputParam","LoRange","HiRange","Name","Comment"]

    var pipeParamsDictionary = Dictionary<String, [Any]>()

    //======(OogiePipeParams)=============================================
    override init() {
        super.init()
        setupPipeParams()
    }

    
    //-----------(OogiePipeParams)=============================================
    func setupPipeParams()
    {
        //9/19/21 also add string keys
        pipeParamsDictionary["inputchannel"] = InputChanParams
        pipeParamsDictionary["outputparam"]  = OutputParamParams
        pipeParamsDictionary["lorange"]      = PipeLoRangeParams
        pipeParamsDictionary["hirange"]      = PipeHiRangeParams
        pipeParamsDictionary["name"]         = PipeNameParams
        pipeParamsDictionary["comment"]      = PipeCommParams

        // Load up params dictionary with string / array combos
        pipeParamsDictionary["00"] = InputChanParams
        pipeParamsDictionary["01"] = OutputParamParams
        pipeParamsDictionary["02"] = PipeLoRangeParams
        pipeParamsDictionary["03"] = PipeHiRangeParams
        pipeParamsDictionary["04"] = PipeNameParams
        pipeParamsDictionary["05"] = PipeCommParams
    } //end setupParams
    
    //-----------(oogiePipeParams)=============================================
    func getParamType(pname:String) -> String
    {
        //quick check for param type
        if let params = pipeParamsDictionary[pname]
        {
            let ptype  = params[1] as! String
            return ptype
        }
        return ""
    }

     
} //end OogiePipe struct

