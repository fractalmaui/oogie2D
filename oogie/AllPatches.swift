//     _    _ _ ____       _       _
//    / \  | | |  _ \ __ _| |_ ___| |__   ___  ___
//   / _ \ | | | |_) / _` | __/ __| '_ \ / _ \/ __|
//  / ___ \| | |  __/ (_| | || (__| | | |  __/\__ \
// /_/   \_\_|_|_|   \__,_|\__\___|_| |_|\___||___/
//
//
//  AllPatches.swift
//  oogieCam
//
//  Created by Dave Scruton on 6/15/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//  Built-in Patches. Can be augmented with addon patches too.
//
//  good link for GM percussion sounds:
//   https://freewavesamples.com/midi-drums
//
//  9/14 add createADSRImage and support funcs
//  10/12 merge all patches into one Dict
//  10/19 redid process to load / name soundpacks
//  12/17 pull loadPurchasedSoundPacks
//  1/25  add patch name sort in loadPurchasedPatches
//  4/26  cleanup
//  6/23  add 4 new sPatches entries:RampLead, etc, using xtraParams field
//  8/2   updates to handle oogiecammetalshop as productID
//  11/1  add loadUserPatches
import Foundation
import UIKit

@objc class AllPatches : NSObject{
    static let sharedInstance = AllPatches()

    var id = 123
    var patch = OogiePatch()
    //NOTE SPS would be better at app level but needs to be here because its a struct
    //  and apparently doesnt link into objective c ??
    var SPS = SPStruct()
    var patchesDict       = Dictionary<String, OogiePatch>() //10/12
    var allPatchCount     = 0 //patchesDict.count?
    var GMNamesDictionary = Dictionary<String, String>()
    var soundPacks        = Dictionary<String, SPStruct>()
    var allSoundPackNames = [String]() // 10/11 keep names in order!
    var purchasedSoundPackNames = [String]() // 10/21 
    let SYNTH_PERC_SP_NAME = "Synth/Perc" //10/19
    let CRITTERS_SP_NAME  = "Critters" //10/19
    let WEIRDNESS_SP_NAME = "Weirdness" //10/19
    let USER_SP_NAME      = "UserSamples" //10/19
    var bufLookups        = Dictionary<NSNumber, String>()
    var patLookups        = Dictionary<String  , NSNumber>()

    //9/14 for ADSR graphics support
    var sfx = soundFX.sharedInstance //10/19 for GMidi instrument lookup

    //----(AllPatches)==============================================
    override init()
    {
        super.init()
        print("loadedFactoryPatches , \(soundPacks.count) soundpacks names \(allSoundPackNames)")
        //10/18 we need gm names here!
        GMNamesDictionary = (sfx() as! soundFX).loadGeneralMidiNames() as! [String : String]
    }

    //----(AllPatches)==============================================
    // 10/22 moved from init
    @objc func loadAllSoundPacksAndPatches()
    {
        loadBuiltinPatches()
        loadFactorySoundPacks()
        loadUserPatches() //11/1 
    }

    //----(AllPatches)==============================================
    //how come i need this? oogie2d gets around this somehow!?
    @objc func createSubfolders()
    {
        DataManager.createSubfolders()
    }
    
    
    //OBJECTIVE C BINDINGS to get patch data out. WHAt a waste!
    //Wow how stoopid. cant see struct members from C!!!!
    @objc func getAttack()            -> Double { return patch.attack }
    @objc func getDecay()             -> Double { return patch.decay }
    @objc func getSustain()           -> Double { return patch.sustain }
    @objc func getSLevel()            -> Double { return patch.sLevel }
    @objc func getRelease()           -> Double { return patch.release }
    @objc func getDuty()              -> Double { return patch.duty }
    @objc func getWave()              -> Int { return patch.wave }
    @objc func getType()              -> Int { return patch.type }
    @objc func getName()              -> String { return patch.name }
    @objc func getSampOffset()        -> Int { return patch.sampleOffset }
    @objc func getPercLoox(i:Int)     -> String { return patch.percLoox[i] }
    @objc func getPercLooxPans(i:Int) -> Int { return patch.percLooxPans[i] }
    @objc func getAllPatchcount()     -> Int { return allPatchCount }
    @objc func getXtraParams()        -> String { return patch.xtraParams } //11/24
    @objc func getPLevel()            -> Int { return patch.pLevel } //2/12/21
    @objc func getPKeyOffset()        -> Int { return patch.pKeyOffset } //2/12/21
    @objc func getPKeyDetune()        -> Int { return patch.pKeyDetune } //2/12/21

    @objc func setPSPN(A:[String])
    {
        purchasedSoundPackNames = A
    }
    
    //----(AllPatches)==============================================
    // 10/28 clear back SP names for adding on new stuff... keep first 2 only
    @objc func clearPurchasedAndUserSoundPackNames()
    {
        while allSoundPackNames.count > 2
        {
            allSoundPackNames.removeLast()
        }
    }
    
    //----(AllPatches)==============================================
    // 10/18 for buffer complete report
    @objc func getBufferReport() -> Dictionary<NSNumber,String>
    {
        return bufLookups
    } //end getBufferReport

    
    //----(AllPatches)==============================================
    //  10/16
    @objc func clearBufferPatchLinks()
    {
        bufLookups.removeAll()
        patLookups.removeAll()
    }

    //----(AllPatches)==============================================
    // 10/16 internal bookkeeping, linking buffers in synth to
    //       physical patches
    @objc func linkBufferToPatch(nn:NSNumber , ss:String)
    {        
        let ssl = ss.lowercased()
        bufLookups[nn] = ssl
        patLookups[ss] = nn
        //print("...link buffer \(nn.intValue) 2patch \(ss)");
    }

    //----(AllPatches)==============================================
    // 1/29/21 used in rename, gets rid of old name from dict
    @objc func unlinkOldBufferByName(ss:String)
    {
        patLookups[ss] = nil;
    }
    
    //----(AllPatches)==============================================
    //9/29 look thru patLookups, find all GM perc names..
    func getGMPercussionNames() -> [String]
    {
        var names : [String] = []
        for (key,_) in patLookups
        {  //god this is sloppy! why is string access so cumbersome??
            if key.count > 4
            {
                let a0 = key.index(key.startIndex, offsetBy: 0)
                let a4 = key.index(key.startIndex, offsetBy: 4)
                if key[a0] == "M" && key[a4] == "_"
                {
                    names.append(key)
                }
            }
        }
        return names.sorted()
    } //end getGMPercussionNames

    //----(AllPatches)==============================================
    // 10/16
    @objc func getSampleNumberByName(ss:String) -> NSNumber
    {
        if let nn = patLookups[ss] {return nn}
        return 0;
    }
    
    //9/14 graphics helper......
    //----(AllPatches)==============================================
    // called from setupSynthOrSample
    @objc func getADSRDisplay (bptr : Int , adsrImage : UIImageView) -> UIImage?
    {
        print("OBSOLETE getADSRDisplay")
        return nil
//        let asize = 256
//        let wbptr = (sfx() as! soundFX).getWorkBuffer()
//        // NOW copy envelope from its world to work area...
//        //11/25 OBSOLETE (sfx() as! soundFX).copyEnvelope(Int32(bptr),Int32(wbptr))
//
//        //11/25 OBSOLETE guard let NNvalz = (sfx() as! soundFX).getEnvelopeForDisplay( wbptr  , Int32(asize))
//        //11/25 OBSOLETE             else {return nil}
//        if (NNvalz.count == 0) {return nil} //9/14 bail on empty too
//        //OUCH. comes back as array of nsnumbers
//        var valz : [Float] = []
//        for val in NNvalz  //should be an array of nsnumber floats
//        {
//            if let nn = val as? NSNumber { valz.append(nn.floatValue) }
//        }
//        let result = createADSRImage(frame:adsrImage.frame,vals: valz)
//        return result
    } //end getADSRDisplay

    
    //9/14 Work functions...
    //=====PatchEditorVC===========================================
    public func createADSRImage(frame:CGRect , vals : [Float]) -> UIImage {
        let colorz : [UIColor] = [.green,.red,.blue,.red]
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        //Fill bkgd
        context.setFillColor(UIColor.clear.cgColor);
        context.fill(frame);
        
        let step   = frame.size.width / CGFloat(vals.count)
        let yscale = frame.size.height
        //draw chart with tiny rects...
        
        var segment = 0
        var x = CGFloat(0.0)
        var oldval : Float = 0.0
        for val in vals
        {
            var nextval = val
            if val < 0 //next phase of envelope? switch color
            {
                nextval = oldval
                segment = Int(abs(val)) //We send segment back in the adsr output!
                segment = min(3,max(0,segment))
            }
            let yval = CGFloat(nextval)*yscale
            let r = CGRect(x: x, y: yscale-yval , width: step, height: yval)
            context.drawBoxGradient(in: r, startingWith: colorz[segment].cgColor, finishingWith: UIColor.white.cgColor) //9/16 change to white
            //context.fill(r);   //for solid fill
            x = x + step
            oldval = nextval
        }
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createADSRImage
    
    //----(AllPatches)==============================================
    // 11/12 purchased patches live in a subfolder under soundpack name,
    //        and the corresponding samples live in a different subfolder
    //12/21 add path name AND sp name
    @objc func loadPurchasedPatches(pid:String , pathName:String , displayName:String)
    {
        var wP = Dictionary<String, OogiePatch>()
        wP = DataManager.loadPurchasedPatchesToDict(OogiePatch.self,subFolder: pathName)
        var purchasedPack = SPStruct() //work soundpack
        let keys = Array(wP.keys).sorted(by: <) //1/25/21 add alpha sort
        // 1/25/21 we need to sort alphabetically!!! (or numerically?)
        for i in 0..<keys.count
        {
            let pname = keys[i]
            if let patch = wP[pname]
            {
                patchesDict[pname] = patch
                purchasedPack.addPatch(name: pname, patch: patch)
            }
        } //12/17 install patches
        allPatchCount = max(patchesDict.count,allPatchCount);
        soundPacks[displayName] = purchasedPack //3/5 change to use 2nd arg
        allSoundPackNames.append(displayName) //3/5 change to use 2nd arg
    } //end loadPurchasedPatches

    //----(AllPatches)==============================================
    // 11/1/21 load user-generated patches
    @objc func loadUserPatches()
    {
        var wP = Dictionary<String, OogiePatch>()
        wP = DataManager.loadUserPatchesToDict(OogiePatch.self) //get any user patches...
        let keys = Array(wP.keys).sorted(by: <)
        // note we just load PATCHES, no soundpack intended...
        for i in 0..<keys.count
        {
            let pname = keys[i]
            if let patch = wP[pname]
            {
                let pkey = "U_" + pname   //add special prefix for key
                patchesDict[pkey] = patch
            }
        }
    } //end loadUserPatches



    //----(AllPatches)==============================================
    // 10/12 new :load canned patches to one big dict
    //  accessed
    @objc func loadBuiltinPatches()
    {
        //print("loadAllPatches");
        patchesDict.removeAll() //10/12 our target
        var wP      = Dictionary<String, OogiePatch>()
        wP = DataManager.loadBuiltinSynthPatchesToDict(OogiePatch.self,
                                                        fromFactory: true)
        for (pname,patch) in wP {patchesDict[pname] = patch} //install patches
        wP = DataManager.loadBuiltinPercussionPatchesToDict(OogiePatch.self,
                                                        fromFactory: true)
        for (pname,patch) in wP {patchesDict[pname] = patch} //install patches
        wP = DataManager.loadBuiltinPercKitPatchesToDict(OogiePatch.self,
                                                        fromFactory: true)
        for (pname,patch) in wP {patchesDict[pname] = patch} //install patches
        wP = DataManager.loadBuiltinCritterPatchesToDict(OogiePatch.self,
                                                        fromFactory: true)
        for (pname,patch) in wP {patchesDict[pname] = patch} //install patches
        wP = DataManager.loadBuiltinWeirdnessPatchesToDict(OogiePatch.self,
                                                        fromFactory: true)
        for (pname,patch) in wP {patchesDict[pname] = patch} //install patches


        allPatchCount = patchesDict.count;
        print("...got \(allPatchCount) patches")
    } //end loadBuiltinPatches
    
    
    var  sPatches =  [ "SineWave","Sawtooth","SquareWave","RampWave",
                       "SineLead","SawLead","SquareLead","RampLead", //6/13/21
                       "Mellow","Bubbles","Casio","SoftSynth",
                       "SynthPiano1","SynthPiano2","SynthPiano3","SwooshNoise"]
    var pPatches = [ "Kick","Snare","Low Tom","Hi Tom",
                     "Open HiHat","Closed HiHat","Ride 1","Ride 2",
                     "Lo Conga","Claves","Lo Mid Tom","Tambourine",
                     "DrumKit1","DrumKit2","DrumKit3","DrumKit4"]
    var cPatches = [ "squirrely","lickety","twerty","crow","peacock",
                     "doggie","cougar","barky","toadie","crickety",
                     "froggie","alleycat","kitty","wolfie","chirpy",
                     "hootie","moose","donkey","goose","elephant",
                     "monkey","rooster","chicken","terrier","cow",
                     "horse","cicada","flipper","piggie","hawk",
                     "seal","spooky"]
    var wPatches = [ "bananapeel","bleep","blip","bongocan","broken",
                      "chandelier","chemicals","clicks","cocktail","drumtrickle",
                      "explosion","fairydust","flipper","gerbil","glassstrings",
                      "glasszap","heavypiano","nylon","radiation","rubberbands",
                      "saucerliftoff","stellar","swoopy","theshining","tincan",
                      "trickle","twinkle","ufochime","vibracan","waterrocks",
                      "zap","zwip"]
    var sgtPatches = [
        "001_Grand Piano","010_Glockenspiel","012_Vibraphone","019_Rock Organ",
        "025_Acc Guitar 1","029_Elect Guitar Mute","030_Overdrive Guitar","031_Distort Guitar",
        "036_ Fretless Bass","041_Violin","042_Viola","043_Cello",
        "044_Contrabass","045_Tremolo Strings","046_Pizzicato Strings","047_Orchestral Harp",
        "048_Timpani","049_String Ens 1","057_Trumpet","058_Trombone",
        "059_Tuba","061_French Horn","068_Baritone Sax","069_Oboe",
        "070_English Horn","071_Bassoon","072_Clarinet","073_Piccolo",
        "074_Flute","075_Recorder","105_Sitar","120_Reverse Cymbal"
    ]
    var oPatches = [
        "001_Grand Piano","002_Bright Piano","003_Electric Grand","004_HonkyTonk Piano",
        "005_Elect Piano1","006_Elect Piano2","007_Harpsichord","008_Clavinet",
        "009_Celesta","010_Glockenspiel","011_Music Box","012_Vibraphone",
        "013_Marimba","014_Xylophone","015_Tubular Bells","016_Dulcimer",
        "017_Drawbar Organ","018_Percussive Organ","019_Rock Organ","020_Church Organ",
        "021_Reed Organ","022_Accordion","023_Harmonica","024_Bandoneon",
        "025_Acc Guitar 1","026_Acc Guitar 2","027_Elect Guitar 1","028_Elect Guitar 2",
        "029_Elect Guitar Mute","030_Overdrive Guitar","031_Distort Guitar","032_Guitar Harmonics",
        "033_Acc Bass","034_Elect Bass 1","035_Elect Bass 2","036_ Fretless Bass",
        "037_Slap Bass 1","038_Slap Bass 2","039_Synth Bass 1","040_Synth Bass 2",
        "041_Violin","042_Viola","043_Cello","044_Contrabass",
        "045_Tremolo Strings","046_Pizzicato Strings","047_Orchestral Harp","048_Timpani",
        "049_String Ens 1","050_String Ens 2","051_Synth String 1","052_Synth String 2",
        "053_Choir Aahs","054_Choir Oohs","055_Synth Voice","056_Orchestra Hit",
        "057_Trumpet","058_Trombone","059_Tuba","060_Muted Trumpet",
        "061_French Horn","062_Brass Section","063_Synth Brass 1","064_Synth Brass 2",
        "065_Soprano Sax","066_Alto Sax","067_Tenor Sax","068_Baritone Sax",
        "069_Oboe","070_English Horn","071_Bassoon","072_Clarinet",
        "073_Piccolo","074_Flute","075_Recorder","076_Pan Flute",
        "077_Blown Bottle","078_Shakuhachi","079_Whistle","080_Ocarina",
        "081_Square Lead","082_Saw Lead","083_Calliope Lead","084_Chiff Lead",
        "085_Charang Lead","086_Voice Lead","087_Fifths Lead","088_Bass Lead",
        "089_New Age Pad","090_Warm Pad","091_PolySynth Pad","092_Choir Pad",
        "093_Bowed Pad","094_Metallic Pad","095_Halo Pad","096_Sweep Pad",
        "097_FX Rain","098_FX Soundtrack","099_FX Crystal","100_FX Atmosphere",
        "101_FX Brightness","102_FX Goblins","103_FX Echoes","104_FX SciFi",
        "105_Sitar","106_Banjo","107_Samisen","108_Koto",
        "109_Kalimba","110_Bagpipe","111_Fiddle","112_Shanai",
        "113_Tinkle Bell","114_Agogo","115_Steel Drums","116_Woodblock",
        "117_Taiko Drum","118_Melodic Tom","119_Synth Drum","120_Reverse Cymbal",
        "121_Fret Noise","122_Breath Noise","123_Seashore","124_Bird Tweet",
        "125_Telephone Ring","126_Helicopter","127_Applause","128_Gunshot"
    ]


//----(AllPatches)==============================================
// Load builtin stuff into SPS struct(s)
    @objc func loadFactorySoundPacks()
    {
        print(" 10/21 load factory...") // \(pname)" )
        soundPacks.removeAll()
        //first load 16 synth / perc factory soundpack...
        var factorySoundPack1 = SPStruct()
        for pname in sPatches
        {
            unpackPatch(name: pname)
            factorySoundPack1.addPatch(name: pname, patch: patch)
        }
        for pname in pPatches //now load 16 perc / perkits
        {
            unpackPatch(name: pname)
            factorySoundPack1.addPatch(name: pname, patch: patch)
        }
        soundPacks[SYNTH_PERC_SP_NAME] = factorySoundPack1 //10/19
        //print("asp add \(SYNTH_PERC_SP_NAME)")
        allSoundPackNames.append(SYNTH_PERC_SP_NAME)
        
        //Load critters, also builtin, all samples
        var factorySoundPack2 = SPStruct()
        for pname in cPatches
        {
            unpackPatch(name: pname)
            factorySoundPack2.addPatch(name: pname, patch: patch)
        }
        soundPacks[CRITTERS_SP_NAME] = factorySoundPack2
        allSoundPackNames.append(CRITTERS_SP_NAME)
        
        //8/30/21 Load weirdness, also builtin, all samples
        var factorySoundPack3 = SPStruct()
        for pname in wPatches
        {
            unpackPatch(name: pname)
            factorySoundPack3.addPatch(name: pname, patch: patch)
        }
        soundPacks[WEIRDNESS_SP_NAME] = factorySoundPack3
        allSoundPackNames.append(WEIRDNESS_SP_NAME)
        
    } //end loadFactorySoundPacks

    //----(AllPatches)==============================================
    // collect user samples from a folder, produce patches for these
    // NOTE: patches should be added in the order you want them to appear in the chooser
    @objc func loadUserSoundPack()
    {
        if let durl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            let surl = durl.appendingPathComponent("samples", isDirectory: true)
            do{
                var userSoundPack = SPStruct()
                var files = try FileManager.default.contentsOfDirectory(atPath: surl.path)
                files = files.sorted() //1/31/21 sort filenames!
                print("loadUserSoundPack: \(surl)")
                for fileName in files {
                    if !fileName.contains("#") //1/31/21
                    {
                        var upatch = OogiePatch()
                        upatch.name = fileName //store sample name
                        print("  ...load userSoundPatch patch \(fileName)")
                        userSoundPack.addPatch(name: fileName, patch: upatch)
                        patchesDict[fileName] = upatch  //10/24 need to save in dict?
                    }
                }  //end for filename
                //11/1 OK now lets add custom user patches also...
                let keys = patchesDict.keys
                for key in keys
                {
                    if key.count > 4   //look for keys starting with U_....
                    {
                        let a0 = key.index(key.startIndex, offsetBy: 0)
                        let a1 = key.index(key.startIndex, offsetBy: 1)
                        if key[a0] == "U" && key[a1] == "_"
                        {
                            if let p = patchesDict[key]
                            {
                                userSoundPack.addPatch(name: key, patch: p)
                            }
                        }
                    }
                } //end for key
                soundPacks[USER_SP_NAME] = userSoundPack  //1/31/21 was in wrong place!
            } //end do
            catch{
               print("error loading user soundpack")
            }
        }
        if !allSoundPackNames.contains(USER_SP_NAME) //10/28 check for dupes
        {
            allSoundPackNames.append(USER_SP_NAME)
            print("asp add \(USER_SP_NAME)")
        }
    } //end loadUserSoundPack
    
    //----(AllPatches)==============================================
    // 11/11 for 3D dice control, just get rand patch name
    @objc func getRandomPatchName() -> String
    {//asdf
        let keys = Array(patchesDict.keys)
        let rint = Int.random(in: 0..<keys.count)
        return keys[rint]
    }
    
    //----(AllPatches)==============================================
    // 10/29 for refunds (not yet implemented)
    @objc func deleteSoundPack(spname : String , displayName : String)
    {
        print ("delete sp top");
        let spnlc = spname.lowercased()
        print ("delete sp 1");
        if soundPacks[spnlc] != nil   //2/5/21 syntax fix
        {
            soundPacks.removeValue(forKey: spnlc) //clobber it!
            print ("delete sp 2");
            if let found = allSoundPackNames.firstIndex(of: displayName)
            {
                print ("delete sp 3");
                allSoundPackNames.remove(at: found) //blow away SPname too
            }
        }
        print ("delete sp done");
    } //end deleteSoundPack
    
    //----(AllPatches)==============================================
    @objc func getNumberOfSoundPacks() -> Int
    {
        return allSoundPackNames.count //10/19 is this better?
    }

    //----(AllPatches)==============================================
    @objc func getSoundPackSize() -> Int
    {
        return SPS.patchNames.count
    }
    
    //----(AllPatches)==============================================
    // pull soundpack to SPS struct..
    @objc func getSoundPackByName(name : String)
    {
        if let testSP = soundPacks[name] { SPS = testSP }
    }
    
    //----(AllPatches)==============================================
    @objc func getSoundPackNameByIndex (index : Int) -> String
    {
        if index < 0 || index >= allSoundPackNames.count {return ""}
        return allSoundPackNames[index]; //10/11 redo
    }
    
    //----(AllPatches)==============================================
    @objc func getSoundPackPatchNameByIndex (index : Int) -> String
    {
        if index < 0 || index >= SPS.patchNames.count {return ""}
        return SPS.patchNames[index]
    }
    
    //----(AllPatches)==============================================
    // populates patch var with desired patch in Soundpack
    @objc func getSoundPackPatch(pname : String)
    {
        var i = 0
        for name in SPS.patchNames
        {
            if name == pname //match
            {
                patch = SPS.patches[i] //get patch loaded and bail
                break
            }
            i+=1
        }
    } //end getSoundPackPatch
    
    //----(AllPatches)==============================================
    // 10/12 for unpacking FACTORY patches! clumsy exhaustive search!
    @objc func unpackPatch(name : String)
    {
        //4/26 cleanup
        if let p = patchesDict[name] { patch = p }
    } //end unpackPatch
    

    
    //----(AllPatches)==============================================
    @objc func writePatch(name:String)
    {
        patch.saveItem(filename: name, cat: "US")
    }
    
    //----(AllPatches)==============================================
    //DIAGNOSTIC: Write out fresh patches for all GMpercussion samples...
    //  subfolder
    func writeGMPercussionPatches()
    {
        
        let purl = Bundle.main.resourceURL!.appendingPathComponent("GMPercussion").path
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: purl)
            print("contents of percussion folder...")
            for file in files
            {
                let sf = file.split(separator: ".")
                let pname = String(sf[0])
                var oop     = OogiePatch()
                oop.name    = pname
                oop.attack  = 0
                oop.decay   = 0
                oop.sustain = 0
                oop.release = 0
                oop.sLevel  = 0
                oop.duty    = 0
                oop.wave    = 0
                oop.type    = Int(PERCUSSION_VOICE)
                oop.saveItem(filename:pname, cat:"GM") //Write it out! 11/14 new arg
                print("write GMpercussion \(pname)")
            }
        }catch{
            fatalError("error: no percussion!")
        }
    } //end writeGMPercussionPatches

    
    //----(AllPatches)==============================================
    // 8/30/21 generic patch saver, takes input list of sample names
    @objc func writeColorPackPatchesFromNames (files: [String])
    {
        for file in files
        {
            let sf = file.split(separator: ".")
            let pname = String(sf[0])
            var oop     = OogiePatch()
            oop.name    = pname
            oop.attack  = 0
            oop.decay   = 0
            oop.sustain = 0
            oop.release = 0
            oop.sLevel  = 0
            oop.duty    = 0
            oop.wave    = 0
            oop.type    = Int(SAMPLE_VOICE)
            oop.saveItem(filename:pname, cat:"US") //Write it out! 11/14 new arg
            print(" ...write colorpack patch \(pname)")
        }

    }
    
    //----(AllPatches)==============================================
    // This writes to the /Documents/patches folder...
    func writeGMSamplePatches()
    {
        
        let purl = Bundle.main.resourceURL!.appendingPathComponent("GeneralMidi").path
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: purl)
            print("contents of samples folder...")
            for file in files
            {
                let sf = file.split(separator: ".")
                let pname = String(sf[0])
                var oop     = OogiePatch()
                oop.name    = pname
                oop.attack  = 0
                oop.decay   = 0
                oop.sustain = 0
                oop.release = 0
                oop.sLevel  = 0
                oop.duty    = 0
                oop.wave    = 0
                oop.type    = Int(SAMPLE_VOICE)
                oop.saveItem(filename:pname, cat:"US") //Write it out! 11/14 new arg
                print(" ...write GMSample \(pname)")
            }
        }catch{
            fatalError("error: no percussion!")
        }
    } //end writeGMSamplePatches

    //----(AllPatches)==============================================
    @objc func testKrashWithDMAndFlurry()
    {
       // DataManager.testKrashWithAnalytics(tstr: "test Krash From Main");
    }
    
}

// 9/14 to support ADSR graph
extension CGContext {
  func drawBoxGradient(
    in rect: CGRect,
    startingWith startColor: CGColor,
    finishingWith endColor: CGColor
  ) {
    // 1
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 2
    let locations = [0.0, 1.0] as [CGFloat]

    // 3
    let colors = [startColor, endColor] as CFArray

    // 4
    guard let gradient = CGGradient(
      colorsSpace: colorSpace,
      colors: colors,
      locations: locations
    ) else {
      return
    }
      let startPoint = CGPoint(x: rect.midX, y: rect.minY)
      let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
          
      // 6
      saveGState()

      // 7
      addRect(rect)
      clip()
      drawLinearGradient(
        gradient,
        start: startPoint,
        end: endPoint,
        options: CGGradientDrawingOptions()
      )

      restoreGState()  }
    
}

