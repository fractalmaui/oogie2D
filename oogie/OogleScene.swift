//
//  OogleScene.swift
//  oogie2D
//
//  Created by Dave Scruton on 8/24/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
//  a shape looks like this:
//    shapeName : edits
//   where shapeName refers to a canned shape, and edits describe any changes to it
//    like:  xpos = 2.0 , ypos = 3.0 , uScale = 0.5, etc
//
//  9/15   add dump
// 10/27   redu createDefaultScene
// 11/22   add version , params strings
import Foundation
import SceneKit

struct OogieScene : Codable {
    var name    : String
    var version : String
    var params  : String
    var shapes  : Dictionary<String, OogieShape>
    var voices  : Dictionary<String, OVStruct>
    
    //======(OogieScene)=============================================
    init()
    {
        name    = "scene000"
        //11/22 add version / params
        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        params  = ""
        shapes  = Dictionary<String, OogieShape>()
        voices  = Dictionary<String, OVStruct>()
    }
    
    //======(OogieScene)=============================================
    mutating func clearScene()
    {
        name  = "empty"
        shapes.removeAll()
        voices.removeAll()
    }
    
    //======(OogieScene)=============================================
    // creates default sphere with one default voice
    mutating func createDefaultScene(sname:String)
    {
        name                = sname
        var shape           = OogieShape()
        shape.name          = "shape001" //10/27 redo
        var voice           = OVStruct()
        voice.name          = "voice001"
        voice.patchName     = "SineWave"
        voice.shapeName     = shape.name
        //update our dictionaries
        voices[voice.name]  = voice
        shapes[shape.name]  = shape
    } //end createDefaultScene

    //======(OogieScene)=============================================
    // Scene gets saved by name
    mutating func saveItem() {
        packParams() //11/22
        DataManager.saveScene(self, with: name)
    }
    
    //======(OogieScene)=============================================
    // 11/22 scene params exist separately in viewController for now,
    //  they get packed up into a string at save time...
    func setDefaultParams()
    {
        OVtempo = 135
    }
    
    //======(OogieScene)=============================================
    // 11/22 params format: name:value,name:value,...
    mutating func packParams()
    {
        params = packIntParam(n: "tempo",vi: OVtempo)
    } //end packParams
    
    //======(OogieScene)=============================================
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
                if let ivf = Int(fieldVal)
                {
                    intFieldVal = ivf
                }
                switch fieldName.lowercased()
                {
                    case "tempo" : OVtempo = intFieldVal
                    default      : break;
                }
            }
        }
    } //end unpackParams
    
    //======(OogieScene)=============================================
    // 11/22
    func packIntParam(n:String , vi:Int) -> String
    {
        return String(format: "%@:%d", n,vi)
    }
    
    //======(OogieScene)=============================================
    // 11/22
    func packDoubleParam(n:String , vd:Int) -> String
    {
        return String(format: "%@:%4.2f", n,vd)
    }
    

    //======(OogieScene)=============================================
    func dump()
    {
        DataManager.dump(self)
        // 11/22
        print("Params...")
        print("  tempo: \(OVtempo)")
    }

}
