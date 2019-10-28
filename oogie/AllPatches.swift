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
import Foundation

class AllPatches {


//This is supposed to be a singleton...
static let sharedInstance = AllPatches()

var builtInSynthPatches : [OogiePatch] = []
var builtInPercussionPatches : [OogiePatch] = []
var builtInGMPatches : [OogiePatch] = []
var storedPatches  : [OogiePatch] = []
    
var builtInPercKitPatches : [OogiePatch] = []
var patchDictionary           = Dictionary<String, OogiePatch>()
var percKitPatchDictionary    = Dictionary<String, OogiePatch>()
var percussionPatchDictionary = Dictionary<String, OogiePatch>()
var GMPatchDictionary         = Dictionary<String, OogiePatch>()
var GMNamesDictionary         = Dictionary<String, String>()
// 10/18 GMfilenames -> GM instrument names
var GMNamesToInstrumentsDictionary = Dictionary<String, String>()
var sfx = soundFX.sharedInstance //10/19 for GMidi instrument lookup

//=====(AllPatches)=============================================
//This makes sure your singletons are truly unique and prevents
//  outside objects from creating their own instances of your class t
private init()
{
    //print(" AllPatches isborn")
    //Create work areas in documents folder
    DataManager.createSubfolders()
    //Load some arrays with contents of folders...
    builtInSynthPatches      = DataManager.loadLocalSynthPatches(OogiePatch.self)
    builtInPercussionPatches = DataManager.loadLocalPercussionPatches(OogiePatch.self)
    builtInPercKitPatches    = DataManager.loadLocalPercKitPatches(OogiePatch.self)
    builtInGMPatches         = DataManager.loadLocalGMPatches(OogiePatch.self)
    storedPatches            = DataManager.loadAllPatches(OogiePatch.self)
    //10/18 we need gm names here!
    GMNamesDictionary = (sfx() as! soundFX).loadGeneralMidiNames() as! [String : String]
    //Add all these to patch dictionaries...
    for patch in builtInSynthPatches
    {
        //print("patch : \(patch)")
        patchDictionary[patch.name.lowercased()] = patch
    }
    for patch in storedPatches            {patchDictionary[patch.name.lowercased()] = patch}
    for patch in builtInPercussionPatches {percussionPatchDictionary[patch.name.lowercased()] = patch}
    for patch in builtInPercKitPatches    {percKitPatchDictionary[patch.name.lowercased()] = patch}
    for patch in builtInGMPatches
    {
        let pname = patch.name.lowercased()
        GMPatchDictionary[pname] = patch
        //10/18 add lookup from filename to instrument name
        let iname = getInstrumentNameFromGMFilename(fname: pname)
        GMNamesToInstrumentsDictionary[pname] = iname
    }
    print("...allpatches loaded")
}
    
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
    func dumpData()
    {
        print("AllPatches Dump: builtin-----------------------------------")
        print(builtInSynthPatches)
        print("      stored-----------------------------------")
        print(storedPatches)
        print("      patchDictionary:-----------------------------------")
        print(patchDictionary)
        print("      percussionPatchDictionary:-----------------------------------")
        print(percussionPatchDictionary)
        print("      percKitPatchDictionary:-----------------------------------")
        print(percKitPatchDictionary)
        print("      GMPatchDictionary:-----------------------------------")
        print(GMPatchDictionary)
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
        let dicts = [patchDictionary,percKitPatchDictionary,percussionPatchDictionary,GMPatchDictionary] //10/16
        for dict in dicts{
            if let op = dict[name.lowercased()]
            {
                return op
            }
        }
        //bail? return generic synth patch
        return OogiePatch()
    } //end getPatchByName

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

} //end class


