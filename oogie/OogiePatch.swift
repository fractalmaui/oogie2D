//    ___              _      ____       _       _
//   / _ \  ___   __ _(_) ___|  _ \ __ _| |_ ___| |__
//  | | | |/ _ \ / _` | |/ _ \ |_) / _` | __/ __| '_ \
//  | |_| | (_) | (_| | |  __/  __/ (_| | || (__| | | |
//   \___/ \___/ \__, |_|\___|_|   \__,_|\__\___|_| |_|
//               |___/
//
//  OogiePatch
//  oogie2D
//
//  Created by Dave Scruton on 8/3/19.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//  Saves a patch for oogie, Codable means it can go to/from JSON txt easily
//  9/23 made percLoox into strings
//  10/14 pull wtype, redundant w/ wave!
//  10/15 add dump
//  11/17 add gotAllZeroes
//  11/24 add xtraParams 
//  2/12  3 new params, pLevel, pKeyOffset, pKeyDetune
import Foundation
struct OogiePatch : Codable {
    
    var name : String
    var type : Int    //Synth, Sample, PercSet, etc
    var wave  : Int   //Synth wave type: sine, ramp, etc
    var attack : Double
    var decay : Double
    var sustain : Double
    var sLevel : Double //Sustain level! (different)
    var release : Double
    var duty : Double
    var sampleOffset  : Int
    var pLevel : Int
    var pKeyOffset : Int
    var pKeyDetune : Int
    var percLoox     : Array<String> = ["mt","mt","mt","mt","mt","mt","mt","mt"]
    var percLooxPans : Array<Int> = [0,1,2,3,4,5,6,7]
    var xtraParams : String //11/24 for performance params / futurproofing

    var createdAt:Date
    var itemIdentifier:UUID
    
    var SYNTH_VOICE = 1 //kluge: defined in synth area
     
    //======(OogiePatch)=============================================
    init()
    {
        name = "empty"
        type = Int(SYNTH_VOICE)
        wave = 0      //Ramp
        attack = 0.0
        decay = 0.0
        sustain = 0.0
        sLevel = 0.0 //Sustain level! (different)
        release = 0.0
        duty = 0.0
        sampleOffset = 0
        pLevel     = 50   //2/12/21 new params
        pKeyOffset = 50
        pKeyDetune = 50
        percLoox     = ["mt","mt","mt","mt","mt","mt","mt","mt"]
        percLooxPans = [0,1,2,3,4,5,6,7]
        xtraParams   = ""
        createdAt = Date()
        itemIdentifier = UUID()
    }
    
    //======(OogiePatch)=============================================
    mutating func clear()
    {
        wave = 0         //Ramp
        attack = 0.0
        decay = 0.0
        sustain = 0.0
        sLevel = 0.0 //Sustain level! (different)
        release = 0.0
        duty = 0.0
        sampleOffset = 0
    } //end clear
    
    
    //======(OogiePatch)=============================================
    // 11/8 Patch gets saved by name
    func saveItem(filename : String , cat : String) {
        DataManager.savePatch(self, with: filename , cat:cat) //itemIdentifier.uuidString)
    }

  
    //======(OogiePatch)=============================================
    func isEqualTo (s : OogiePatch) -> Bool
    {
        var result = true
        result = result && (self.name != s.name)
        result = result && (self.type != s.type)
        result = result && (self.wave != s.wave)
        result = result && (self.attack != s.attack)
        result = result && (self.decay != s.decay)
        result = result && (self.sustain != s.sustain)
        result = result && (self.sLevel != s.sLevel)
        result = result && (self.release != s.release)
        result = result && (self.sampleOffset != s.sampleOffset)
        result = result && (self.percLoox != s.percLoox)
        result = result && (self.percLooxPans != s.percLooxPans)
        return result
    }

    //======(OogiePatch)=============================================
    // Hmm not sure here!
    func deleteItem() {
        DataManager.delete( itemIdentifier.uuidString)
    }
    
    //======(OogiePatch)=============================================
    //11/17 Should i include slevel?
    func gotAllZeroes() -> Bool
    {
        return attack == 0.0 && decay == 0.0 &&
               sustain == 0.0 && release == 0.0
    }
    //======(OogiePatch)=============================================
//    mutating func markAsCompleted() {
//        self.completed = true
//        DataManager.save(self, with: itemIdentifier.uuidString)
//    }
    
    //======(OogiePatch)=============================================
    func dump()
    {
        DataManager.dump(self)
    }

}
