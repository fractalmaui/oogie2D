//    ___              _    __     __    _
//   / _ \  ___   __ _(_) __\ \   / /__ (_) ___ ___
//  | | | |/ _ \ / _` | |/ _ \ \ / / _ \| |/ __/ _ \
//  | |_| | (_) | (_| | |  __/\ V / (_) | | (_|  __/
//   \___/ \___/ \__, |_|\___| \_/ \___/|_|\___\___|
//               |___/
//
//  oogieVoice.swift
//  oogie2D
//
//  Created by Dave Scruton on 7/22/19.
//
//  8/13 added OogiePatch for patch-related properties
//  8/22 add saveVoice
//  9/10 add voiceParamsDictionary et al
//  9/24 add getPatchNameArray to support different types of patches
//  9/26 add loadDefaultPatchForVoiceType, sfx reference
//  10/4  add panFixed, etc in setInputColor
//  10/9  add name field
//  11/14 new arg to patch:saveItem
//  11/18 move playColors in ... what about masterPitch and quantTime?
//  11/25 add getChanValueByName, RRR,GGG,BBB channel standard names
//  1/27  add getParam
//  1/29  add getParmLimsForPipe, remove Patch as pipe input
//  2/5   fix bug in getParamCount!!
//  2/28  redo top/bottom midi
//  4/18  add rotTrigger support
//  4/19  add angle arg to playColors, pull pitchFloat
//  4/22  add getParam func
//  4/26  add int param type for midi params
//  4/27  redo top/bot midi and channel
//  5/3   move in getShapeColor from mainVC
//  5/9   add detune as editable param, change detune rules in playColors
//  5/14  new top/bottom midi defaults
//  8/11/21 MODIFY OVStruct, add performance controls portamento, etc...
import Foundation

let SYNTH_TYPE = 1001
let SAMPLE_TYPE = 1002
let PERC_TYPE = 1003
let COMBO_TYPE = 1004

let  SYNTHA_DEFAULT    = 4.0
let  SYNTHD_DEFAULT    = 2.0
let  SYNTHS_DEFAULT    = 20.0
let  SYNTHSL_DEFAULT   = 40.0
let  SYNTHR_DEFAULT    = 20.0
let  SYNTHDUTY_DEFAULT = 50.0

let MAX_CBOX_FRAMES = 20 //11/18 for playColors support 

//Parameter area... this is how the user gets at 3d objects from the UI
//Parmas: Name,Type,Min,Max,Default,DisplayMult,DisplayOffset?? (string params need a list of items)
// NOTE: .pi has to have a numeric multiplicator / divisor to compile in this statement!
let LatParams   : [Any] = ["Latitude" ,      "double", -.pi/2.0   , .pi/2.0   , 0.0, 180.0 / .pi, 0.0 ]
let LonParams   : [Any] = ["Longitude",      "double", -1.0 * .pi , 1.0 * .pi , 0.0, 180.0 / .pi,0.0 ]
// 10/15 NOTE: order here MUST match macro value order in synth!
let TypeParams  : [Any] = ["Type",           "string" , "Synth", "Percussion", "PercKit", "Sample", "Harmony"]
let PatchParams : [Any] = ["Patch",          "string","mt"]
// 5/14 add pitch shift
let PitchShiftParams : [Any] = ["ChromaticKey","string" , "C", "C#", "D", "D#", "E", "F",
                                            "F#", "G", "G#", "A", "A#", "B"]
let ScaleParams : [Any] = ["Scale",          "string" ,"major" ,"minor" ,"blues" ,"chromatic",
                           "lydian" ,"phrygin" ,"pixolydian" ,"locrian" ,"egyptian",
                           "hungarian" ,"algerian","japanese" ]
let LevelParams    : [Any]   = ["Level" ,    "double", 0.0 , 1.0 , 0.5 , 255.0, 0.0 ]
//5/2 add thresh
let ThreshParams : [Any]     = ["Threshold", "double" ,1.0, 255.0 , 5.0  , 1.0,  0.0 ]
//  10/4 add nvp chan/fixed / midi params
let NChanParams : [Any]      = ["NChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let VChanParams : [Any]      = ["VChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let PChanParams : [Any]      = ["PChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let NFixedParams : [Any]     = ["NFixed",    "double" ,  16.0, 112.0 , 64.0  , 1.0,  0.0 ] //4/27 redo next 3
let VFixedParams : [Any]     = ["VFixed",    "double" ,  0.0 , 255.0 , 128.0 , 1.0,  0.0 ]
let PFixedParams : [Any]     = ["PFixed",    "double" ,  0.0 , 255.0 , 128.0 , 1.0,  0.0 ]
let RotTriggerParams : [Any] = ["RotTrigger","double" ,  0.0 , 256.0 , 0.0 , 1.0,  0.0 ]
let DetuneParams : [Any]     = ["Detune",     "string" , "Off", "On"]   //5/9
// 2/28 are these ranges wrong now???
let BottomMidiParams : [Any] = ["BottomMidi","int" ,  16.0 , 112.0 , 52.0 , 1.0,  0.0 ] //4/27 redo next 3
let TopMidiParams : [Any]    = ["TopMidi",   "int" ,  16.0 , 112.0 , 72.0 , 1.0,  0.0 ]
let MidiChannelParams : [Any] = ["MidiChannel","int" ,  1.0 ,16.0 , 1.0 , 1.0,  0.0 ]
let VNameParams    : [Any]   = ["Name",      "text", "mt"]
let VCommParams    : [Any]   = ["Comment",   "text", "mt"]
// All param names, must match first item above for each param!
let voiceParamNames : [String]    = ["Latitude", "Longitude","Type","Patch","ChromaticKey",
                             "Scale","Level","Threshold",
                             "NChan","VChan","PChan",
                             "NFixed","VFixed","PFixed","RotTrigger","Detune",   // 5/9
                             "BottomMidi","TopMidi","MidiChannel","Name","Comment"]
let voiceParamNamesOKForPipe : [String]    = ["Latitude", "Longitude","ChromaticKey",
                                            "Scale","Level","Threshold","NChan","VChan","PChan",
                                            "NFixed","VFixed","PFixed","RotTrigger","Detune",   // 5/9
                                            "BottomMidi","TopMidi","MidiChannel"]

var voiceParamsDictionary = Dictionary<String, [Any]>()
// 9/23 canned perc kit defaults
let percDefaults : [String] = ["Bass_Drum_1","Acoustic_Snare","Low_Tom","Low_Mid_Tom",
                              "High_Tom","Open_Hi_Hat","Closed_Hi_Hat","Ride_Cymbal_1"]

var sfx = soundFX.sharedInstance

let MAX_LOOX = 8


    //4/19/20 debug analysis vars
    typealias debugTuple = (date: Date, note: Int)
    var dhptr = 0    //history recorder ptr
    let dhmax = 64   //history recorder size
    // init fixed size array...
    var debugHistory = [debugTuple?](repeating: nil, count: dhmax)


    class Person: NSObject, NSCopying {
    var firstName: String
    var lastName: String
    var age: Int

    init(firstName: String, lastName: String, age: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
    }

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = Person(firstName: firstName, lastName: lastName, age: age)
        return copy
    }
}

class OogieVoice: NSObject, NSCopying {

    var OOP  = OogiePatch() //this is a struct
    var OVS  = OVStruct()   //  another struct
    var allP = AllPatches.sharedInstance
    var uid  = "nouid"

    var oldNote = 0;
    var uniqueCount = 0;

    //Working vars: Synth channels
    var nchan = 0
    var pchan = 0
    var vchan = 0
    var schan = 0

    //Working vars: Synth channels: last values
    var lnchan = 0
    var lvchan = 0
    var lpchan = 0
    var lschan = 0

    var muted = false //10/17
    var midiNote = 0
    // 8/11/21 last note...type are for delay
    var lastnoteplayed = 0
    var lastgain = 0
    var lastbuf = 0
    var lasttype: Int32 = 0
    var hiLiteFrame = 0
    var bufferPointer = 0 //Points to sample buffer
    var bufferPointerSet = [Int]() //Array of sample buffers for percussion kit
    var triggerKey    = -1 //For percussion, GMidi note
    var beat = 0   //4/18 for rotTrigger usage
    // Work vars for color conversion
    var RRR = 0
    var GGG = 0
    var BBB = 0
    var HHH = 0
    var SSS = 0
    var LLL = 0
    var CCC = 0
    var MMM = 0
    var KKK = 0
    var YYY = 0
    
    var masterPitch = 0 //DHS 4/19 set from app delegate
    let quantTime = 0   //DHS 11/18
    
    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()
    
    var inPipes  = Set<String>()    //1/22 use insert and remove to manage...
    var outPipes = Set<String>()   //1/22 use insert and remove to manage...

    //-----------(oogieVoice)=============================================
    override init() {
        super.init()
        OOP.type      = Int(SYNTH_VOICE)   //7/1/21 was SYNTH_TYPE
        OOP.attack    = 10
        OOP.decay     = 10
        OOP.sustain   = 50
        OOP.release   = 20
        OOP.sLevel    = 50
        OVS.noteFixed = 64 //10/4
        OVS.volFixed  = 128
        OVS.panFixed  = 128
        //9/8 unique ID for tab
        uid = ProcessInfo.processInfo.globallyUniqueString
        masterPitch = 0
        setupVoiceParams()
    }
    
    //-----------(oogieVoice)=============================================
    func copy(with zone: NSZone? = nil) -> Any {
        let copy      = OogieVoice()
        //Only copy editable/savable/ID items, dont worry about most working vars
        copy.OVS      = OVS
        copy.OOP      = OOP
        copy.inPipes  = inPipes
        copy.outPipes = outPipes
        copy.uid      = uid
        //Performance vars that NEED copying
        copy.muted    = muted
        return copy
    }
    
    //-----------(oogieVoice)=============================================
    func setupVoiceParams()
    {
        // Load up params dictionary with string / array combos
        voiceParamsDictionary["00"] = LatParams
        voiceParamsDictionary["01"] = LonParams
        voiceParamsDictionary["02"] = TypeParams
        voiceParamsDictionary["03"] = PatchParams
        voiceParamsDictionary["04"] = PitchShiftParams //5/14
        voiceParamsDictionary["05"] = ScaleParams
        voiceParamsDictionary["06"] = LevelParams
        voiceParamsDictionary["07"] = ThreshParams  //5/2 add threshold
        voiceParamsDictionary["08"] = NChanParams   //10/4 n/v/p channels
        voiceParamsDictionary["09"] = VChanParams
        voiceParamsDictionary["10"] = PChanParams
        voiceParamsDictionary["11"] = NFixedParams   //10/4 n/v/p fixed
        voiceParamsDictionary["12"] = VFixedParams
        voiceParamsDictionary["13"] = PFixedParams
        voiceParamsDictionary["14"] = RotTriggerParams //4/18 add rot trigger
        voiceParamsDictionary["15"] = DetuneParams //5/9 add detune
        voiceParamsDictionary["16"] = BottomMidiParams
        voiceParamsDictionary["17"] = TopMidiParams
        voiceParamsDictionary["18"] = MidiChannelParams
        voiceParamsDictionary["19"] = VNameParams
        voiceParamsDictionary["20"] = VCommParams   //2/4
    } //end setupVoiceParams
    
    //-----------(oogieVoice)=============================================
    func addToDebugHistory(n:Int)
    {
        debugHistory[dhptr] = debugTuple(Date(),n)
        dhptr+=1
        if dhptr >= dhmax  //wraparound
           {dhptr = 0
            analyzeDebugHistory()
        }
    }
    
    //-----------(oogieVoice)=============================================
    func analyzeDebugHistory()
    {
        //loop over history starting at dhptr and wrapping around
        var ptr   = dhptr
        var optr  = 0
        var avet  = 0.0 //average / total
        var avec  = 0   //ave counter
        var mint  = 999.0   //min/max limits
        var maxt  = -999.0
        for i in 1...dhmax
        {
            if i > 1 //start getting data on 2nd loop
            {
                let t1 = debugHistory[optr]  //get last tuple
                let t2 = debugHistory[ptr]   // and current one
                if let start = t1?.date      //now get two timestamps
                {
                    if let end   = t2?.date
                    {
                        let timeInterval : Double = end.timeIntervalSince(start)
                        //print("loop \(i) : s \(start) e \(end) interval \(timeInterval)")
                        if timeInterval < 1.0 //ignore large intervals
                        {
                            avet+=timeInterval
                            avec+=1
                            mint = min(mint,timeInterval)
                            maxt = max(maxt,timeInterval)
                        }
                    }
                }
            }
            optr = ptr    //remember last ptr
            ptr  = ptr+1  //increment ptr / wraparound
            if ptr >= dhmax {ptr = 0}
        }
        avet = avet / Double(avec)
        //print("ave \(avet) min/max \(mint),\(maxt)")
        
    } //end analyzeDebugHistory
    
    
    var dogcount = 0
    var lasta  = 0.0
    var lastba = 0.0
    var lastbeatTime = Date()
    //-----------(oogieVoice)=============================================
    // check to see if angle a has gone past a rotTrigger boundary
    // BUG: angle is still varying WILDLY, and beat misses when this happens!
    func getBeat(a:Double) -> Bool
    {
        if OVS.rotTrigger == 0.0 {return false}
        let pi2 = 2.0 * .pi
        var a0to2pi = a
        // get our radian offset around the circle...
        a0to2pi.formTruncatingRemainder(dividingBy:pi2)
        a0to2pi = a0to2pi - (pi2 * OVS.xCoord) //apply x offset
        while a0to2pi < 0.0
        {
            a0to2pi = a0to2pi + pi2
        }
        let doubleBeat = a0to2pi / (pi2 / OVS.rotTrigger)
        let newBeat = Int(floor(doubleBeat))
        //NSLog("getBeat a %f angle %f  aoff %f  ", a,a0to2pi,a-lasta  )
        lasta = a
        if newBeat != beat
        {
            let beatTime = Date()
            let beatDelta = beatTime.timeIntervalSince(lastbeatTime)
            //NSLog("...newbeat %d tdelta %f adelta %f",newBeat,beatDelta,a - lastba)
            beat = newBeat
            lastbeatTime = beatTime
            lastba = a
            return true
        }
        return false
    } //end getBeat
    
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if voiceParamsDictionary == nil    //5/9 saw crash here! WTF
        {
            print("getNthParams ERROR: nil params!")
            return [""]
        }
        if n < 0 || n >= voiceParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return voiceParamsDictionary[key]!
    }
    
    
    //-----------(oogieVoice)=============================================
    //11/25 VERY BUSY, called by pipes! assume name is lowercase
    func getChanValueByName (n : String) -> Int
    {
        switch(n)
        {
        case "red"          :  return RRR
        case "green"        :  return GGG
        case "blue"         :  return BBB
        case "cyan"         :  return CCC
        case "magenta"      :  return MMM
        case "yellow"       :  return YYY
        case "hue"          :  return HHH
        case "luminsotiy"   :  return LLL
        case "saturation"   :  return SSS
        default             :  return 0
        }
    } //end getChanValueByName
    
    
    //-----------(oogieVoice)=============================================
    // 1/29 new
    func getParmLimsForPipe(name:String) -> (lolim:Double , hilim:Double)
    {
        //print("getplfp \(name)")
        var lol = 0.0
        var hil = 1.0
        //must do search because of case difference!
        var found  = false
        var iindex = 0
        // 1/29 find our name...maybe make case-independent array search method?
        for pn in voiceParamNames
        {
            if pn.lowercased() == name
            { found = true ; break }
            iindex+=1
        }
        if found // find param name
        {
            let sindex = String(format: "%2.2d", iindex)         // convert to string for lookup
            if let paramz = voiceParamsDictionary[sindex]       // finally, get params array
            {
                let pc = paramz.count
                if let ptype = paramz[1] as? String //Check param type
                {
                    if (ptype == "string") //string params dont have set limits
                        { hil = Double(pc-2) }
                    else // double params have fixed limits
                    {
                        //2/1 WRONG! look for the corrct indices!!!
                        lol = paramz[2] as! Double
                        hil = paramz[3] as! Double
                    }
                }
            } //end let paramz
        } //end let iindex
        return(lol,hil)
    } //end getParmLimsForPipe
    
    
    //=====<oogie2D mainVC>====================================================
    // 8/23 assumes only one shape and only one pointer!
    //  XYCoord are in radian units, Y is -pi/2 to pi/2
    //   most math is done in 0..1 XY coords, then bmp size applied
    // 5/3 moved in from mainVC, reduce args
//    func getShapeColor(shape: SphereShape, xCoord : Double , yCoord : Double , angle : Double) -> (R:Int , G:Int , B:Int , A:Int)
    func getShapeColor(shape:OogieShape) -> (R:Int , G:Int , B:Int , A:Int)
    {
        let aoff = Double.pi / 2.0  //10/25 why are we a 1/4 turn off?
        //get angle from sloppy global! bail with black color if not present
        let angle = shape.angle
        //print("getShapeColor:voice \(OVS.key) shape \(OVS.shapeKey) : angle \(angle)")//
        // 11/3 fix math error in xpercent!
        var xpercent = (angle + aoff - OVS.xCoord) / twoPi  //11/3 apply xcoord B4 dividing!
        xpercent = -1.0 * xpercent                     //  and flip X direction
        //Keep us in range 0..1
        while xpercent > 1.0 {xpercent = xpercent - 1.0}
        while xpercent < 0.0 {xpercent = xpercent + 1.0}
        let ypercent = 1.0 - ((OVS.yCoord + .pi/2) / .pi)
        let bmpX = Int(Double(shape.bmp.wid) * xpercent)
        let bmpY = Int(Double(shape.bmp.hit) * ypercent) //9/15 redo!
        let cp = CGPoint(x: bmpX, y: bmpY)
        //print("gsc[\(shape.name)] cp \(cp)")
        let pColor = shape.bmp.getPixelColor(pos: cp) //pColor is class member
        //Sloppy! need to get RGB though...
        var pr : CGFloat = 0.0
        var pg : CGFloat = 0.0
        var pb : CGFloat = 0.0
        var pa : CGFloat = 0.0
        pColor.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        //print("...xycoord \(OVS.xCoord),\(OVS.yCoord) : bmpxy \(bmpX),\(bmpY)")
        //print("...rgb \(pr),\(pg),\(pb)")
        return (Int(pr * 255.0),Int(pg * 255.0),Int(pb * 255.0),Int(pa * 255.0))
    } //end getShapeColor
    
    
    //-----------(oogieVoice)=============================================
    func dumpParams() -> String
    {
        var s = String(format: "[key:%@]\n",OVS.key)
        for pname in voiceParamNames
        {
            let pTuple = getParam(named : pname.lowercased())
            s = s + String(format: "%@:%@\n",pname,pTuple.sParam)
        }
        s = s + String(format: "UID:%@\n",OVS.uid)
        return s
    }
    
    //-----------(oogieVoice)=============================================
    func getParamList() -> [String]
    {
        if !paramListDirty {return paramList} //get old list if no new params
        paramList.removeAll()
        for pname in voiceParamNames
        {
            let pTuple = getParam(named : pname.lowercased())
            paramList.append(pTuple.sParam)  
        }
        paramListDirty = false
        return paramList
    } //end getParamList


    //-----------(oogieVoice)=============================================
    // using this voices internal type, get array of appropriate patchnames
    func getPatchNameArray() -> [Any]
    {
        var patchNames = [String]()
        patchNames.append("Patch")
        patchNames.append("string")
//6/29/21 FIX THIS!
//        var dict = allP.synthPatchDictionary             //assume synth patches...
//        if OOP.type == PERCKIT_VOICE
//        {
//            dict = allP.percKitPatchDictionary     //need percKit patches instead?
//        }
//        else if OOP.type == PERCUSSION_VOICE
//        {
//            dict = allP.percussionPatchDictionary  //need percussion patches instead?
//        }
//        else if OOP.type == SAMPLE_VOICE
//        {
//            dict = allP.GMPatchDictionary
//            var lilNames : [String] = []
//            for (name, _) in dict {lilNames.append(name)}
//            lilNames = lilNames.sorted()
//            for name in lilNames {  patchNames.append(name)  }
//        }
//        if OOP.type != SAMPLE_VOICE  //sort percussion!
//        {
//            for (name, _) in dict  {  patchNames.append(name)  } //append names
//            patchNames = patchNames.sorted() //5/15 wups!
//       }
        //10/18 Samples get sorted alphabetically...
        return patchNames
    } //end getPatchNameArray
    
    //-----------(oogieVoice)=============================================
    // 9/26 find our default in allpatches
    func loadDefaultPatchForVoiceType()
    {
        //6/29/21 FIX!   OOP = allP.getDefaultPatchByType(ptype: OOP.type)
        //10/15 figger out which buffers to use...
        if OOP.type == Int(PERCKIT_VOICE) { getPercLooxBufferPointerSet() }
    }
    
    //-----------(oogieVoice)=============================================
    // Goes to canned voices subfolder for file!
    func loadVoice(name:String)
    {
        OVS.name = name
        OVS = DataManager.loadVoice(name, with: OVStruct.self)
        // DHS 9/27 add type to patch getter
        //6/29/21 FIX! OOP = allP.getPatchByName(name: OVS.patchName)
        //10/15 figger out which buffers to use...
        if OOP.type == Int(PERCKIT_VOICE) { getPercLooxBufferPointerSet() }
    }
    
    //-----------(oogieVoice)=============================================
    // voice struct gets... why does loadVoice rely on dataManager but this does not?
    //   instead OVS.saveItem calls DataManager
    func saveVoice(name:String)
    {
        OVS.name      = name      //Voice Name: for 3D voice generator in AR space
        OVS.patchName = OOP.name // Patch Name: Synth / Sample patch we are using for this voice
        OVS.saveItem()
    }

    //-----------(oogieVoice)=============================================
    // 4/23 sets param by name to either double or string depending on type
    //  NOTE: some fields need to be pre-processed before storing, that
    //   is the responsibility of the caller!
    func setParam(named name : String , toDouble dval: Double , toString sval: String)
    {
        let ival = Int(dval) //some params are stored as integers!
        //print("setParam \(dval)")

        switch (name)
        {
        case "latitude"     : OVS.yCoord = dval
        case "longitude"    : OVS.xCoord = dval
        case "patch"        : OVS.patchName = sval
        case "type"         : break
        case "scale"        : OVS.keySig     = ival
        case "chromatickey" : OVS.pitchShift = ival //5/14
        case "level"        : OVS.level      = dval
        case "threshold"    : OVS.thresh     = ival
        case "nchan"        : OVS.noteMode   = ival
        case "vchan"        : OVS.volMode    = ival
        case "pchan"        : OVS.panMode    = ival
        case "nfixed"       : OVS.noteFixed  = ival
        case "vfixed"       : OVS.volFixed   = ival
        case "pfixed"       : OVS.panFixed   = ival
        case "rottrigger"   : OVS.rotTrigger = dval
        case "detune"       : OVS.detune     = ival
        case "ofixed"       : OVS.panFixed   = ival
        case "bottommidi"   : OVS.bottomMidi = ival
        case "topmidi"      : OVS.topMidi = ival
        case "midichannel"  : OVS.midiChannel = ival
        case "name"         : OVS.name = sval
        case "comment"      : OVS.comment = sval
        //8/11/21 performance params
        case "portamento"    : OVS.portamento   = ival
        case "viblevel"      : OVS.vibLevel     = ival
        case "vibspeed"      : OVS.vibSpeed     = ival
        case "vibwave"       : OVS.vibWave      = ival
        case "vibelevel"     : OVS.vibeLevel    = ival
        case "vibespeed"     : OVS.vibeSpeed    = ival
        case "vibewave"      : OVS.vibeWave     = ival
        case "delaytime"     : OVS.delayTime    = ival
        case "delaysustain"  : OVS.delaySustain = ival
        case "delaymix"      : OVS.delayMix     = ival

        default: print("Error:Bad voice param in set:" + name)   //5/9
        } //end switch
        paramListDirty = true
    } //end setParam

    
    //-----------(oogieVoice)=============================================
    // 4/22/20 gets param by name, returns tuple
    func getParam(named name : String) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = ""
        var isString = false
        switch (name)  //depending on param, set double or string
        {
        case "latitude":    dp = OVS.yCoord
        case "longitude":   dp = OVS.xCoord
        case "type":        dp = Double(OOP.type)
        case "patch":       sp = OVS.patchName.lowercased()
                            isString = true
        //OUCH! MISSING KEY!!!WTF?
        case "scale":       dp = Double(OVS.keySig)
        case "chromatickey":dp = Double(OVS.pitchShift)  //5/14
        case "level":       dp = OVS.level
        case "threshold":   dp = Double(OVS.thresh)
        case "nchan":       dp = Double(OVS.noteMode)
        case "vchan":       dp = Double(OVS.volMode)
        case "pchan":       dp = Double(OVS.panMode)
        case "nfixed":      dp = Double(OVS.noteFixed)
        case "vfixed":      dp = Double(OVS.volFixed)
        case "pfixed":      dp = Double(OVS.panFixed)
        case "rottrigger":  dp = Double(OVS.rotTrigger)
        case "detune":      dp = Double(OVS.detune)   //5/9 add detune
        case "topmidi":     dp = Double(OVS.topMidi)
        case "bottommidi":  dp = Double(OVS.bottomMidi)
        case "midichannel": dp = Double(OVS.midiChannel)
        case "name":        sp = OVS.name    //2/4
                            isString = true
        case "comment":     sp = OVS.comment //2/4
                            isString = true
        default:print("Error:Bad voice param in get:" + name)  //5/9
        }
        if !isString  {sp = String(format: "%4.2f", dp)} //4/25 pack double as string
        return(name , dp , sp) //pack up name,double,string
    } //end getParam
    
    //-----------(oogieVoice)=============================================
    // 11/18 move in from mainvC. heavy lifter, lots of crap brought together
    //  needs masterPitch. should it be an arg or class member?
    //  4/19 add angle arg
    func playColors(angle : Double, rr : Int ,gg : Int ,bb : Int) -> Bool
    {
        //print("playColors...")
        var inkeyNote = 0
        var inkeyOldNote = 0
        //this sets midiNote!
        setInputColor(chr: rr, chg: gg, chb: bb)
        //DHS TEST ONLY!!! this should be modulated by vchan ? depending on voice mode
        //(sfx() as! soundFX).setSynthGain(128)
        
        var noteWasPlayed = false
        bufferPointer = 0;
        if OOP.type == PERCUSSION_VOICE
        {
            bufferPointer = Int((sfx() as! soundFX).getPercussionBuffer(OOP.name.lowercased())) //4/12/20
        }
        else if OOP.type == SAMPLE_VOICE
        {
            bufferPointer = Int((sfx() as! soundFX).getGMBuffer(OOP.name))
        }
        
        //NSLog("....playColors:NOTE: %d npvchan %d %d %d",midiNote,nchan,pchan,vchan)
        let vt    = OOP.type
        if midiNote > 0  || OVS.rotTrigger != 0//Play something?
        {
            //NSLog("OVPlayColors:Midinote %d",midiNote)
            (sfx() as! soundFX).setSynthMIDI(Int32(OVS.midiDevice), Int32(OVS.midiChannel)) //chan: 0-16
            let nc = (sfx() as! soundFX).getSynthNoteCount()
            inkeyOldNote = oldNote
            // 5/14 add pitch shift
            inkeyNote    = masterPitch + OVS.pitchShift + Int((sfx() as! soundFX).makeSureNoteis(inKey: Int32(OVS.keySig),Int32(midiNote)))
            // Mono: Handle releasing old note...
            if OVS.poly == 1 {(sfx() as! soundFX).releaseNote(Int32(inkeyOldNote),0)} //2nd arg, WTF??
            //TBD....[synth setTimetrax:OVgettimetrax(vloop)];
            //New note outside tolerance?
            //print(" toler check: nchan \(nchan) lnchan \(lnchan) nc \(nc) thresh \(OVS.thresh)",nchan,lnchan,nc )
            
            var mono = 1
            if OVS.poly != 0 { mono = 0 }
            
            //4/19 add check for beats as needed:
            var gotTriggered = false
            if OVS.rotTrigger == 0 //Use colors as trigger?
            {
                gotTriggered = (abs (nchan - lnchan) > OVS.thresh) && nc < 12 //5/2
                if (nc >= 12){ print(" SYNTH/sample notecount overflow!!") }
            }
            else //use beats trigger?
            {
                    //print("beats key \(OVS.key) angle \(angle)")
                    gotTriggered = getBeat(a: angle) //uses angle from shape
            }
            //if (abs (nchan - lnchan) > 2*OVS.thresh) && nc < 12
            if gotTriggered // 4/19
            {
               // NSLog(" bing!==============")
                (sfx() as! soundFX).setSynthMono(Int32(mono))
                (sfx() as! soundFX).setSynthMonoUN(Int32(uniqueCount))
                
                
                //sfx() as! soundFX).build
                //Does this need to be above ADSR?
                //if vt == SYNTH_VOICE (sfx() as! soundFX).buildaWaveTable(0, Int32(OOP.wave))
                if vt == SYNTH_VOICE
                {
                    (sfx() as! soundFX).buildaWaveTable(0, Int32(OOP.wave))

                }
                (sfx() as! soundFX).setSynthAttack(Int32(OOP.attack))
                (sfx() as! soundFX).setSynthDecay(Int32(OOP.decay))
                (sfx() as! soundFX).setSynthSustain(Int32(OOP.sustain))
                (sfx() as! soundFX).setSynthSustainL(Int32(OOP.sLevel))
                (sfx() as! soundFX).setSynthRelease(Int32(OOP.release))
//                (sfx() as! soundFX).setSynthRelease(Int32(OOP.releaseTime))
                (sfx() as! soundFX).buildEnvelope(0,true)
                (sfx() as! soundFX).setSynthPortamento(Int32(OVS.portamento))
                (sfx() as! soundFX).setSynthVibAmpl(Int32(OVS.vibLevel))
                (sfx() as! soundFX).setSynthVibSpeed(Int32(OVS.vibSpeed))
                (sfx() as! soundFX).setSynthVibWave(Int32(OVS.vibWave))
                (sfx() as! soundFX).setSynthVibeAmpl(Int32(OVS.vibeLevel))
                (sfx() as! soundFX).setSynthVibeSpeed(Int32(OVS.vibeSpeed))
                (sfx() as! soundFX).setSynthVibeWave(Int32(OVS.vibeWave))
                if OVS.portamento > 0 //8/11 keep track of last note for portamento!
                {
                    (sfx() as! soundFX).setPortamentoLastNote(Int32(lastnoteplayed))
                }
                (sfx() as! soundFX).setSynthDelayVars(
                    Int32(OVS.delayTime),Int32(OVS.delaySustain),Int32(OVS.delayMix)
                )
                // 8/11/21 set these 3 to defaults for now, will become params
                (sfx() as! soundFX).setSynthPLevel(50);
                (sfx() as! soundFX).setSynthPKeyOffset(50);
                (sfx() as! soundFX).setSynthPKeyDetune(50);

                var noteToPlay = -1
                var bptr = 0
                //-------SYNTH: built-in canned wave samples--------------------------
                if vt == SYNTH_VOICE
                {
                    lastgain = Int(Double(vchan) * 0.7 * OVS.level) // 8/11 for delay
                    lastbuf  = 0
                    lasttype = SYNTH_VOICE

                    (sfx() as! soundFX).setSynthGain(Int32(lastgain))
                    if OVS.panMode != 11  //No fixed pan? Use pchan
                    {
                        (sfx() as! soundFX).setSynthPan(Int32(pchan))
                    }
                    else //Forced pan?
                    {
                        (sfx() as! soundFX).setSynthPan(Int32(OVS.panFixed))
                    }
                    (sfx() as! soundFX).setSynthSampOffset(Int32(OVS.sampleOffset))
                    //4/19 add master pitch,2 octave offset (synths are low sample rate)
                    noteToPlay    = inkeyNote + 24
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt))
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay:  32 , Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
                    noteWasPlayed = true
                    lastnoteplayed = inkeyNote
                    applyDelayIfAny() //8/11/21
                    noteWasPlayed = true   //5/15
                } //End synth block
                else if vt == HARMONY_VOICE
                {
                } //end harmony block
                else if vt == SAMPLE_VOICE //10/16 add GM samples
                {
                    lastgain = Int(Double(vchan) * 0.7 * OVS.level) //8/11 for delay

                    (sfx() as! soundFX).setSynthGain(Int32(lastgain))
                    (sfx() as! soundFX).setSynthDetune(Int32(OVS.detune)); //5/9 add detune as editable param
                    (sfx() as! soundFX).setSynthPan(Int32(pchan))
                    bptr = bufferPointer
                    lastbuf  = bptr //8/11 for delay
                    lasttype = SAMPLE_VOICE
                    noteToPlay = inkeyNote
                    //ok playit
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(inkeyNote), Int32(bptr) ,Int32(vt)) //Play Middle C for now...
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(inkeyNote), Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
                    noteWasPlayed = true
                    lastnoteplayed = inkeyNote
                    applyDelayIfAny() //8/11/21
                } //end sample block 9/22
                else if vt == PERCUSSION_VOICE
                {
                    lastgain = Int(Double(vchan) * 0.7 * OVS.level) // 8/11 for delay
                    (sfx() as! soundFX).setSynthGain(Int32(lastgain))
                    (sfx() as! soundFX).setSynthDetune(Int32(OVS.detune)); //5/9 add detune as editable param
                    // 9/27 no trigger key,just trigger of tolerance..
                    (sfx() as! soundFX).setSynthPan(Int32(pchan))
                    bptr = bufferPointer
                    lastbuf  = bptr //8/11 for delay
                    lasttype = PERCUSSION_VOICE
                    if OVS.detune == 0  //5/9 add detune on/off
                        {noteToPlay = 60}
                    else
                        {noteToPlay = inkeyNote}

                    //ok playit
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt)) //Play Middle C for now...
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(noteToPlay) , Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
                    noteWasPlayed = true
                    lastnoteplayed = noteToPlay
                    applyDelayIfAny() //8/11/21
                } //end percussion block
                else if vt == PERCKIT_VOICE
                {
                    var topMidi = OVS.topMidi
                    var botMidi = OVS.bottomMidi
                    if (topMidi - botMidi < 10) //Handle illegal crap, this should be ELSEWHERE!!!
                    {
                        botMidi = 40   //5/14 new defaults
                        topMidi = 80
                    }
                    var octave = (nchan - botMidi) / 20 // 12 //get octave
                    octave = max(min(octave,7),0)
                    //10/15  CRASH HERE!!!
                    bptr = bufferPointerSet[octave]
                    lastbuf  = bptr //8/11 for delay
                    lasttype = PERCKIT_VOICE

                    //print("note \(nchan) oct \(octave) bptr \(bptr)")
                    noteToPlay = 32
//??                    lastnoteplayed = noteToPlay
                    applyDelayIfAny() //8/11/21

                } //end perckit block
                
//                if noteToPlay != -1
//                {
//                    if quantTime == 0 //No Quant, play now
//                    {
//                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt))
//                    }
//                    else
//                    {
//                        (sfx() as! soundFX).playNote(withDelay:  32 , Int32(bptr) ,Int32(vt),Int32(quantTime))
//                    }
//                    noteWasPlayed = true
//                    lastnoteplayed = inkeyNote
//                    //print("...playnote \(noteToPlay)");
//                }
                uniqueCount = Int((sfx() as! soundFX).getSynthUniqueCount())
                hiLiteFrame = MAX_CBOX_FRAMES
                oldNote     = nchan
                saveColors()
                addToDebugHistory(n:noteToPlay) //4/19 add debug tracker
            } //end abs toler check
        } //end midinote...
        return noteWasPlayed
    } //end playColors
    
    
    
    //====(OOGIECAM MainVC)============================================
    //uses workVoice, re-emits notes as needed
    func applyDelayIfAny()
    {
        //Effect flag off? Bail!
//    #ifdef DJMODE_TESTER
//        if (fxbFlags[MVC_ALL_FX] == FALSE || fxbFlags[MVC_DELAY_FX] == FALSE) return;
//    #endif
        if OVS.delayMix == 0 || OVS.delayTime == 0 {return} //NO Delay? no apply
        //Delay time goes from 0 to 100, scale to fit here...
        let timeMS = OVS.delayTime * 10;  //goes up to 1 second that way
        var workTime = timeMS;
        //OK, we may need to loop a bit here...
        var sustain      = Float(lastgain) / 255.0
        var sustainmult  = Float(OVS.delaySustain) * 0.01 //percent value
        if sustainmult == 1.0  {sustainmult = 0.98}
        let mixlevel     = Float(OVS.delayMix) * 0.01; //percent value
        while sustain > 0.05
        {
            var gain = Int32( mixlevel * sustain * 255.0);
            if gain > 255  {gain = 255}
            if gain < 0    {gain = 0}
            (sfx() as! soundFX).setSynthGain(gain)
            sustain = sustain * sustainmult
            (sfx() as! soundFX).playNote(withDelay:  Int32(lastnoteplayed) , Int32(lastbuf) ,Int32(lasttype),Int32(workTime))
            workTime+=timeMS;
        } // end while

    } //end applyDelayIfAny

    
    //-----------(oogieVoice)=============================================
    //    func savePatch (name:String)
    //    {
    //        OOP.name = name
    //        OOP.saveItem(filename:name, cat:"GM") //11/14 new arg
    //    }
    
    //-----------(oogieVoice)=============================================
    // called when user switches type, need to reset synth/samples/whatever...
    func loadDefaultsForNewType(nt : String)
    {
        //print("ldfnt nt \(nt)")
        if  nt == "synth"
        {
            //6/29/21 FIX! OOP = allP.getDefaultPatchByType(ptype: Int(SYNTH_VOICE))
        }
        else if nt == "percussion" //9/22
        {
            OOP.clear()
            //6/29/21 FIX! OOP = allP.getDefaultPatchByType(ptype: Int(PERCUSSION_VOICE))
            bufferPointer = Int((sfx() as! soundFX).getPercussionBuffer(OOP.name))
            triggerKey    = Int((sfx() as! soundFX).getPercussionTriggerKey(OOP.name))
        }
        else if nt == "sample" //10/16
        {
            OOP.clear()
            //6/29/21 FIX! OOP = allP.getDefaultPatchByType(ptype: Int(SAMPLE_VOICE))
            bufferPointer = Int((sfx() as! soundFX).getGMBuffer(OOP.name))
        }
        else if nt == "perckit" //9/24
        {
            //6/29/21 FIX! OOP = allP.getDefaultPatchByType(ptype: Int(PERCKIT_VOICE))
            getPercLooxBufferPointerSet() //10/15 figger out which buffers to use...
        }
        OVS.patchName = OOP.name  //10/15 make sure we know the new patch name!
    } //loadDefaultsForNewType
    
    //-----------(oogieVoice)=============================================
    func getParamCount() -> Int
    {
        return voiceParamNames.count   // 2/5 WTF? BUG!!!
    }

    //-----------(oogieVoice)=============================================
    //10/15 relies heavily on structure members in this class
    func getPercLooxBufferPointerSet()
    {
        bufferPointerSet.removeAll() //clear array...
        for pName in OOP.percLoox   //loop over lookup perc names...
        {   //and add approp. buffer pointers to pointer set
            bufferPointerSet.append(Int((sfx() as! soundFX).getPercussionBuffer(pName.lowercased())))
        }
    } //end getPercLooxBufferPointerSet
    
    //-----------(oogieVoice)=============================================
    func setup(vtype:Int,vmisc:Int)
    {
        OOP.type = vtype
        if OOP.type == NULL_VOICE {return}
        
        //NEED TO CHANGE!
        OOP.wave        = 1 //sine
        OVS.poly        = 1 //poly voice by default
        OVS.panMode     = 11  // Use "NA"
        OVS.thresh    = 4        //    perc threshold for soundoff
        OVS.quant     = 30        //    Quantization: 0 = none 100 = 1/4 notes?
        OVS.bottomMidi  = 12    //  2/28 redo C 0
        OVS.topMidi     = 108  //  2/28 redo  C 8
        OVS.keySig      = 0 //Major


        OVS.noteMode = 3
        OVS.volMode  = 4
        OVS.octave      = 0 //No octave shift
        OVS.noteMode    = 3 //Use Hue
        OVS.volMode     = 9  // Use "NA"
        OVS.detune      = 0   //  detune only works for samples?
        OVS.level       = 0.5  //Get NO SOUND udderwise
        OVS.midiDevice  = 0 //New voice has NO MIDI until turned on...
        OVS.midiChannel = 0
        OVS.pitchShift  = 0
        if OOP.type == SYNTH_VOICE || OOP.type == HARMONY_VOICE
        {
            OOP.attack   = SYNTHA_DEFAULT
            OOP.decay    = SYNTHD_DEFAULT
            OOP.sustain  = SYNTHS_DEFAULT
            OOP.sLevel   = SYNTHSL_DEFAULT
            OOP.release  = SYNTHR_DEFAULT
            OOP.duty     = SYNTHDUTY_DEFAULT
        }
        if OOP.type == SAMPLE_VOICE //here's where our misc arg is important!
        {
            OVS.whichSamp = OVS.sampleOffset + vmisc
            OVS.detune    = 1   // Most samples will get detuned
        }
        //Init percussion lookups (six are used for each voice)
        for loop in 0...MAX_LOOX-1
        {
            OOP.percLoox[loop]     = percDefaults[loop]
            OOP.percLooxPans[loop] = 11
        }
        //clear runtime color storage
        nchan     = 0
        pchan     = 0
        vchan     = 0
        lnchan    = 0
        lpchan    = 0
        lvchan    = 0
        lschan    = 0

    } //end setup
    
    
    //-----------(oogieVoice)=============================================
    func RGBtoHLS(R:Int,G:Int,B:Int)
    {
    /* calculate lightness */
    let cMax = max( max(R,G), B);
    let cMin = min( min(R,G), B);
    var Rdelta = 0
    var Gdelta = 0
    var Bdelta = 0
    //populate HKS
    LLL = ( ((cMax+cMin)*HLSMAX) + RGBMAX )/(2*RGBMAX)
    
    if (cMax == cMin) {            /* r=g=b --> achromatic case */
        SSS = 0                   /* saturation */
        HHH = 0                     /* hue */
        //NSLog(@"bad hue... RGB %d %d %d",R,G,B);
    }
    else {                        /* chromatic case */
        /* saturation */
        if LLL <= (HLSMAX/2)
        {
            SSS = ( ((cMax-cMin)*HLSMAX) + ((cMax+cMin)/2) ) / (cMax+cMin)
        }
        else
        {
            SSS = ( ((cMax-cMin)*HLSMAX) + ((2*RGBMAX-cMax-cMin)/2) )
                / (2*RGBMAX-cMax-cMin)
        }
        /* hue */
        Rdelta = ( ((cMax-R)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
        Gdelta = ( ((cMax-G)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
        Bdelta = ( ((cMax-B)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
    
        if (R == cMax)
        {
            HHH = Bdelta - Gdelta;
            //NSLog(@"H1... bgdel %d %d",Bdelta,Gdelta);
        }
        else if (G == cMax)
        {
            HHH = (HLSMAX/3) + Rdelta - Bdelta;
            //NSLog(@"H2... bgdel %d %d",Rdelta,Bdelta);
        }
        else /* B == cMax */
        {
            HHH = ((2*HLSMAX)/3) + Gdelta - Rdelta;
            //NSLog(@"H3... grdel %d %d",Gdelta,Rdelta);
        }
        //make sure we are in range 0..255??? int modulo
        while (HHH < 0)
        {
            HHH += HLSMAX;
        }
        while (HHH > HLSMAX)
        {
            HHH -= HLSMAX;
        }
         //NSLog(@" hls %d %d %d",HH,LL,SS);
       } //end else
    } //end RGBtoHLS

    
    //-----------(oogieVoice)=============================================
    func RGBtoCMY(R:Int,G:Int,B:Int)
    {
        var minCMY,lcc,lmm,lyy : Double
        // BLACK
        CCC = 0
        MMM = 0
        YYY = 0
        if R==0 && G==0 && B==0
        {
            KKK = 1
            return
        }
        lcc = 1.0 - (Double(R)/255.0)
        lmm = 1.0 - (Double(G)/255.0)
        lyy = 1.0 - (Double(B)/255.0)
        minCMY = lcc //get smallest of 3
        if minCMY > lmm {minCMY = lmm}
        if minCMY > lyy {minCMY = lyy}
    
        CCC = Int(255.0 * (lcc-minCMY) / (1.0 - minCMY))
        MMM = Int(255.0 * (lmm-minCMY) / (1.0 - minCMY))
        YYY = Int(255.0 * (lyy-minCMY) / (1.0 - minCMY))
        KKK = Int(255.0 * minCMY)
    // NSLog(@" RGB %d %d %d : cmyk %d  %d %d %d",R,G,B,CC,MM,YY,KK);
    
    } //end  RGBtoCMY
    

    
    //-----------(oogieVoice)=============================================
    func setInputColor(chr:Int,chg:Int,chb:Int)
    {
        var tnchan = 0
        var tpchan = 0
        var tvchan = 0
        let tschan = 0
        let pf     = 0.0

        if (chr==0) && (chg==0) && (chb==0) //black means no sound/note/center pan
        {
            nchan = 0
            pchan = 128
            vchan = 0
            midiNote = 0
            return
        }
        pchan = 128
        vchan = 128
        //get MusiColors(TM) data...
        //11/25 WHATDAFUK? i thiought this was already here! populate channels
        RRR = chr
        GGG = chg
        BBB = chb
        RGBtoHLS( R:chr, G:chg, B:chb) //Do All conversions...
        RGBtoCMY( R:chr, G:chg, B:chb)

        //print("nvpmodes \(OVS.noteMode), \(OVS.volMode), \(OVS.panMode)")
        //Get color/etc channel out to note channel as needed
        switch(OVS.noteMode)
        {
        case 0:  tnchan = chr
        case 1:  tnchan = chg
        case 2:  tnchan = chb
        case 3:  tnchan = HHH
        case 4:  tnchan = LLL
        case 5:  tnchan = SSS
        case 6:  tnchan = CCC
        case 7:  tnchan = MMM
        case 8:  tnchan = YYY
        default: tnchan = OVS.noteFixed // 10/4 introduce fixed values
        }
        //Get color/etc channel out to volume channel as needed
        switch(OVS.volMode)
        {
        case 0:  tvchan = chr
        case 1:  tvchan = chg
        case 2:  tvchan = chb
        case 3:  tvchan = HHH
        case 4:  tvchan = LLL
        case 5:  tvchan = SSS
        case 6:  tvchan = CCC
        case 7:  tvchan = MMM
        case 8:  tvchan = YYY
        default: tvchan = OVS.volFixed // 10/4 introduce fixed values
        }
        
        //Get color/etc channel out to pan channel as needed
        lpchan = 128 //start w/ reasonable default
        if OOP.type != PERCKIT_VOICE   //5/9
        {
            switch(OVS.panMode) //10/4 was using wrong property!
            {
            case 0:  tpchan = chr
            case 1:  tpchan = chg
            case 2:  tpchan = chb
            case 3:  tpchan = HHH
            case 4:  tpchan = LLL
            case 5:  tpchan = SSS
            case 6:  tpchan = CCC
            case 7:  tpchan = MMM
            case 8:  tpchan = YYY
            default: tpchan = OVS.panFixed // 10/4 introduce fixed values
            }
            
        }
       
        //OK, make our note fit into the range designated by user...
        let bmr = Double(OVS.topMidi-OVS.bottomMidi)  //get user target key range
        let bmn = Double(tnchan) / 256.0      //   input hue, convert to 0.0 - 1.0 range
        if OOP.type != PERCKIT_VOICE   //5/9
        {
            midiNote =  OVS.bottomMidi + Int(bmr * bmn);
        }
        else //Perc Kit ONLY!  5/9
        {
            if OVS.detune != 0
            {
                midiNote = OVS.topMidi + Int(bmr * bmn)
            }
            else
            {
                midiNote = tnchan
            }
            var whichperc = midiNote / 44; //44 splits us into 6 octs/ 38:7
            if whichperc < 0   { whichperc = 0}
            //9/23 WTF??? whichperc = OOP.percLoox[whichperc]
            //Here is where we will add percussion pan:
            switch(OOP.percLooxPans[whichperc])
                {
                case 0:  tpchan = chr
                case 1:  tpchan = chg
                case 2:  tpchan = chb
                case 3:  tpchan = HHH
                case 4:  tpchan = LLL
                case 5:  tpchan = SSS
                case 6:  tpchan = CCC
                case 7:  tpchan = MMM
                case 8:  tpchan = YYY
                case 9:  tpchan = 0 // L pan
                case 10: tpchan = 255 // R pan
                case 11: tpchan = 128 // N/A mode: center!
                default: tpchan = 128 // error? center!
                }
            
        }//perc
        nchan = tnchan
        pchan = tpchan
        vchan = tvchan
        schan = tschan
//        if(0)  NSLog(@" voice[%d] type %d nvmode %d %d ,n/v/p/schan %d %d %d %d,midinote %d",
//        which,vt,Voices[which].noteMode,
//        Voices[which].volMode,Voices[which].nchan,
//        Voices[which].vchan,Voices[which].pchan,Voices[which].schan,
//        Voices[which].midiNote);
    } //end setInputColor
        //-----------(oogieVoice)=============================================
    func loadPercPatch (voice:Int,which:Int)
    {

    } //end OVloadPercPatch
    

    //-----------(oogieVoice)=============================================
    func saveColors()
    {
        lnchan = nchan
        lpchan = pchan
        lvchan = vchan
        lschan = schan
    }

    
    
    //-----------(oogieVoice)=============================================
    func loadSynthPatch (voice:Int,which:Int)
    {
        //  FOR NOW JUST RANDOMMIZE  if which == 0 //randomizer
        if true
        {
            OOP.attack      = Double.random(in:0.0...69.5);
            OOP.decay       = Double.random(in:0.0...69.5);
            OOP.sustain     = Double.random(in:0.0...89.5);
            OOP.sLevel      = Double.random(in:0.0...99.5);
            OOP.release     = Double.random(in:0.0...79.5);
            OOP.duty        = Double.random(in:0...99.5);
         //No need?    OOP.level       = Double.random(in:0.3...0.7);
            OOP.wave        = Int.random(in:0...5);
            //MIDI keyboard range for outgoing notes
            OVS.bottomMidi  = 12;  // 2/28 redo top/bottom MIDI
            OVS.topMidi     = 108; // 2/28 redo
            OVS.keySig      = Int.random(in:0...12); //Randomize key signature too!
            OVS.panMode     = Int.random(in:0...12); //Pan MODE
            //panlr       = Double.random(0.0...1.0);  //Actual pan
            OVS.thresh      = Int.random(in:1...15);        //    perc threshold for soundoff
            OVS.detune      = 1; // STICK TO DETUNED!
            OVS.poly = 0;
            if Int.random(in:0...5) < 2 {OVS.poly = 1}
            //TBD?
            //cursorType = SYNTH_CURSOR //TBD??
        } //end which == 0
        else //Canned
        {
            //TBD?
            //if which < 9) {cursorType = SYNTH_CURSOR}
            //else {cursorType = SAMPLE_CURSOR}

        }

        OVS.noteMode = 3
        OVS.volMode = 4
        OOP.type = Int(SYNTH_VOICE)
        //portamento = 0
    } //end loadSynthPatch
    
    
}

