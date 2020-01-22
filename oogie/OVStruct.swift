//    _____     ______  _                   _
//   / _ \ \   / / ___|| |_ _ __ _   _  ___| |_
//  | | | \ \ / /\___ \| __| '__| | | |/ __| __|
//  | |_| |\ V /  ___) | |_| |  | |_| | (__| |_
//   \___/  \_/  |____/ \__|_|   \__,_|\___|\__|
//
//  OogieVoiceStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 8/15/19.
//  10/4 add fixed params for note,vol,pan

import Foundation
struct OVStruct : Codable {

    var name         : String
    var patchName    : String
    var shapeName    : String //THIS MAY BE REDUNDANT?? Patch has type too!
    var level        : Double
    var xCoord       : Double   // 0..1 domain X,Y vary
    var yCoord       : Double  //   according to shape voice is applied to
    var detune       : Int
    var pitchShift   : Int
    var whichSamp    : Int  //Huh? sampleOffset is in oogiePatch! Should these 2 be there instead?
    var sampleOffset : Int  //Huh? sampleOffset is in oogiePatch! Should these 2 be there instead?
    var midiDevice   : Int
    var midiChannel  : Int
    var noteMode     : Int   //Use a channel or fixed value for notes
    var volMode      : Int   //Use a channel or fixed value for volume level
    var panMode      : Int   //Use a channel or fixed value for pan LR
    var noteFixed    : Int
    var volFixed     : Int
    var panFixed     : Int
    var octave       : Int
    
    //10/3 move from oogiePatch..
    //  no save with voice as it was!
    var poly  : Int //These 2 are opposites
    var mono  : Int
    var thresh  : Int
    var quant  : Int
    var topMidi  : Int
    var bottomMidi  : Int
    var keySig  : Int

    
    //======(OVStruct)=============================================
    init()
    {
        name         = "empty"
        patchName    = "empty"
        shapeName    = "default"
        level        = 1.0 //Overall level  9/16 make 1
        xCoord       = 0.0
        yCoord       = 0.1 //DHS 9/16 off equator
        sampleOffset = 0
        detune       = 0
        pitchShift   = 1
        whichSamp    = 0
        sampleOffset   = 0
        midiDevice   = 0
        midiChannel  = 0
        noteMode     = 0
        volMode      = 0
        panMode      = 0
        noteFixed    = 64   //Middle C   10/4 add fixed values for all channels
        volFixed     = 128  //half level
        panFixed     = 128  //center pan

        octave       = 0
        //10/3 moved in from patch. these are performance variables!
        poly        = 1
        mono        = 0
        thresh      = 5
        quant       = 0
        topMidi     = 20
        bottomMidi  = 128
        keySig      = 0
    }
    
    //======(OVStruct)=============================================
    // 10/3 restruct
    mutating func clear()
    {
        name         = "empty"
        patchName    = "empty"
        shapeName    = "default"
        level        = 1.0 //Overall level  9/16 make 1
        xCoord       = 0.0
        yCoord       = 0.1 //DHS 9/16 off equator
        sampleOffset = 0
        detune       = 0
        pitchShift   = 1
        whichSamp    = 0
        sampleOffset   = 0
        midiDevice   = 0
        midiChannel  = 0
        noteMode     = 0
        volMode      = 0
        panMode      = 0
        noteFixed    = 64   //Middle C   10/4 add fixed values for all channels
        volFixed     = 128  //half level
        panFixed     = 128  //center pan
        octave       = 0
        //10/3 moved in from patch. these are performance variables!
        poly        = 1
        mono        = 0
        thresh      = 5
        quant       = 0
        topMidi     = 20
        bottomMidi  = 128
        keySig      = 0

    }
    
    //======(OVStruct)=============================================
    // Patch gets saved by name
    func saveItem() {
        DataManager.saveVoice(self, with: name) //itemIdentifier.uuidString)
    }
    
    //======(OVStruct)=============================================
    // Hmm not sure here!
    func deleteItem() {
        //DataManager.delete( itemIdentifier.uuidString)
    }

    //======(OVStruct)=============================================
    func dump()
    {
        DataManager.dump(self)
    }
    

    
    
}

