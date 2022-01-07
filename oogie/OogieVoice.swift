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
//  8/11/21 MODIFY OVStruct, add performance controls portamento, etc...
//  9/1   add loadRandomPercKitPatch, etc
//  9/15  redid all param ranges to accommodate slider range 0..1
//  9/16  add FX params to getParam
//  9/18  add oogieVoiceParams singleton
//  10/8  synth waves now stored in buffers 0..4
//  10/12 move lastBeatTime to top ,add verbose arg to playColors
//  10/20 add inScalars
//  10/25 add xtraParam support
//  10/27 playColors returns last note now
//  11/10 add quant , getQuantTime
//  11/29 allow black colors in setInputColor
//  12/13 remove get/set PatchParam, etc, moved to oogiePatch
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

let halfpi = .pi / 2.0
let twopi  = .pi * 2.0

let MAX_CBOX_FRAMES = 20 //11/18 for playColors support 



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



// 8/12/21 make accessible in objective C
@objc class OogieVoice: NSObject, NSCopying {

    var OOP  = OogiePatch() //this is a struct
    var OVS  = OVStruct()   //  another struct
    var allP = AllPatches.sharedInstance
    var OVP  =  OogieVoiceParams.sharedInstance //9/18/21 oogie voice params
    var OPaP =  OogiePatchParams.sharedInstance //9/28
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
    
    var masterPitch = 0 // 11/21
    var masterTune  = 0 // 11/21
    var masterTempo = 135 // 11/21
    var quantTime = 0   //DHS 11/18
    
    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()
    
    var inPipes   = Set<String>()    //1/22 use insert and remove to manage...
    var outPipes  = Set<String>()   //1/22 use insert and remove to manage...
    var inScalars = Set<String>()    //10/20 new for scalars

    var lastbeatTime = Date() //10/12 moved up from below
    var birthTime    = Date() //11/10 for quant

    var audio3d = "normal" //10/25 for 3d audio placement,
    
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
        masterPitch   = 0
        lastbeatTime  = Date() //10/12 timetag voice
    }
    
    //-----------(oogieVoice)=============================================
    func copy(with zone: NSZone? = nil) -> Any {
        let copy       = OogieVoice()
        //Only copy editable/savable/ID items, dont worry about most working vars
        copy.OVS       = OVS
        copy.OOP       = OOP
        copy.inPipes   = inPipes
        copy.outPipes  = outPipes
        copy.inScalars = inScalars //10/20
        copy.uid       = uid
        //Performance vars that NEED copying
        copy.muted     = muted
        return copy
    }
    
    
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
        //lasta = a
        if newBeat != beat
        {
            let beatTime = Date()
            //let beatDelta = beatTime.timeIntervalSince(lastbeatTime)
            //NSLog("...newbeat %d tdelta %f adelta %f",newBeat,beatDelta,a - lastba)
            beat = newBeat
            lastbeatTime = beatTime
            //lastba = a
            return true
        }
        return false
    } //end getBeat
    
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
// 9/13/21 comment out to silence warning!
//        if voiceParamsDictionary == nil    //5/9 saw crash here! WTF
//        {
//            print("getNthParams ERROR: nil params!")
//            return [""]
//        }
        if n < 0 || n >= OVP.voiceParamsDictionaryOLD.count {return []} //9/18/21
        let key =  String(format: "%02d", n)
        return OVP.voiceParamsDictionaryOLD[key]!
    }

    //-----------(oogieVoice)=============================================
    // 9/14/21 new
    func getNamedParams(name : String) -> [Any]
    {
        //exists? Great!
        if let vpd = OVP.voiceParamsDictionary[name]  { return vpd }//9/18/21
        //otherwise return generic FX 0..100 params
        return OVP.fx100Params
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
        for pn in OVP.voiceParamNames     //9/18/21
        {
            if pn.lowercased() == name
            { found = true ; break }
            iindex+=1
        }
        if found // find param name
        {
            if let paramz = OVP.voiceParamsDictionary[name]       //  use name to get param lims
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
    func getShapeColor(shape:OogieShape) -> (R:Int , G:Int , B:Int , A:Int)
    {
        let aoff = halfpi  //1/7/22 use canned .pi vars
        //get radian angle from shape...
        let angle = shape.angle
        // 11/3 fix math error in xpercent!
        var xpercent = (angle + aoff - OVS.xCoord) / twopi  //11/29 apply xcoord B4 dividing!
        //print("get ShapeColor:shape angle \(angle) initial xper \(xpercent)")
        xpercent = -1.0 * xpercent                     //  and flip X direction
        //Keep us in range 0..1
        while xpercent > 1.0 {xpercent = xpercent - 1.0}
        while xpercent < 0.0 {xpercent = xpercent + 1.0}
        let ypercent = 1.0 - ((OVS.yCoord + halfpi) / .pi)    //1/7/22 use canned .pi vars
        let bmpX = Int(Double(shape.bmp.wid) * xpercent)
        let bmpY = Int(Double(shape.bmp.hit) * ypercent) //9/15 redo!
        let cp = CGPoint(x: bmpX, y: bmpY)
        //print(" get ShapeColor:  xy% \(Int(100.0*xpercent)),\(Int(100.0*ypercent)) cp \(cp) bwid\(shape.bmp.wid)")
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
        for pname in OVP.voiceParamNames      //9/18/21
        {
            let pTuple = getParam(named : pname.lowercased())
            s = s + String(format: "%@:%@\n",pname,pTuple.sParam)
        }
        // 10/12 wups! add more params
        s = s + String(format: "%@:%@\n","shapekey",OVS.shapeKey)
        s = s + String(format: "inPipes   %@\n",inPipes) //10/21 add more info
        s = s + String(format: "outPipes  %@\n",outPipes)
        s = s + String(format: "inScalars %@\n",inScalars)
        s = s + String(format: "UID:%@\n",OVS.uid)
        return s
    }
    
    //-----------(oogieVoice)=============================================
    func getParamList() -> [String]
    {
        if !paramListDirty {return paramList} //get old list if no new params
        paramList.removeAll()
        for pname in OVP.voiceParamNames
        {
            let pTuple = getParam(named : pname.lowercased())
            paramList.append(pTuple.sParam)  
        }
        paramListDirty = false
        return paramList
    } //end getParamList

    //-----------(oogieVoice)=============================================
    // 9/17/21 pack up defaults for UI use
    // OBSOLETE....
    func getDefaultsDict() -> Dictionary<String,Any>
    {
        var d = Dictionary<String, Any>()
        for pname in OVP.voiceParamNames //look at all params... 9/18/21
        {
            let plow = pname.lowercased()
            var pdefault : NSNumber = 0
            if let params = OVP.voiceParamsDictionary[plow]
            {
                let ptype = params[1] as! String
                if ptype == "double" //sliders have params in their arrays
                {
                    let dd = params[4] as! Double
                    pdefault = NSNumber.init(value:dd)
                }
            }
            d[plow] = pdefault
        }
        return d
    } //end getDefaultsDict

    //-----------(oogieVoice)=============================================
    // 9/17 redo
    // how about packing arrays with value: (paramarray contents)??
    func getParamDictWith(soundPack:String) -> Dictionary<String,Any>
    {
        var d = Dictionary<String, Any>()
        d["soundpack"] = ["soundpack" , soundPack]
        for pname in OVP.voiceParamNames //look at all params... 9/18/21
        {
            //print("pack param \(pname)")
            let plow = pname.lowercased()
            let pTuple = getParam(named : plow)
            let sv = pTuple.sParam
            var dv = pTuple.dParam as Double
            if let paramz = OVP.voiceParamsDictionary[plow]  //get param info...
            {
                var workArray = paramz  //copy
                if let ptype = paramz[1] as? String
                {
                    if ptype == "double"  //double type? do some conversion
                    {
                        let lolim  = paramz[6] as! Double
                        let lrange = paramz[5] as! Double
                        if lrange != 0.0 //9/16 DO not apply range shift to int params!
                        {
                            dv = (dv - lolim) / lrange
                        }
                        workArray.append(NSNumber(value:dv))
                    } //end double/int type
                    else if ptype == "int"     //9/16 int type? no conversion
                    {
                        workArray.append(NSNumber(value:dv))
                    }
                    else //string?
                    {
                        workArray.append(sv)
                    }
                }  //end let ptype
                //d[plow] = NSNumber(value:dv)
                d[plow] = workArray

            } //end let paramz
        } //end for pname
        return d
    } //end getParamDictWith
    
    //-----------(oogieVoice)=============================================
    //TEMP, improve this!
    func getPatchDictWithValues() -> Dictionary<String,Any>
    {
        var pdict = Dictionary<String, Double>()
        // make a dictionary of params just like for shapes and pipes here!!!
        //   add it to voice object?
        //OUCH! we have to send a swift class to an ObjectiveC UI!
        pdict["type"] = Double(OOP.type)
        pdict["wave"] = Double(OOP.wave)
        pdict["poly"] = Double(OVS.poly)
        pdict["attack"] = OOP.attack
        pdict["decay"] = OOP.decay
        pdict["sustain"] = OOP.sustain
        pdict["release"] = OOP.release
        pdict["slevel"] = OOP.sLevel
        pdict["duty"] = OOP.duty
        pdict["nchan"] = Double(nchan)
        pdict["vchan"] = Double(vchan)
        pdict["pchan"] = Double(pchan)
        pdict["sampoffset"] = Double(OVS.sampleOffset)
        pdict["volmode"] = Double(OVS.volMode)
        pdict["notemode"] = Double(OVS.volMode)
        pdict["pan"] = Double(OVS.panMode)
        if OOP.type == PERCKIT_VOICE //pack percKit?
        {
            for i in 0...7
            {
                var pkey = "percloox" + String(i)
                pdict[pkey] = Double(OOP.percLoox[i]);
                pkey = "perclooxpans"
                pdict[pkey] = Double(OOP.percLooxPans[i]);
            }
        }
        return pdict
    } //end getPatchDictWithValues
    
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
        //  12/3 OLD          self.OVScene.OSC = try DataManager.loadScene("pipey", with: OSCStruct.self)
        do{  //12/3 add try/catch to all datamanager loads
            OVS = try DataManager.loadVoice(name, with: OVStruct.self)
        }
        catch{
            print("failure loading voice!");
        }

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
        //print("OVsetParam \(name) -> \(dval)  \(sval)")

        switch (name)
        {
        case "name"         : OVS.name    = sval
        case "comment"      : OVS.comment = sval
        case "latitude"     : OVS.yCoord  = dval
        case "longitude"    : OVS.xCoord  = dval
        case "patch"        : OVS.patchName = sval
        case "type"         : break
        case "scale"        : OVS.keySig     = ival
        case "keysig"       : OVS.keySig     = ival //9/15/21
        case "chromatickey" : OVS.pitchShift = ival //5/14
        case "level"        : OVS.level      = dval
        case "overdrive"    : OVS.level      = dval //9/15/21
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
        case "audio3d"       : audio3d          = sval  //10/25
        case "quant"         : OVS.quant        = ival

        default:
            print("Error:Bad voice param in set:" + name)   //5/9
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
        case "keysig":      dp = Double(OVS.keySig) //9/16/21
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
        //9/16/21 performance params
        case "portamento":   dp = Double(OVS.portamento)
        case "viblevel":     dp = Double(OVS.vibLevel)
        case "vibspeed":     dp = Double(OVS.vibSpeed)
        case "vibwave":      dp = Double(OVS.vibWave)
        case "vibelevel":    dp = Double(OVS.vibeLevel)
        case "vibespeed":    dp = Double(OVS.vibeSpeed)
        case "vibewave":     dp = Double(OVS.vibeWave)
        case "delaytime":    dp = Double(OVS.delayTime)
        case "delaysustain": dp = Double(OVS.delaySustain)
        case "delaymix":     dp = Double(OVS.delayMix)
        case "audio3d":      sp = audio3d    //10/25
        case "quant":        dp = Double(OVS.quant)
        default:print("Error:Bad voice param in get:" + name)  //5/9
        }
        if !isString  {sp = String(format: "%4.2f", dp)} //4/25 pack double as string
        return(name , dp , sp) //pack up name,double,string
    } //end getParam

    //-----------(oogieVoice)=============================================
    // future-proof? packs some vars into xtraParams as a string
    //  call right before save to file
    func packXtraParams()
    {
        var s = ""
        s = s + String(format: "audio3d:%@",audio3d)
        OVS.xtraParams = s //all done? save
    } //end packXtraParams
    
    //-----------(oogieVoice)=============================================
    // future-proof? takes xtraParams in as a string, parses parsms from it
    // call right after load from file
    func unpackXtraParams()
    {
        let xss = OVS.xtraParams.split(separator: ",") //split into pairs...
        if xss.count > 0
        {
            for spair in xss // get pairs
            {
                let onePair = spair.split(separator: ",") //peel off pairs...
                if onePair.count == 2
                {
                    let sl = String(onePair[0])
                    let sr = String(onePair[1])
                    switch(sl) //lets look at our lh names...
                    {
                    case "audio3d":  audio3d = sr
                    default: print(" error...bad xtra param \(sl)")
                    }
                }
            } //end for spair
        } //end xss.count
    } //end unpackXtraParams
    
    //-----------(oogieVoice)=============================================
    //11/10 returns ms time to next quantize step time
    // NOTE birth time must be reset if tempo changes!
    func getQuantTime(q:Int) -> Int
    {
        var qtime = 0
        //first do some math... get time per beat
        let lookups = [1,2,4,8,16,32,64,128,256] //last 2 never get used?
        if q > 0
        {
            let qexp = lookups[q-1]
            let timePerBeat = (240.0 / Double(qexp)) / Double(masterTempo)
            //get time now
            let now = Date()
            let interval = now.timeIntervalSince(birthTime) //overall time since birth
            let beats = Int(interval / timePerBeat)  //# beats
            
            //let lilt = interval - (Double(beats) * timePerBeat) //do i even need this?
            //let lilt  = interval % timePerBeat   // time into beat
            qtime = Int(1000.0 * ( ( Double(beats+1) * timePerBeat ) - interval ) )//get ms to next quant step
            //print(".........................................interval \(interval) beats \(beats)  qtime \(qtime)")
        }
        
        return qtime
    }
    
    //-----------(oogieVoice)=============================================
    // 11/18 move in from mainvC. heavy lifter, lots of crap brought together
    //  needs masterPitch. should it be an arg or class member?
    //  4/19 add angle arg
    func playColors(angle : Double, rr : Int ,gg : Int ,bb : Int, verbose : Bool) -> Int
    {
        var inkeyNote = 0
        var noteToPlay = 0
        //this sets midiNote!
        setInputColor(chr: rr, chg: gg, chb: bb)
        bufferPointer = 0;
        if OOP.type == PERCUSSION_VOICE || OOP.type == SAMPLE_VOICE
        {
            //9/11 use sample num from voice... for perc/samples now
            bufferPointer = OVS.whichSamp
        }
        if verbose { print("....playColors:NOTE:\(midiNote) NPV:\(nchan) \(pchan) \(vchan)  ... RGB ( \(rr),\(gg),\(bb) )") }
        //print("....playColors:NOTE:\(midiNote) type:\(OOP.type) uid:\(uid)  n:lnchan \(nchan) : \(lnchan)")
        let vt    = OOP.type
        if midiNote > 0  || OVS.rotTrigger != 0  //Play something?
        {
            (sfx() as! soundFX).setSynthMIDI(Int32(OVS.midiDevice), Int32(OVS.midiChannel)) //chan: 0-16
            let nc = (sfx() as! soundFX).getSynthNoteCount()
            //inkeyOldNote = oldNote
            // 5/14 add pitch shift
            inkeyNote    = masterPitch + OVS.pitchShift + Int((sfx() as! soundFX).makeSureNoteis(inKey: Int32(OVS.keySig),Int32(midiNote)))
            // Mono: Handle releasing old note...
            // 8/14 NO NEED?            if OVS.poly == 1 {(sfx() as! soundFX).releaseNote(Int32(inkeyOldNote),0)} //2nd arg, WTF??
            //TBD....[synth setTimetrax:OVgettimetrax(vloop)];
            //New note outside tolerance?
            
            var mono = 1
            if OVS.poly != 0 { mono = 0 }
            
            //4/19 add check for beats as needed:
            var gotTriggered = false
            if OVS.rotTrigger == 0 //Use colors as trigger?
            {
                gotTriggered = (abs (nchan - lnchan) > OVS.thresh) && nc < 12 //5/2
                if (nc >= 20){ print("   ...SYNTH notecount \(nc)") }
                //print("...triggered \(gotTriggered) n:lnchan \(nchan) : \(lnchan) thresh \(OVS.thresh) ")
            }
            else //use beats trigger?
            {
                //print("beats key \(OVS.key) angle \(angle)")
                gotTriggered = getBeat(a: angle) //uses angle from shape
            }
            //if (abs (nchan - lnchan) > 2*OVS.thresh) && nc < 12
            if gotTriggered // 4/19
            {
                if verbose { print("..t \(midiNote)") }
                //print(" toler check: nchan \(nchan) lnchan \(lnchan) nc \(nc) thresh \(OVS.thresh)",nchan,lnchan,nc )
                //11/10 handle quantize...
                quantTime = 0
                if OVS.quant != 0 //1/10 add quant interval
                {
                    quantTime = getQuantTime(q: OVS.quant)
                }
                
                
                //print(" playnote type:\(vt)  whichsamp:\(OVS.whichSamp) id:\(OVS.uid)");
                (sfx() as! soundFX).setSynthMono(Int32(mono))
                (sfx() as! soundFX).setSynthMonoUN(Int32(uniqueCount))
                if vt == SYNTH_VOICE
                {
                    if OOP.wave == 3   //10/8 rebuild wave for squares ONLY
                    {
                        // 10/8/21 cant get WAVE_SQUARE to work here, WTF?
                        (sfx() as! soundFX).buildaWaveTable(3, 3)
                    }
                }
                (sfx() as! soundFX).setSynthAttack(Int32(OOP.attack))
                //print("....playColors:attack \(OOP.attack)")
                (sfx() as! soundFX).setSynthDecay(Int32(OOP.decay))
                (sfx() as! soundFX).setSynthSustain(Int32(OOP.sustain))
                (sfx() as! soundFX).setSynthSustainL(Int32(OOP.sLevel))
                (sfx() as! soundFX).setSynthRelease(Int32(OOP.release))
                // 10/8 NO NEED?             (sfx() as! soundFX).buildEnvelope(0,true)
                (sfx() as! soundFX).setSynthPortamento(Int32(OVS.portamento))
                (sfx() as! soundFX).setSynthVibAmpl(Int32(OVS.vibLevel))
                (sfx() as! soundFX).setSynthVibSpeed(Int32(OVS.vibSpeed))
                (sfx() as! soundFX).setSynthVibWave(Int32(OVS.vibWave))
                (sfx() as! soundFX).setSynthVibeAmpl(Int32(OVS.vibeLevel))
                (sfx() as! soundFX).setSynthVibeSpeed(Int32(OVS.vibeSpeed))
                (sfx() as! soundFX).setSynthVibeWave(Int32(OVS.vibeWave))
                (sfx() as! soundFX).setSynthInfinite(0) //11/2/21 just in case
                
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
                
                var bptr = 0
                //-------SYNTH: built-in canned wave samples--------------------------
                if vt == SYNTH_VOICE
                {
                    bptr = OOP.wave //10/8 synth waves use bufs 0..4
                    lastgain = Int(Double(vchan) * 0.7 * OVS.level) // 8/11 for delay
                    lastbuf  = bptr
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
                    //print("play synth buf \(bptr) note \(noteToPlay)")
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt))
                        if verbose { print("                                                                          ..synthNote bptr[\(bptr)]:\(noteToPlay)") }
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(noteToPlay) , Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
                    lastnoteplayed = inkeyNote
                    applyDelayIfAny() //8/11/21
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
                        if verbose { print(" ...sampleNote bptr[\(bptr)]:\(inkeyNote)") }
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(inkeyNote), Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
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
                        if verbose { print(" ...percussionNote bptr[\(bptr)]:\(noteToPlay)") }
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(noteToPlay) , Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
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
                    bptr = bufferPointerSet[octave]
                    lastbuf  = bptr //8/11 for delay
                    lasttype = PERCKIT_VOICE
                    
                    let pkPan = OOP.percLooxPans[octave]
                    //print("pkbuf \(bptr) pkpan[\(octave)] = \(pkPan)")
                    (sfx() as! soundFX).setSynthPan(Int32(pkPan))
                    noteToPlay = 32
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt)) //Play Middle C for now...
                        if verbose { print(" ...percKitNote bptr[\(bptr)]:\(noteToPlay)") }
                    }
                    else
                    {
                        (sfx() as! soundFX).playNote(withDelay: Int32(noteToPlay) , Int32(bptr) ,Int32(vt),Int32(quantTime))
                    }
                } //end perckit block
                uniqueCount = Int((sfx() as! soundFX).getSynthUniqueCount())
                hiLiteFrame = MAX_CBOX_FRAMES
                oldNote     = nchan
                saveColors()
                addToDebugHistory(n:noteToPlay) //4/19 add debug tracker
            } //end abs toler check
        } //end midinote...
        //DHS 11/29 testo
//        else  //11/20 zer0 note? clear old note too
//        {
//            lnchan = 0
//        }
        return noteToPlay
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
            print(" ..delay \(workTime) note \(lastnoteplayed)  buf \(lastbuf) gain \(gain)")
            (sfx() as! soundFX).playNote(withDelay:  Int32(lastnoteplayed) , Int32(lastbuf) ,Int32(lasttype),Int32(workTime))
            workTime+=timeMS;
        } // end while

    } //end applyDelayIfAny

    //=====<oogie2D mainVC>====================================================
    // 10/1 new, for applying patch edits to this voice
    func applyEditsWith(dict : Dictionary< AnyHashable, Any> )
    {
        for (key,value) in dict
        {
            if let pname = key as? String
            {
                var ppname = pname //work var...
                //print("pname \(pname) ") //look for percloox_0... etc
                let a = pname.split(separator: "_")
                if a.count > 1
                {
                    ppname = String(a[0]) //keep first part
                }
                if let ssn = value as? String //wow lots of crap just to unpack 2 items!
                {
                    if let vArray = OPaP.patchParamsDictionary[ppname] //get param info array
                    {
                        var dd : Double = 0.0
                        let ptype = vArray[1] as! String
                        if ptype == "double" && vArray.count > 6
                        {
                            if let dtemp = Double(ssn)
                            {
                                let dmult = vArray[5] as! Double
                                let doff  = vArray[6] as! Double
                                dd = (dtemp * dmult) + doff //convert to full parameter value
                            }
                        }
                        else if ptype == "string"    //try to get an integer value just in case...
                        {
                            if let dtemp = Double(ssn)
                            {
                                dd = dtemp
                            }
                        }
                        //Finally! now set the patch param to reflect edit...
                        //print(" apply edit to \(pname) value \(dd)")
                        OOP.setParam(named: pname, toDouble: dd, toString: ssn) //12/13 change patch get/set
                    }
                } //end let ssn
           } //end let pname
        } //end for key
    } //end applyEditsWith

    
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
        return OVP.voiceParamNames.count   // 2/5 WTF? BUG!!!  9/18/21
    }

    //-----------(oogieVoice)=============================================
    //10/15 relies heavily on structure members in this class
    // 9/1/21 redid for new voice structs
    func getPercLooxBufferPointerSet()
    {
        bufferPointerSet.removeAll() //clear array...
        for pName in OOP.percLoox   //loop over lookup perc names...
        {   //and add approp. buffer pointers to pointer set
            
            let nn = allP.getSampleNumberByName(ss: pName)
            bufferPointerSet.append(nn.intValue); //10/26 wups
            //Int((sfx() as! soundFX)getPercussionBuffer(pName.lowercased())))
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
        //let pf     = 0.0
//11/29 test: allow black as a note
//        if (chr==0) && (chg==0) && (chb==0) //black means no sound/note/center pan
//        {
//            nchan = 0
//            pchan = 128
//            vchan = 0
//            midiNote = 0
//            return
//        }
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
    func saveColors()
    {
        lnchan = nchan
        lpchan = pchan
        lvchan = vchan
        lschan = schan
    }
    
    //-----------(oogieVoice)=============================================
    // 9/1 new, note buffer lo/hi limits!
    func loadRandomPercPatch(builtinBase:Int , builtinMax : Int)
    {
        OOP.attack     = 0;
        OOP.decay      = 0;
        OOP.sustain    = 0;
        OOP.sLevel     = 0;
        OOP.release    = 0;
        OOP.wave       = 0;
        OOP.duty       = 0;
        OVS.sampleOffset = Int.random(in:0...30);
        OVS.whichSamp    = Int.random(in:builtinBase...builtinMax)
        //print("rand perc buffer \(OVS.whichSamp)")
        OVS.panMode      = Int.random(in:0...11);
        OVS.panFixed     = Int.random(in:0...255);
        OVS.detune       = Int(Double.random(in:0...1.5)); // 9/1 copy from oogiecam
        OVS.poly = 1;
        if Double.random(in:0...4.0) < 1.5 {OVS.poly = 0}
    } //end loadRandomPercPatch
    
    //-----------(oogieVoice)=============================================
    // 9/1 new, note buffer lo/hi limits!
    func loadRandomPercKitPatch(builtinBase:Int , builtinMax : Int)
    {
        OOP.attack     = 0;
        OOP.decay      = 0;
        OOP.sustain    = 0;
        OOP.sLevel     = 0;
        OOP.release    = 0;
        OOP.wave       = 0;
        OOP.duty       = 0;
        OVS.sampleOffset = Int.random(in:0...30);
        OVS.whichSamp    = Int.random(in:builtinBase...builtinMax)
        OVS.panMode      = Int.random(in:0...11);
        OVS.panFixed     = Int.random(in:0...255);
        OVS.detune       = 0; // no detune!
        OVS.poly         = 1;
        if Double.random(in:0...4.0) < 1.5 {OVS.poly = 0}
        
        for loop in 0...7
        {
            let bptr = Int.random(in:builtinBase...builtinMax)
            //10/27 slow as fuck, find proper loaded sample name for bptr...
            let d = allP.patLookups //  mixed case names!
            var bname = ""
            for (s,n) in d  //get string / number
            {
                if n.intValue == bptr {bname = s;break}
            }
            
            
//            if let bname = allP.bufLookups[NSNumber(value: bptr)]
//            {
                OOP.percLoox[loop]     = bname
                OOP.percLooxPans[loop] = Int.random(in: 0...255);
//            }
        }
    } //end loadRandomPercKitPatch
    
    //-----------(oogieVoice)=============================================
    // 9/1 new, note buffer lo/hi limits!
    func loadRandomSamplePatch(builtinBase:Int , builtinMax : Int , purchasedBase:Int , purchasedMax : Int)
    {
        OOP.attack     = 0;
        OOP.decay      = 0;
        OOP.sustain    = 0;
        OOP.sLevel     = 0;
        OOP.release    = 0;
        OOP.wave       = 0;
        OOP.duty       = 0;
        
        OVS.keySig     = Int.random(in:0...12);

        OVS.sampleOffset = Int.random(in:0...30);
        OVS.panMode      = Int.random(in:0...11);
        OVS.panFixed     = Int.random(in:0...255);
        OVS.detune       = Int(Double.random(in:0...1.5)); // 9/1 copy from oogiecam
        OVS.poly = 1;
        if Double.random(in:0...4.0) < 1.5 {OVS.poly = 0}
        var which = Int.random(in:0...10);
        if purchasedBase == 0  { which = 0 } //nothing purchased? always builtins!
        if which < 5 //look at builtins
        {
            OVS.whichSamp    = Int.random(in:builtinBase...builtinMax)
        }
        else //purchased?
        {
            OVS.whichSamp    = Int.random(in:purchasedBase...purchasedMax)
        }
    } //end loadRandomPercPatch
    
    //-----------(oogieVoice)=============================================
    // 9/1/21 redid, no args now...
    func loadRandomSynthPatch()
    {
        OOP.attack      = Double.random(in:0.0...69.5);
        OOP.decay       = Double.random(in:0.0...69.5);
        OOP.sustain     = Double.random(in:0.0...89.5);
        OOP.sLevel      = Double.random(in:0.0...99.5);
        OOP.release     = Double.random(in:0.0...79.5);
        OOP.duty        = Double.random(in:0...99.5);
        //No need?    OOP.level       = Double.random(in:0.3...0.7);
        OOP.wave        = Int.random(in:0...4); //10/27 wups
        //MIDI keyboard range for outgoing notes
        OVS.bottomMidi  = 12;  // 2/28 redo top/bottom MIDI
        OVS.topMidi     = 108; // 2/28 redo
        OVS.keySig      = Int.random(in:0...12); //Randomize key signature too!
        OVS.panMode     = Int.random(in:0...12); //Pan MODE
        OVS.panMode     = Int.random(in:0...11);
        OVS.panFixed    = Int.random(in:0...255);
        OVS.thresh      = Int.random(in:1...15);        //    perc threshold for soundoff
        OVS.detune      = Int(Double.random(in:0...1.5)); // 9/1 copy from oogiecam
        OVS.poly = 1;
        if Double.random(in:0...4.0) < 1.5 {OVS.poly = 0}
    } //end loadRandomSynthPatch
    
    
}

