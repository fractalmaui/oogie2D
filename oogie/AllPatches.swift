//     _    _ _ ____       _       _
//    / \  | | |  _ \ __ _| |_ ___| |__   ___  ___
//   / _ \ | | | |_) / _` | __/ __| '_ \ / _ \/ __|
//  / ___ \| | |  __/ (_| | || (__| | | |  __/\__ \
// /_/   \_\_|_|_|   \__,_|\__\___|_| |_|\___||___/
//
//  AllPatches.swift
//  oogie2D
//
//  Created by Dave Scruton on 8/22/19.
//
//  need to add local load from documents..patches folder area
//   and maybe from DB too! (json strings stashed on db?)
//  9/13 change key in patchDictionary to lowercase
//  9/25 add getDefaultPatchByType
//  9/27 add type to patch getter
//  10/15 change getPatchByName
//  10/16 add GM patches
//  11/12 add getAllPatchInfo, new dictionaries
//  11/13 all datamanager loads go straight to dict, NOT array
import Foundation

//A lil info for each patch...goes into dictionary

struct PatchieInfo  {
    var builtin = true
    var factorySettingWasChanged = false
    var category = "GM"   //How is it easiest to communicate this and reduce lines of code?
    var name = "" //sanity check
}

//REGEX extension crap, makes regex easier to use...
//  https://benscheirman.com/2014/06/regex-in-swift/
//
//  https://rumorscity.com/wp-content/uploads/2014/08/Best-Regular-Expressions-Cheat-Sheet-02.jpg
extension NSRegularExpression {
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}



//AllPatches contains every patch. They are grouped into arrays and dictionaries.

class AllPatches {
//This is supposed to be a singleton...
static let sharedInstance = AllPatches()

//var builtInSynthPatches : [OogiePatch] = []
var builtInPercussionPatches : [OogiePatch] = []
var builtInGMPatches : [OogiePatch] = []
var storedPatches  : [OogiePatch] = []
    
var builtInPercKitPatches : [OogiePatch] = []
var allBuiltinPatchDictionary = Dictionary<String, OogiePatch>()
var allFactoryPatchDictionary = Dictionary<String, OogiePatch>()
var yuserPatchDictionary      = Dictionary<String, OogiePatch>()
var synthPatchDictionary      = Dictionary<String, OogiePatch>()
var percKitPatchDictionary    = Dictionary<String, OogiePatch>()
var percussionPatchDictionary = Dictionary<String, OogiePatch>()
var GMPatchDictionary         = Dictionary<String, OogiePatch>()
var GMNamesDictionary         = Dictionary<String, String>()
var GMOIffsetDictionary       = Dictionary<String, Int>()
//This is for ALL patches
var patchInfoDict             = Dictionary<String, PatchieInfo>()
// 10/18 GMfilenames -> GM instrument names
var GMNamesToInstrumentsDictionary = Dictionary<String, String>()
var sfx = soundFX.sharedInstance //10/19 for GMidi instrument lookup

//=====(AllPatches)=============================================
//This makes sure your singletons are truly unique and prevents
//  outside objects from creating their own instances of your class t
private init()
{
    DataManager.createSubfolders()  //Create subfolders if not yet there..
    //11/13 now we just load straight to dict(name,patch), NOT array
    yuserPatchDictionary     = DataManager.loadAllPatchesToDict(OogiePatch.self)

    synthPatchDictionary     = DataManager.loadBuiltinSynthPatchesToDict(OogiePatch.self,
                                                                         fromFactory: false)
    percussionPatchDictionary     = DataManager.loadBuiltinPercussionPatchesToDict(OogiePatch.self,
                                                                         fromFactory: false)
    percKitPatchDictionary     = DataManager.loadBuiltinPercKitPatchesToDict(OogiePatch.self,
                                                                         fromFactory: false)
    GMPatchDictionary     = DataManager.loadBuiltinGMPatchesToDict(OogiePatch.self,
                                                                         fromFactory: false)
    for (pname,_) in GMPatchDictionary //Get GM instrument lookups...
    {
        let iname = getInstrumentNameFromGMFilename(fname: pname)
        GMNamesToInstrumentsDictionary[pname] = iname
    }

    //10/18 we need gm names here!
    GMNamesDictionary = (sfx() as! soundFX).loadGeneralMidiNames() as! [String : String]

    //assemble allpatches everywhere.. (from 3 dictionaries)
    allBuiltinPatchDictionary = synthPatchDictionary.merging(percussionPatchDictionary) { (_, new) in new }
    print("tp1.....")
    dumpBuiltinPatch(n: "Casio")
    allBuiltinPatchDictionary = allBuiltinPatchDictionary.merging(percKitPatchDictionary) { (_, new) in new }
    allBuiltinPatchDictionary = allBuiltinPatchDictionary.merging(GMPatchDictionary) { (_, new) in new }

    //FACTORY=========== merge dicts from raw file input...
    allFactoryPatchDictionary = DataManager.loadBuiltinSynthPatchesToDict(OogiePatch.self,
                                                                         fromFactory: true)
    //Why do i have to break out dicts? straightline code dozent work?
    var workD = DataManager.loadBuiltinPercussionPatchesToDict(OogiePatch.self,
                                                               fromFactory: true)
    allFactoryPatchDictionary = allFactoryPatchDictionary.merging(workD) { (_, new) in new }
    workD = DataManager.loadBuiltinPercKitPatchesToDict(OogiePatch.self,
                                                               fromFactory: true)
    allFactoryPatchDictionary = allFactoryPatchDictionary.merging(workD) { (_, new) in new }
    workD = DataManager.loadBuiltinGMPatchesToDict(OogiePatch.self,
                                                               fromFactory: true)
    allFactoryPatchDictionary = allFactoryPatchDictionary.merging(workD) { (_, new) in new }
    print("tp4.....")
    dumpBuiltinPatch(n: "Casio")

    getAllPatchInfo()  //load basic info for every patch...
    loadGMOffsets() //11/10 compute octave / note offsets...
    print("...allpatches loaded")
}
    //=====(AllPatches)=============================================
    //  11/17 add new incoming patch, could be any type, only have name here!
    func addNewUserPatch (p : OogiePatch , n : String)
    {
        //asdf
        if patchExists(name:n) {return} //Bail on dupe! (should complain?)
        yuserPatchDictionary[n] = p //Done!
    }
    
    //=====(AllPatches)=============================================
    func dumpBuiltinPatch (n : String)
    {
        if let wp = allBuiltinPatchDictionary[n]
        {
            print("abpd casio \(wp)")
            wp.dump()
        }
    }
    
    //=====(AllPatches)=============================================
    //11/14 Tries to create string whatever_0123.
    //  if numeric part there, increments it
    func getNewNameForCopy(n : String) -> String
    {
        //first see if we have already got a numeric suffix...
        let regex = NSRegularExpression("[A-Za-z0-9]_[0-9]{4}")
        if regex.matches(n) //Already numeric? Increment
        {
            let ss = n.split(separator: "_")
            if let numeric = Int(ss[1])
            {
                return ss[0] + String(format: "_%4.4d", numeric+1)
            }
        }

        return n + "_0001"
    } //end  + String(format: "%4.2f", displayValue)

    
    //=====(AllPatches)=============================================
    // Just a lookup. could use case i guess
    func getCatByName (n : String) -> String
    {
        var cat = "SY"
        if      percKitPatchDictionary[n]    != nil {cat = "PK"}
        else if percussionPatchDictionary[n] != nil {cat = "PE"}
        else if GMPatchDictionary[n]         != nil {cat = "GM"}
        return cat
    }
    
    //=====(AllPatches)=============================================
    // Just a lookup. could use case i guess
    func getCategoryFolderName (n : String) -> String
    {
        var                  name = "SynthPatches"
        if      (n == "PE") {name = "PercussionPatches"}
        else if (n == "PK") {name = "PercKitPatches"}
        else if (n == "GM") {name = "GMPatches"}
        return name
    }
    
    //=====(AllPatches)=============================================
    //populates patchInfoDict with PatchieInfo objects
    func getAllPatchInfo()
    {
        patchInfoDict.removeAll() //Start empty..
        for (name,ppp) in allBuiltinPatchDictionary
        {
            let badNames = ["empty","default"]  //Filter out any crap...
            if badNames.contains(name) {break}
            //print("ADD PATCH NAME \(name)--------------------")
            var pi     = PatchieInfo()
            pi.name    = name
            pi.builtin = allBuiltinPatchDictionary[name] != nil
            //Compare patch w/ factory ...
            if let tp = allFactoryPatchDictionary[name]
            {
                pi.factorySettingWasChanged = ppp.isEqualTo(s: tp)
            }
            //Get 2 letter category
            pi.category = getCatByName(n: name)
            //print(" GPI name \(name) pi \(pi)")
            //All done, add info to dict
            patchInfoDict[name] = pi
        }
        //print("el dono \(patchInfoDict)")
    } //end getAllPatchInfo
    
    //=====(AllPatches)=============================================
    // 11/13 called from patchEditVC amongst udders...
    func changedAPatch (name:String)
    {
        var pi = patchInfoDict[name]   //Get info
        pi?.factorySettingWasChanged = true
        patchInfoDict[name] = pi       //Save Info

    }
    
    //=====(AllPatches)=============================================
    //Look at GMNamesDict, parse last 2 chars, if
    //  it is C4 then no offset, but add octaves for 5,6,7
    //  and subracta octaves for 3,2,1
    func loadGMOffsets()
    {
        for patch in builtInGMPatches
        {
            let pname = patch.name.lowercased()
            var offset     = 64
            let dindex     = pname.index(pname.endIndex, offsetBy: -2)
            let last2Chars = pname[dindex...]
            let firstChar  = last2Chars.prefix(1)
            let lastChar   = last2Chars.suffix(1)
            
            switch(firstChar)
            {
                case "C" : offset = 64
                case "d" : offset = 66
                case "e" : offset = 68
                case "f" : offset = 69
                case "g" : offset = 71
                case "a" : offset = 72
                case "b" : offset = 75
                default  : offset = 64
            }
            var octave = 0
            switch(lastChar)
            {
                case "1" : octave = -3
                case "2" : octave = -2
                case "3" : octave = -1
                case "4" : octave =  0
                case "5" : octave =  1
                case "6" : octave =  2
                case "7" : octave =  3
                default  : octave = 0
            }
            offset = offset + 12 * octave
            GMOIffsetDictionary[pname] = 64 - offset
        }
    } //end loadGMOffsets
    
    //=====(AllPatches)=============================================
    // 10/18
    func getInstrumentNameFromGMFilename(fname:String) -> String
    {
        let pSubstrs = fname.split(separator: "_")
        if pSubstrs.count == 3
        {
            if let patchNum = Int32(pSubstrs[1]) //get patch# and instrument name 1...n
            {
                let pkey = String(patchNum) //stupid : back to string again!
                if let instrumentName = GMNamesDictionary[pkey]
                {
                    return instrumentName
                }
            }
        }
        return ""
    }
    
    //=====(AllPatches)=============================================
    func getOffsetForGMPatch(name : String) -> Int
    {
        if let i = GMOIffsetDictionary[name] {return i}
        return 0
    }
    
    
    //=====(AllPatches)=============================================
    func getUserPatchesForVoiceType(type:Int) -> Dictionary<String, OogiePatch>
    {
        var result = Dictionary<String, OogiePatch>()
        for (name,p) in yuserPatchDictionary //Copy out any matches to our type
        {
            if p.type == type  { result[name] = p }
        }
        return result
    } //end getUserPatchesForVoiceType

    //=====(AllPatches)=============================================
    func dumpData()
    {
        print("AllPatches Dump: builtin-----------------------------------")
        //print(builtInSynthPatches)
        print("      stored-----------------------------------")
        print(storedPatches)
        print("      synthPatchDictionary:-----------------------------------")
        print(synthPatchDictionary)
        print("      percussionPatchDictionary:-----------------------------------")
        print(percussionPatchDictionary)
        print("      percKitPatchDictionary:-----------------------------------")
        print(percKitPatchDictionary)
        print("      GMPatchDictionary:-----------------------------------")
        print(GMPatchDictionary)
    }
    
    //=====(AllPatches)=============================================
    // just queries the dictionaries...
    func patchExists(name:String) -> Bool
    {
        if allBuiltinPatchDictionary[name] != nil {return true}
        if yuserPatchDictionary[name] != nil {return true}
        return false
    }
    
    //=====(AllPatches)=============================================
    // used when voice type is changed, gets default patch for voicetype
    func getDefaultPatchByType(ptype : Int) -> OogiePatch
    {
        var name = "bubbles"
        switch (Int32(ptype))
        {
            case PERCKIT_VOICE   : name = "kit1"
            case PERCUSSION_VOICE: name = "low_mid_tom"
            case SAMPLE_VOICE    : name = "gm_001_c3" //10/16
            default              : name = "bubbles"
        }
        return getPatchByName(name: name)
    } //end getDefaultPatchByType
    
    //=====(AllPatches)=============================================
    // 10/15 search thru dictionaries for patch.
    //   assumes no dupes across dictionaries!
    func getPatchByName(name:String) -> OogiePatch
    {
        let dicts = [synthPatchDictionary,percKitPatchDictionary,percussionPatchDictionary,GMPatchDictionary,yuserPatchDictionary] //11/13 add yuser!
        for dict in dicts{
            if let op = dict[name] //11/15 NOTE CASE_SENSITIVE!!!
            {
                return op
            }
        }
        //bail? return generic synth patch
        return OogiePatch()
    } //end getPatchB"GMyName

    //=====(AllPatches)=============================================
    func getPercKitPatchByName(name:String) -> OogiePatch
    {
        if let op = percKitPatchDictionary[name.lowercased()]
        {
            return op
        }
        //consolation prize? return empty patch?
        return OogiePatch()
    } //end getPercKitPatchByName

    //=====(AllPatches)=============================================
    func getPercussionPatchByName(name:String) -> OogiePatch
    {
        if let op = percussionPatchDictionary[name.lowercased()]
        {
            return op
        }
        //consolation prize? return empty patch?
        return OogiePatch()
    } //end getPercussionPatchByName
 
    //=====(AllPatches)=============================================
    func getGMPatchByName(name:String) -> OogiePatch
    {
        if let op = GMPatchDictionary[name.lowercased()]
        {
            return op
        }
        //consolation prize? return empty patch?
        return OogiePatch()
    } //end getGMPatchByName

    
    //Regex crap
//    func =~ (input:String, pattern: String) -> Bool{
//        return Regex(pattern).test(input)
//    }
    
} //end class


