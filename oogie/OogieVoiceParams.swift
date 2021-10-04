//    ___              _    __     __    _          ____
//   / _ \  ___   __ _(_) __\ \   / /__ (_) ___ ___|  _ \ __ _ _ __ __ _ _ __ ___  ___
//  | | | |/ _ \ / _` | |/ _ \ \ / / _ \| |/ __/ _ \ |_) / _` | '__/ _` | '_ ` _ \/ __|
//  | |_| | (_) | (_| | |  __/\ V / (_) | | (_|  __/  __/ (_| | | | (_| | | | | | \__ \
//   \___/ \___/ \__, |_|\___| \_/ \___/|_|\___\___|_|   \__,_|_|  \__,_|_| |_| |_|___/
//               |___/
//  oogieVoiceParams.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/19/21.
//  Params for oogieVoice objects. singleton, created once
//  9/28 pulled numeric param dict entries
import Foundation

// 8/12/21 make accessible in objective C
@objc class OogieVoiceParams: NSObject {

    static let sharedInstance = OogieVoiceParams()
    
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
    //Params: Name,Type,Min,Max,Default,DisplayMult,DisplayOffset?? (string params need a list of items)
    // NOTE: .pi has to have a numeric multiplicator / divisor to compile in this statement!
    let LatParams   : [Any] = ["Latitude" ,      "double", -.pi/2.0   , .pi/2.0   , 0.0, 1.0 * .pi, -0.5 * .pi ]
    let LonParams   : [Any] = ["Longitude",      "double", -1.0 * .pi , 1.0 * .pi , 0.0, 2.0 * .pi  ,-1.0 * .pi ]
    // 10/15 NOTE: order here MUST match macro value order in synth!
    let TypeParams  : [Any] = ["Type",           "string" , "Synth", "Percussion", "PercKit", "Sample", "Harmony"]
    let PatchParams : [Any] = ["Patch",          "string","mt"]
    // 5/14 add pitch shift
    let PitchShiftParams : [Any] = ["ChromaticKey","string" , "C", "C#", "D", "D#", "E", "F",
                                                "F#", "G", "G#", "A", "A#", "B"]
    let ScaleParams : [Any] = ["Scale",          "string" ,     //9/19 redo
                               "major" ,"minor" ,"lydian" ,"phrygin" ,
                               "mixolydian" ,"locrian" ,"egyptian","hungarian" ,
                               "algerian","japanese","chinese","chromatic" ]
    let LevelParams    : [Any]   = ["Level" ,    "double", 0.0 , 1.0 , 0.5 , 255.0, 0.0 ]
    //5/2 add thresh
    let ThreshParams : [Any]     = ["Threshold", "double" ,1.0, 255.0 , 5.0  , 100.0,  0.0 ]
    //  10/4 add nvp chan/fixed / midi params
    let NChanParams : [Any]      = ["NChan",     "string" , "Red", "Green", "Blue", "Hue",
                                    "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
    let VChanParams : [Any]      = ["VChan",     "string" , "Red", "Green", "Blue", "Hue",
                                    "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
    let PChanParams : [Any]      = ["PChan",     "string" , "Red", "Green", "Blue", "Hue",
                                    "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
    let NFixedParams : [Any]     = ["NFixed",    "double" ,  16.0, 112.0 , 64.0  , 255.0,  0.0 ] //4/27 redo next 3
    let VFixedParams : [Any]     = ["VFixed",    "double" ,  0.0 , 255.0 , 128.0 , 255.0,  0.0 ]
    let PFixedParams : [Any]     = ["PFixed",    "double" ,  0.0 , 255.0 , 128.0 , 255.0,  0.0 ]
    let RotTriggerParams : [Any] = ["RotTrigger","double" ,  0.0 , 256.0 , 0.0 , 255.0,  0.0 ]
    let DetuneParams : [Any]     = ["Detune",     "string" , "Off", "On"]   //5/9
    // 9/17/21 change top/bottom midi from int to double
    let BottomMidiParams : [Any] = ["BottomMidi","double" ,  16.0 , 112.0 , 32.0 , 100.0,  20.0 ] //9/14/21 change last item
    let TopMidiParams : [Any]    = ["TopMidi",   "double" ,  16.0 , 112.0 , 96.0 , 100.0,  20.0 ]
    let MidiChannelParams: [Any] = ["MidiChannel","int" ,  1.0 ,16.0 , 1.0 , 128.0,  0.0 ]
    let VNameParams    : [Any]   = ["Name",      "text", "mt"]
    let VCommParams    : [Any]   = ["Comment",   "text", "mt"]

    let fx100Params : [Any]     = ["FX",   "double" ,  0.0 , 0.0 , 0.0 , 100.0,  0.0 ] // for f/x sliders
    let fxWaveParamsOLD : [Any]     = ["FXWave",   "int" ,  0.0 , 0.0 , 0.0 , 4.0,  0.0 ] // for wave pickers
    let fxWaveParams : [Any]      = ["FXWave",     "string" , "Sine", "Saw", "Square", "Ramp"]

    // All param names, must match first item above for each param!
    let voiceParamNames : [String]    = ["Latitude", "Longitude","Type","Patch","ChromaticKey",
                                 "Scale","Level","Threshold","KeySig",  // 9/16/21 keysig
                                 "NChan","VChan","PChan",
                                 "NFixed","VFixed","PFixed","RotTrigger","Detune",   // 5/9
                                 "BottomMidi","TopMidi","MidiChannel","Name","Comment",
                                 "Portamento","Viblevel","Vibspeed","VibWave", //9/15/21 add fx
                                 "VibeLevel","VibeSpeed","VibeWave",
                                 "DelayTime" ,"DelaySustain","DelayMix"
    ]
    let voiceParamNamesOKForPipe : [String]    = ["Latitude", "Longitude","ChromaticKey",
                                                "Scale","Level","Threshold","KeySig",   // 9/16/21 keysig
                                                "NChan","VChan","PChan",
                                                "NFixed","VFixed","PFixed","RotTrigger","Detune",   // 5/9
                                                "BottomMidi","TopMidi","MidiChannel",
                                                "Portamento","Viblevel","Vibspeed","vibwave", //9/15/21 add fx
                                                "VibeLevel","VibeSpeed","VibeWave",
                                                "DelayTime" ,"DelaySustain","DelayMix"
    ]

    var voiceParamsDictionary = Dictionary<String, [Any]>()
    var voiceParamsDictionaryOLD = Dictionary<String, [Any]>()
    // 9/23 canned perc kit defaults
    let percDefaults : [String] = ["Bass_Drum_1","Acoustic_Snare","Low_Tom","Low_Mid_Tom",
                                  "High_Tom","Open_Hi_Hat","Closed_Hi_Hat","Ride_Cymbal_1"]


    
    //-----------(oogieVoiceParams)=============================================
    override init() {
        super.init()
        setupVoiceParams() //load a dictionary, set up any other structs
    }
    
    //-----------(oogieVoiceParams)=============================================
    func getParamType(pname:String) -> String
    {
        //quick check for param type
        if let params = voiceParamsDictionary[pname]
        {
            let ptype  = params[1] as! String
            return ptype
        }
        return ""
    }

    //-----------(oogieVoiceParams)=============================================
    func getParamChoices(pname:String) -> [String]
    {
        if var params = voiceParamsDictionary[pname]
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

    
    //-----------(oogieVoiceParams)=============================================
    func setupVoiceParams()
    {
        // Load up params dictionary with string / array combos
        voiceParamsDictionary["latitude"] = LatParams
        voiceParamsDictionary["longitude"] = LonParams
        voiceParamsDictionary["type"] = TypeParams
        voiceParamsDictionary["patch"] = PatchParams
        voiceParamsDictionary["pitch"] = PitchShiftParams //5/14
        voiceParamsDictionary["keysig"] = ScaleParams
        voiceParamsDictionary["level"] = LevelParams
        voiceParamsDictionary["overdrive"] = LevelParams
        voiceParamsDictionary["threshold"] = ThreshParams  //5/2 add threshold
        voiceParamsDictionary["nchan"] = NChanParams   //10/4 n/v/p channels
        voiceParamsDictionary["vchan"] = VChanParams
        voiceParamsDictionary["pchan"] = PChanParams
        voiceParamsDictionary["nfixed"] = NFixedParams   //10/4 n/v/p fixed
        voiceParamsDictionary["vfixed"] = VFixedParams
        voiceParamsDictionary["pfixed"] = PFixedParams
        voiceParamsDictionary["rottrigger"] = RotTriggerParams //4/18 add rot trigger
        voiceParamsDictionary["pkeydetune"] = DetuneParams //5/9 add detune
        voiceParamsDictionary["bottommidi"] = BottomMidiParams
        voiceParamsDictionary["topmidi"] = TopMidiParams
        voiceParamsDictionary["midichan"] = MidiChannelParams
        voiceParamsDictionary["name"] = VNameParams
        voiceParamsDictionary["comment"] = VCommParams   //2/4
        voiceParamsDictionary["portamento"]   = fx100Params //9/15/21 add fx
        voiceParamsDictionary["viblevel"]     = fx100Params
        voiceParamsDictionary["vibspeed"]     = fx100Params
        voiceParamsDictionary["vibwave"]      = fxWaveParams
        voiceParamsDictionary["vibelevel"]    = fx100Params
        voiceParamsDictionary["vibespeed"]    = fx100Params
        voiceParamsDictionary["vibewave"]     = fxWaveParams
        voiceParamsDictionary["delaytime"]    = fx100Params
        voiceParamsDictionary["delaysustain"] = fx100Params
        voiceParamsDictionary["delaymix"]     = fx100Params

    } //end setupVoiceParams
    
  
    
}

