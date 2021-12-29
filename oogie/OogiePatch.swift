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
//  11/1 add dumpParams
//  12/13 add getParam , setParam
//  12/20 change from struct to object, add applyEditsWith...
//  12/21 add copy method
import Foundation
@objc class OogiePatch: NSObject,Codable,NSCopying {

    var name         = ""   //12/20 add inits for all class properties
    var type         = 0    //Synth, Sample, PercSet, etc
    var wave         = 0    //Synth wave type: sine, ramp, etc
    var attack       = 0.0  //Envelope generator params, ADSR/SLevel
    var decay        = 0.0
    var sustain      = 0.0
    var sLevel       = 0.0
    var release      = 0.0
    var duty         = 0.0  // duty for square waves only
    var sampleOffset = 0
    var pLevel       = 50
    var pKeyOffset   = 50
    var pKeyDetune   = 50
    var percLoox     : Array<String> = ["mt","mt","mt","mt","mt","mt","mt","mt"]
    var percLooxPans : Array<Int> = [0,1,2,3,4,5,6,7]
    var xtraParams   = "" //11/24 for performance params / futurproofing
    var createdAt      = Date()
    var itemIdentifier = UUID()
     
    //======(OogiePatch)=============================================
    // 12/20
    override init()
    {
        super.init()
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
    //mutating
    func clear()
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
    // 12/21 new
    func copy(with zone: NSZone? = nil) -> Any {
        let copy       = OogiePatch()
        copy.name           = name
        copy.type           = type
        copy.wave           = wave
        copy.attack         = attack
        copy.decay          = decay
        copy.sustain        = sustain
        copy.sLevel         = sLevel
        copy.release        = release
        copy.duty           = duty
        copy.sampleOffset   = sampleOffset
        copy.pLevel         = pLevel
        copy.pKeyOffset     = pKeyOffset
        copy.pKeyDetune     = pKeyDetune //10/20
        copy.percLoox       = percLoox
        copy.percLooxPans   = percLooxPans
        copy.xtraParams     = xtraParams
        copy.createdAt      = createdAt
        copy.itemIdentifier = itemIdentifier
        return copy
    } //end copy

    
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
    // 12/20 moved in from voice, convenience for patchEditor
    func applyEditsWith(dict : Dictionary< AnyHashable, Any> )
    {
        let OPaP =  OogiePatchParams.sharedInstance //12/20

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
                        setParam(named: pname, toDouble: dd, toString: ssn) //12/13 change patch get/set
                    }
                } //end let ssn
           } //end let pname
        } //end for key
    } //end applyEditsWith

    
    //======(OogiePatch)=============================================
    // 12/13 add get/set param funcs independent to patch...
    // 12/20 wups use pname to avoid conflict
    func getParam(named pname : String, pIndex: Int) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = ""
        var isString = false  //do i need this??
        let pptr = min(7,max(0,pIndex)) //legalize perc index...
        switch (pname)  //depending on param, set double or string
        {
        case "name":        sp = name;isString = true
        case "type":        dp = Double(type)
        case "wave":        dp = Double(wave)
        case "attack":      dp = Double(attack)
        case "decay":       dp = Double(decay)
        case "sustain":     dp = Double(sustain)
        case "slevel":      dp = Double(sLevel)
        case "release":     dp = Double(release)
        case "duty":        dp = Double(duty)
        case "sampleoffset":dp = Double(sampleOffset)
        case "pkeydetune":  dp = Double(pKeyDetune)
        case "pkeyoffset":  dp = Double(pKeyOffset)
        case "plevel":      dp = Double(pLevel)
        case "percloox":    sp = percLoox[pptr];isString = true
        case "perclooxpans":dp = Double(percLooxPans[pptr])
        default:print("Error:Bad patch param in get:" + pname)
        }
        if !isString  {sp = String(format: "%4.2f", dp)} // pack double as string
        return(pname , dp , sp) //pack up name,double,string
    } //end getParam

    //======(OogiePatch)=============================================
    // used for floating point and numeric fields ONLY??
    func setUnitParam(named pname : String, toDouble dval: Double)
    {
        //HOW DO I DO THIS?
    }
    
    //======(OogiePatch)=============================================
    // 12/13 new
    func setParam(named pname : String , toDouble dval: Double , toString sval: String)
    {
        let ival = Int(dval) //some params are stored as integers!
        //print("setParam \(name) -> \(dval)  \(sval)")
        switch (pname)  //depending on param, set double or string
        {
        case "name":        name = sval
        case "wave":        wave = ival
        case "type":        type = ival
        case "attack":      attack = dval
        case "decay":       decay = dval
        case "sustain":     sustain = dval
        case "slevel":      sLevel = dval
        case "release":     release = dval
        case "duty":        duty = dval
        case "sampleoffset":sampleOffset = ival
        case "pkeydetune":  pKeyDetune = ival
        case "pkeyoffset":  pKeyOffset = ival
        case "plevel":      pLevel = ival
        case "percloox_0":  percLoox[0] = sval
        case "percloox_1":  percLoox[1] = sval
        case "percloox_2":  percLoox[2] = sval
        case "percloox_3":  percLoox[3] = sval
        case "percloox_4":  percLoox[4] = sval
        case "percloox_5":  percLoox[5] = sval
        case "percloox_6":  percLoox[6] = sval
        case "percloox_7":  percLoox[7] = sval
        case "perclooxpans_0":  percLooxPans[0] = ival
        case "perclooxpans_1":  percLooxPans[1] = ival
        case "perclooxpans_2":  percLooxPans[2] = ival
        case "perclooxpans_3":  percLooxPans[3] = ival
        case "perclooxpans_4":  percLooxPans[4] = ival
        case "perclooxpans_5":  percLooxPans[5] = ival
        case "perclooxpans_6":  percLooxPans[6] = ival
        case "perclooxpans_7":  percLooxPans[7] = ival
        default:print("Error:Bad patch param in set:" + name)
        }
    } //end setParam

    //======(OogiePatch)=============================================
    // 10/13 moved in from oogieVoice
    func getParamDict() -> Dictionary<String,Any>
    {
        let OPaP = OogiePatchParams.sharedInstance //12/13
        var d    = Dictionary<String, Any>()
        for pname in OPaP.patchParamNames //look at all params...
        {
            let plow = pname.lowercased()
            if plow == "percloox" || plow == "perclooxpans" {continue} //bail on percloox for now...
            //print("pack patch param \(pname)")
            let pTuple = getParam(named : plow , pIndex:0) //12/13 changed patch get/set
            let sv = pTuple.sParam
            var dv = pTuple.dParam as Double
            if let paramz = OPaP.patchParamsDictionary[plow]  //get param info...
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
                d[plow] = workArray
            } //end let paramz
        } //end for pname
        ///Now append percloox / perclooxpans
        var pass = 0
        for pplow in [ "percloox" , "perclooxpans" ]
        {
            for i in 0...7
            {
                if var workArray = OPaP.patchParamsDictionary[pplow]  //get param info...
                {
                    let pTuple = getParam(named : pplow , pIndex:i) //12/13 changed patch get/set
                    let dv = pTuple.dParam //double param
                    let sv = pTuple.sParam //string param
                    ///print("pass \(pass) loop \(i)")
                    /// pass 0:percloox is a string, pass 1:pans is a number
                    if pass == 0  { workArray.append(sv) }
                    else          { workArray.append(NSNumber(value:dv/255.0)) } //10/2 pan needs conversion...
                   // print("..........dv \(dv) sv \(sv)")
                    // name = percloox_3   or  perclooxpans_2, etc
                    d[pplow + "_" + String(i)]  = workArray //append digit to param name
                }
            }
            pass = pass + 1
        }
        return d
    } //end getParamDict

    
    //======(OogiePatch)=============================================
    func dump()
    {
        DataManager.dump(self)
    }
    
    //======(OogiePatch)=============================================
    // 11/1 new
    func dumpParams() -> String
    {
        return DataManager.getDumpString(self)
    }
    


}
