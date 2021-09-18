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
//  10/4  add fixed params for note,vol,pan
//  2/3   add comment field
//  2/28  redo bottom / top midi
//  4/18  add rotTrigger
//  4/30  change shapeName to shapeKey
//  5/9   make detune editable param
import Foundation
struct OVStruct : Codable {

    var key          : String //4/30 stored in dictionary under this key
    var name         : String
    var comment      : String
    var patchName    : String
    var shapeKey     : String //4/30 points to shape by key
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
    var rotTrigger   : Double   //4/18 for triggering percussion
    
    //10/3 move from oogiePatch..
    //  no save with voice as it was!
    var poly        : Int //These 2 are opposites
    var mono        : Int
    var thresh      : Int
    var quant       : Int
    var topMidi     : Int
    var bottomMidi  : Int
    var keySig      : Int
    var uid         : String //5/1
    
    //8/11/21 performance params
    var portamento   : Int
    var vibLevel     : Int
    var vibSpeed     : Int
    var vibWave      : Int
    var vibeLevel    : Int
    var vibeSpeed    : Int
    var vibeWave     : Int
    var delayTime    : Int
    var delaySustain : Int
    var delayMix     : Int

 
    
    //======(OVStruct)=============================================
    init()
    {
        key          = ""
        name         = "empty"
        comment      = ""
        patchName    = "empty"
        shapeKey     = ""
        level        = 1.0 //Overall level  9/16 make 1
        xCoord       = 0.0
        yCoord       = 0.1 //DHS 9/16 off equator
        sampleOffset = 0
        detune       = 0
        pitchShift   = 0   //4/19 why was this 1?
        whichSamp    = 0
        sampleOffset = 0
        midiDevice   = 0
        midiChannel  = 0
        noteMode     = 3    //4/14/20 initialize to Hue for note modes
        volMode      = 9    //        ...fixed for volume / pan
        panMode      = 9
        noteFixed    = 64   //Middle C   10/4 add fixed values for all channels
        volFixed     = 128  //half level
        panFixed     = 128  //center pan
        octave       = 0
        rotTrigger   = 0.0    //no rotation trigger
        //10/3 moved in from patch. these are performance variables!
        poly        = 1
        mono        = 0
        thresh      = 5
        quant       = 0
        bottomMidi  = 40   //5/14 new defaults
        topMidi     = 80
        keySig      = 0
        
        //8/11 performance params
        portamento   = 0
        vibLevel     = 0
        vibSpeed     = 0
        vibWave      = 0
        vibeLevel    = 0
        vibeSpeed    = 0
        vibeWave     = 0
        delayTime    = 0
        delaySustain = 0
        delayMix     = 0

        //5/1 uid
        uid = "voice_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(OVStruct)=============================================
    // 10/3 restruct
    mutating func clear()
    {
        name         = "empty"
        comment      = COMMENT_DEFAULT //2/3 from appDelegate
        patchName    = "empty"
        shapeKey     = ""
        level        = 1.0 //Overall level  9/16 make 1
        xCoord       = 0.0
        yCoord       = 0.1 //DHS 9/16 off equator
        sampleOffset = 0
        detune       = 0
        pitchShift   = 0  //4/19
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
        bottomMidi  = 40   // 5/14 new defaults
        topMidi     = 80
        keySig      = 0
        //8/11 performance params
        portamento   = 0
        vibLevel     = 0
        vibSpeed     = 0
        vibWave      = 0
        vibeLevel    = 0
        vibeSpeed    = 0
        vibeWave     = 0
        delayTime    = 0
        delaySustain = 0
        delayMix     = 0


    }
    
    //======(OSStruct)=============================================
    func getNewUID() -> String
    {
        return "voice_" + ProcessInfo.processInfo.globallyUniqueString
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

    //======(OogieShape)=============================================
    func dump()
    {
        DataManager.dump(self)
    }
    

    
    
}

