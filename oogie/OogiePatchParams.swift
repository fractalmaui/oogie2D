//
//                     _      ____       _       _     ____
//    ___   ___   __ _(_) ___|  _ \ __ _| |_ ___| |__ |  _ \ __ _ _ __ __ _ _ __ ___  ___
//   / _ \ / _ \ / _` | |/ _ \ |_) / _` | __/ __| '_ \| |_) / _` | '__/ _` | '_ ` _ \/ __|
//  | (_) | (_) | (_| | |  __/  __/ (_| | || (__| | | |  __/ (_| | | | (_| | | | | | \__ \
//   \___/ \___/ \__, |_|\___|_|   \__,_|\__\___|_| |_|_|   \__,_|_|  \__,_|_| |_| |_|___/
//               |___/
//
//  OogiePatchParams.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/28/21
//  Params for oogiePatch objects. singleton, created once
//
import Foundation

@objc class OogiePatchParams: NSObject {

    static let sharedInstance = OogiePatchParams()

    //Parameter area...
    //Params: Name,Type,Min,Max,Default,DisplayMult,DisplayOffset?? (string params need a list of items)
    let PNameParams     : [Any]   = ["Name",      "text", "mt"]
    // No plan to change type right now...
    let PTypeParams     : [Any] = ["Type","string" , "Synth", "Sample", "Percussion", "PercKit", "Harmony", "Combo"]
    let PWaveParams     : [Any] = ["Wave","string" , "Sine", "Saw", "Square", "Ramp", "Noise"]
    let AttackParams    : [Any] = ["Attack" ,     "double", 0.0   , 255.0   , 2.0, 255.0, 0.0 ]
    let DecayParams     : [Any] = ["Decay" ,      "double", 0.0   , 255.0   , 0.0, 255.0, 0.0 ]
    let SustainParams   : [Any] = ["Sustain" ,    "double", 0.0   , 255.0   , 3.0, 255.0, 0.0 ]
    let SLevelParams    : [Any] = ["SLevel" ,     "double", 0.0   , 255.0   , 0.0, 255.0, 0.0 ]
    let ReleaseParams   : [Any] = ["Release" ,    "double", 0.0   , 255.0   , 40.0, 255.0, 0.0 ]
    let DutyParams      : [Any] = ["Duty" ,       "double", 0.0   , 100.0   , 50.0, 100.0, 0.0 ]
    // NOTE this is in percent!
    let SampOffParams   : [Any] = ["SampleOffset" ,  "double", 0.0   , 100.0   , 0.0, 100.0, 0.0 ]

    let PKeyDetuneParams : [Any] = ["PKeyDetune" ,   "double", 0.0   , 100.0   , 50.0, 100.0, 0.0 ]
    let PKeyOffsetParams : [Any] = ["PKeyOffset" ,   "double", 0.0   , 100.0   , 50.0, 100.0, 0.0 ]
    let PPLevelParams    : [Any] = ["PLevel" ,       "double", 0.0   , 100.0   , 50.0, 100.0, 0.0 ]
    //These two are used to setup 8 sliders / choosers
    let PPercLooxParams    : [Any] = ["percLoox" ,   "string", "" ]
    let PPercLooxPanParams : [Any] = ["percLooxPans" ,   "double", 0.0   , 255.0   , 0.0, 255.0, 0.0 ]

    let patchParamNames : [String]    = ["Name", "Type","Wave","Attack",
                                 "Decay","Sustain","SLevel","Release",
                                 "Duty","SampleOffset","PKeyDetune","PKeyOffset","PLevel",
                                 "PercLoox","PercLooxPans"
    ]

    var patchParamsDictionary = Dictionary<String, [Any]>()
    
    //-----------(OogiePatchParams)=============================================
    override init() {
        super.init()
        setuppatchParams() //load a dictionary, set up any other structs
    }
    
    //-----------(OogiePatchParams)=============================================
    // 10/2 redo to handle percloox_0..7 etc
    func getParamType(pname:String) -> String
    {
        var ppname = pname
        let a = pname.split(separator: "_")  //handle percloox_0...7 items...
        if a.count > 1 //got more than 1 part? just keep first part
        {
            ppname = String(a[0])
        }
        //quick check for param type
        if let params = patchParamsDictionary[ppname]
        {
            let ptype  = params[1] as! String
            return ptype
        }
        return ""
    } //end getParamType

    //-----------(OogiePatchParams)=============================================
    func getParamChoices(pname:String) -> [String]
    {
        if var params = patchParamsDictionary[pname]
        {
            params.remove(at: 0)
            params.remove(at: 0)
            var a : [String] = []
            for nextchoice in params
            {
                if let ss = nextchoice as? String
                {
                    a.append(ss)
                }
            }
            return a
        }
        return []
    } //end getParamChoices

    
    //-----------(OogiePatchParams)=============================================
    func setuppatchParams()
    {
        // Load up params dictionary with string / array combos
        patchParamsDictionary["name"]         = PNameParams
        patchParamsDictionary["type"]         = PTypeParams
        patchParamsDictionary["wave"]         = PWaveParams
        patchParamsDictionary["attack"]       = AttackParams
        patchParamsDictionary["decay"]        = DecayParams
        patchParamsDictionary["sustain"]      = SustainParams
        patchParamsDictionary["slevel"]       = SLevelParams
        patchParamsDictionary["release"]      = ReleaseParams
        patchParamsDictionary["duty"]         = DutyParams
        patchParamsDictionary["sampleoffset"] = SampOffParams
        patchParamsDictionary["pkeydetune"]   = SampOffParams
        patchParamsDictionary["sampleoffset"] = SampOffParams
        patchParamsDictionary["pkeydetune"]   = PKeyDetuneParams
        patchParamsDictionary["pkeyoffset"]   = PKeyOffsetParams
        patchParamsDictionary["plevel"]       = PPLevelParams
        patchParamsDictionary["percloox"]     = PPercLooxParams
        patchParamsDictionary["perclooxpans"] = PPercLooxPanParams
    } //end setupPatchParams
    
} //end oogiePatchParams class

