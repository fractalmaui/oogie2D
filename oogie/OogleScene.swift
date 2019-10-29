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

import Foundation
import SceneKit

var OVtempo = 135 //Move to params ASAP

struct OogieScene : Codable {
    var name    : String
    var shapes  : Dictionary<String, OogieShape>
    var voices  : Dictionary<String, OVStruct>

    
    //======(OogieScene)=============================================
    init()
    {
        name    = "scene000"
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
    func saveItem() {
        DataManager.saveScene(self, with: name)
    }
    
    //======(OogieScene)=============================================
    func dump()
    {
        DataManager.dump(self)
    }

}
