//    ___  ____   ____ ____  _                   _
//   / _ \/ ___| / ___/ ___|| |_ _ __ _   _  ___| |_
//  | | | \___ \| |   \___ \| __| '__| | | |/ __| __|
//  | |_| |___) | |___ ___) | |_| |  | |_| | (__| |_
//   \___/|____/ \____|____/ \__|_|   \__,_|\___|\__|                                                 
//  OogleScene.swift
//  oogie2D
//
//  Created by Dave Scruton on 4/30/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//
//  This used to be OogieScene, but I moved it into a sub-struct
//   that is now part of OogieScene. That way I could add things
//   like the runtime scene storage, selected items, etc. without
//   breaking the Codable protocol.

import Foundation
import SceneKit

struct OSCStruct : Codable {
    var comment   : String
    var name      : String
    var ooversion : String   //2/3 easier to find in json data!
    var params    : String
    var shapes    : Dictionary<String, OSStruct>
    var voices    : Dictionary<String, OVStruct>
    var pipes     : Dictionary<String, PipeStruct>
    var scalars   : Dictionary<String, ScalarStruct>  //10/13 new

    //======(OSCStruct)=============================================
    init()
    {
        name      = "scene000"
        comment   = COMMENT_DEFAULT //2/3 from appDelegate
        //11/22 add version / params
        ooversion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        params    = ""
        shapes    = Dictionary<String, OSStruct>()
        voices    = Dictionary<String, OVStruct>()
        pipes     = Dictionary<String, PipeStruct>()
        scalars   = Dictionary<String, ScalarStruct>() //10/13 new
    }
    
    //======(OSCStruct)=============================================
    mutating func clearScene()
    {
        name = "empty"
        shapes.removeAll()
        voices.removeAll()
        pipes.removeAll()
        scalars.removeAll()   //10/13 new
    }
    
    //======(OSCStruct)=============================================
    // Scene gets saved by name
    mutating func saveItem() {
        packParams() //11/22
        DataManager.saveScene(self, with: name)
    }
    
    //======(OSCStruct)=============================================
    //11/22 get shape names into list
    func getListOfShapes() -> [String]
    {
        var troutput : [String] = []
        for (n,_) in shapes {troutput.append(n)}
        return troutput
    }

    //======(OSCStruct)=============================================
    //11/22 get shape names into list
    func getListOfVoices() -> [String]
    {
        var troutput : [String] = []
        for (n,_) in voices {troutput.append(n)}
        return troutput
    }
    

    
    //======(OSCStruct)=============================================
    // 11/22 scene params exist separately in viewController for now,
    //  they get packed up into a string at save time...
    func setDefaultParams()
    {
        OVtempo = 135
    }
    
    //======(OSCStruct)=============================================
    // 11/22 params format: name:value,name:value,...
    mutating func packParams()
    {
        params = packIntParam(n: "tempo",vi: OVtempo)
        // 5/1 camXform comes from viewController.  SLOPPY!
        params = params + "," + packFloatParam(n: "m11", vf:camXform.m11)
        params = params + "," + packFloatParam(n: "m12", vf:camXform.m12)
        params = params + "," + packFloatParam(n: "m13", vf:camXform.m13)
        params = params + "," + packFloatParam(n: "m14", vf:camXform.m14)
        params = params + "," + packFloatParam(n: "m21", vf:camXform.m21)
        params = params + "," + packFloatParam(n: "m22", vf:camXform.m22)
        params = params + "," + packFloatParam(n: "m23", vf:camXform.m23)
        params = params + "," + packFloatParam(n: "m24", vf:camXform.m24)
        params = params + "," + packFloatParam(n: "m31", vf:camXform.m31)
        params = params + "," + packFloatParam(n: "m32", vf:camXform.m32)
        params = params + "," + packFloatParam(n: "m33", vf:camXform.m33)
        params = params + "," + packFloatParam(n: "m34", vf:camXform.m34)
        params = params + "," + packFloatParam(n: "m41", vf:camXform.m41)
        params = params + "," + packFloatParam(n: "m42", vf:camXform.m42)
        params = params + "," + packFloatParam(n: "m43", vf:camXform.m43)
        params = params + "," + packFloatParam(n: "m44", vf:camXform.m44)

    } //end packParams
    
    //======(OSCStruct)=============================================
    // 11/22
    func unpackParams()
    {
        //break up params first...
        let ss = params.split(separator: ",")  //fields separated by commas
        for s in ss //Get each field...
        {
            var fieldName = ""  //we will get 2 strings, L/R side of colon separator
            var fieldVal  = ""
            let pp        = s.split(separator:":")
            if pp.count == 2 //2 subfields?
            {
                fieldName = String(pp[0])
                fieldVal  = String(pp[1])
                // Prepare numeric fields if needed...
                var intFieldVal = 0
                if let ivf = Int(fieldVal) { intFieldVal = ivf }
                var floatFieldVal = Float(0.0)
                if let fvf = Float(fieldVal) { floatFieldVal = fvf }
                switch fieldName.lowercased()
                {
                case "tempo" : OVtempo = intFieldVal
                case "m11"   : camXform.m11 = floatFieldVal
                case "m12"   : camXform.m12 = floatFieldVal
                case "m13"   : camXform.m13 = floatFieldVal
                case "m14"   : camXform.m14 = floatFieldVal
                case "m21"   : camXform.m21 = floatFieldVal
                case "m22"   : camXform.m22 = floatFieldVal
                case "m23"   : camXform.m23 = floatFieldVal
                case "m24"   : camXform.m24 = floatFieldVal
                case "m31"   : camXform.m31 = floatFieldVal
                case "m32"   : camXform.m32 = floatFieldVal
                case "m33"   : camXform.m33 = floatFieldVal
                case "m34"   : camXform.m34 = floatFieldVal
                case "m41"   : camXform.m41 = floatFieldVal
                case "m42"   : camXform.m42 = floatFieldVal
                case "m43"   : camXform.m43 = floatFieldVal
                case "m44"   : camXform.m44 = floatFieldVal
                default      : break;
                }
            }
        }
        //dump()
    } //end unpackParams
    
    //======(OSCStruct)=============================================
    // 11/22
    func packIntParam(n:String , vi:Int) -> String
    {
        return String(format: "%@:%d", n,vi)
    }
    
    //======(OSCStruct)=============================================
    // 11/24
    func packFloatParam(n:String , vf:Float) -> String
    {
        return String(format: "%@:%4.2f", n,vf)
    }
    

    //======(OSCStruct)=============================================
    // 12/27 new
    func getDumpString() -> String
    {
        let s = DataManager.getDumpString(self)
        return s
    }

    //======(OSCStruct)=============================================
    func dump()
    {
        DataManager.dump(self)
        // 11/22
        print("Params...")
        print("  tempo: \(OVtempo)")
    }

    
}
