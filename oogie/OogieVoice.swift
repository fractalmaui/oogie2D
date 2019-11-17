//                     _    __     __    _
//    ___   ___   __ _(_) __\ \   / /__ (_) ___ ___
//   / _ \ / _ \ / _` | |/ _ \ \ / / _ \| |/ __/ _ \
//  | (_) | (_) | (_| | |  __/\ V / (_) | | (_|  __/
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

//Parameter area... this is how the user gets at 3d objects from the UI
//Parmas: Name,Type,Min,Max,Default,DisplayMult,DisplayOffset?? (string params need a list of items)
// NOTE: .pi has to have a numeric multiplicator / divisor to compile in this statement!
let LatParams   : [Any] = ["Latitude" ,      "double", -.pi/2.0   , .pi/2.0   , 0.0, 180.0 / .pi, 0.0 ]
let LonParams   : [Any] = ["Longitude",      "double", -1.0 * .pi , 1.0 * .pi , 0.0, 180.0 / .pi,0.0 ]
// 10/15 NOTE: order here MUST match macro value order in synth!
let TypeParams  : [Any] = ["Type",           "string" , "Synth", "Percussion", "PercKit", "Sample", "Harmony"]
let PatchParams : [Any] = ["Patch",          "string","mt"]
// 10/4 NOT SUPPORTED YET
//let KeyParams   : [Any] = ["Key","string" , "C", "C#", "D", "D#", "E", "F",
//                                            "F#", "G", "G#", "A", "A#", "B"]
let ScaleParams : [Any] = ["Scale",          "string" ,"major" ,"minor" ,"blues" ,"chromatic",
                           "lydian" ,"phrygin" ,"pixolydian" ,"locrian" ,"egyptian",
                           "hungarian" ,"algerian","japanese" ]
let LevelParams    : [Any]   = ["Level" ,    "double", 0.0 , 1.0 , 0.5 , 255.0, 0.0 ]
//  10/4 add nvp chan/fixed / midi params
let NChanParams : [Any]      = ["NChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let VChanParams : [Any]      = ["VChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let PChanParams : [Any]      = ["PChan",     "string" , "Red", "Green", "Blue", "Hue",
                                "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow", "Fixed"]
let NFixedParams : [Any]     = ["NFixed",    "double" ,  0.0 , 1.0 , 0.2 , 100.0, 20.0 ]
let VFixedParams : [Any]     = ["VFixed",    "double" ,  0.0 , 1.0 , 0.5 , 255.0,  0.0 ]
let PFixedParams : [Any]     = ["PFixed",    "double" ,  0.0 , 1.0 , 0.5 , 255.0,  0.0 ]
let BottomMidiParams : [Any] = ["BottomMidi","double" ,  0.0 , 1.0 , 0.2 , 120.0,  8.0 ]
let TopMidiParams : [Any]    = ["TopMidi",   "double" ,  0.0 , 1.0 , 0.8 , 120.0,  8.0 ]
let MidiChannelParams : [Any] = ["MidiChannel", "double" ,  0.0 , 1.0 , 0.0 , 16.0,  1.0 ]
let NameParams    : [Any]    = ["Name",      "text", "mt"]
// All param names, must match first item above for each param!
let voiceParamNames : [String]    = ["Latitude", "Longitude","Type","Patch",
                             "Scale","Level",
                             "NChan","VChan","PChan",
                             "NFixed","VFixed","PFixed",
                             "BottomMidi","TopMidi","MidiChannel","Name"]

var voiceParamsDictionary = Dictionary<String, [Any]>()
// 9/23 canned perc kit defaults
let percDefaults : [String] = ["Bass_Drum_1","Acoustic_Snare","Low_Tom","Low_Mid_Tom",
                              "High_Tom","Open_Hi_Hat","Closed_Hi_Hat","Ride_Cymbal_1"]

var sfx = soundFX.sharedInstance

let MAX_LOOX = 8

class OogieVoice: NSObject {

    var pitchFloat = 0.0

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
    var lastnoteplayed = 0
    var hiLiteFrame = 0
    var bufferPointer = 0; //Points to sample buffer
    var bufferPointerSet = [Int]() //Array of sample buffers for percussion kit
    var triggerKey    = -1; //For percussion, GMidi note

    // Work vars for color conversion
    var HHH = 0
    var SSS = 0
    var LLL = 0
    var CC  = 0
    var MM  = 0
    var KK  = 0
    var YY  = 0
    
    //-----------(oogieVoice)=============================================
    override init() {
        super.init()
        OOP.type      = SYNTH_TYPE
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
        setupParams()
    }
    
    //-----------(oogieVoice)=============================================
    func setupParams()
    {
        // Load up params dictionary with string / array combos
        voiceParamsDictionary["00"] = LatParams
        voiceParamsDictionary["01"] = LonParams
        voiceParamsDictionary["02"] = TypeParams
        voiceParamsDictionary["03"] = PatchParams
        voiceParamsDictionary["04"] = ScaleParams
        voiceParamsDictionary["05"] = LevelParams
        voiceParamsDictionary["06"] = NChanParams   //10/4 n/v/p channels
        voiceParamsDictionary["07"] = VChanParams
        voiceParamsDictionary["08"] = PChanParams
        voiceParamsDictionary["09"] = NFixedParams   //10/4 n/v/p fixed
        voiceParamsDictionary["10"] = VFixedParams
        voiceParamsDictionary["11"] = PFixedParams
        voiceParamsDictionary["12"] = BottomMidiParams
        voiceParamsDictionary["13"] = TopMidiParams
        voiceParamsDictionary["14"] = MidiChannelParams
        voiceParamsDictionary["15"] = NameParams
    } //end setupParams
    
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= voiceParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return voiceParamsDictionary[key]!
    }
    
    
    //-----------(oogieVoice)=============================================
    // using this voices internal type, get array of appropriate patchnames
    func getPatchNameArray() -> [Any]
    {
        var patchNames = [String]()
        patchNames.append("Patch")
        patchNames.append("string")
        var dict = allP.synthPatchDictionary             //assume synth patches...
        if OOP.type == PERCKIT_VOICE
        {
            dict = allP.percKitPatchDictionary     //need percKit patches instead?
        }
        else if OOP.type == PERCUSSION_VOICE
        {
            dict = allP.percussionPatchDictionary  //need percussion patches instead?
        }
        else if OOP.type == SAMPLE_VOICE
        {
            dict = allP.GMPatchDictionary
            var lilNames : [String] = []
            for (name, _) in dict {lilNames.append(name)}
            lilNames = lilNames.sorted()
            for name in lilNames {  patchNames.append(name)  }
        }
        if OOP.type != SAMPLE_VOICE
        {
            for (name, _) in dict  {  patchNames.append(name)  } //append names
        }
        //10/18 Samples get sorted alphabetically...
        return patchNames
    } //end getPatchNameArray
    
    //-----------(oogieVoice)=============================================
    // 9/26 find our default in allpatches
    func loadDefaultPatchForVoiceType()
    {
        OOP = allP.getDefaultPatchByType(ptype: OOP.type)
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
        OOP = allP.getPatchByName(name: OVS.patchName)
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
//    func savePatch (name:String)
//    {
//        OOP.name = name
//        OOP.saveItem(filename:name, cat:"GM") //11/14 new arg
//    }

    //-----------(oogieVoice)=============================================
    // called when user switches type, need to reset synth/samples/whatever...
    func loadDefaultsForNewType(nt : String)
    {
        if  nt == "synth"
        {
            OOP = allP.getDefaultPatchByType(ptype: Int(SYNTH_VOICE))
        }
        else if nt == "percussion" //9/22
        {
            OOP.clear()
            OOP = allP.getDefaultPatchByType(ptype: Int(PERCUSSION_VOICE))
            bufferPointer = Int((sfx() as! soundFX).getPercussionBuffer(OOP.name))
            triggerKey    = Int((sfx() as! soundFX).getPercussionTriggerKey(OOP.name))
        }
        else if nt == "sample" //10/16
        {
            OOP.clear()
            OOP = allP.getDefaultPatchByType(ptype: Int(SAMPLE_VOICE))
            bufferPointer = Int((sfx() as! soundFX).getGMBuffer(OOP.name))
        }
        else if nt == "perckit" //9/24
        {
            OOP = allP.getDefaultPatchByType(ptype: Int(PERCKIT_VOICE))
            getPercLooxBufferPointerSet() //10/15 figger out which buffers to use...
        }
        OVS.patchName = OOP.name  //10/15 make sure we know the new patch name!
    } //loadDefaultsForNewType
    
    //-----------(oogieVoice)=============================================
    func getParamCount() -> Int
    {
        return shapeParamNames.count
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
        OVS.bottomMidi  = 64 - 0*12    //C 4
        OVS.topMidi     = 64 + 3*12  //  C 7
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
        if (OOP.type == SAMPLE_VOICE) //here's where our misc arg is important!
        {
            OVS.whichSamp = OVS.sampleOffset + vmisc
            OVS.detune    = 0   // Most samples will get detuned
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
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = OogieVoice()
        return copy
    }
    
    
    
    //-----------(oogieVoice)=============================================
    func RGBtoHLS(R:Int,G:Int,B:Int)
    {
    /* calculate lightness */
    let cMax = max( max(R,G), B);
    let cMin = min( min(R,G), B);
    var Rdelta = 0
    var Gdelta = 0
    var Bdelta = 0
        
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
        CC = 0
        MM = 0
        YY = 0
        if R==0 && G==0 && B==0
        {
            KK = 1
            return
        }
        lcc = 1.0 - (Double(R)/255.0)
        lmm = 1.0 - (Double(G)/255.0)
        lyy = 1.0 - (Double(B)/255.0)
        minCMY = lcc //get smallest of 3
        if minCMY > lmm {minCMY = lmm}
        if minCMY > lyy {minCMY = lyy}
    
        CC = Int(255.0 * (lcc-minCMY) / (1.0 - minCMY))
        MM = Int(255.0 * (lmm-minCMY) / (1.0 - minCMY))
        YY = Int(255.0 * (lyy-minCMY) / (1.0 - minCMY))
        KK = Int(255.0 * minCMY)
    // NSLog(@" RGB %d %d %d : cmyk %d  %d %d %d",R,G,B,CC,MM,YY,KK);
    
    } //end  RGBtoCMY
    

    
    //-----------(oogieVoice)=============================================
    func setInputColor(chr:Int,chg:Int,chb:Int)
    {
        var tnchan = 0
        var tpchan = 0
        var tvchan = 0
        var tschan = 0
        var pf     = 0.0

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
        var needHLS = true   //The VOICE type params may alter these two...
        var needCMY = true
        if needHLS  {RGBtoHLS( R:chr, G:chg, B:chb)}  //Do All conversions...
        if needCMY  {RGBtoCMY(R: chr, G:chg, B:chb) }
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
        case 6:  tnchan = CC
        case 7:  tnchan = MM
        case 8:  tnchan = YY
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
        case 6:  tvchan = CC
        case 7:  tvchan = MM
        case 8:  tvchan = YY
        default: tvchan = OVS.volFixed // 10/4 introduce fixed values
        }
        
        //Get color/etc channel out to pan channel as needed
        lpchan = 128 //start w/ reasonable default
        if OOP.type == SYNTH_VOICE || OOP.type == SAMPLE_VOICE || OOP.type == HARMONY_VOICE
        {
            switch(OVS.panMode) //10/4 was using wrong property!
            {
            case 0:  tpchan = chr
            case 1:  tpchan = chg
            case 2:  tpchan = chb
            case 3:  tpchan = HHH
            case 4:  tpchan = LLL
            case 5:  tpchan = SSS
            case 6:  tpchan = CC
            case 7:  tpchan = MM
            case 8:  tpchan = YY
            default: tpchan = OVS.panFixed // 10/4 introduce fixed values
            }
            
        }
       
        //OK, make our note fit into the range designated by user...
        let bmr = Double(OVS.topMidi-OVS.bottomMidi)  //get user target key range
        let bmn = Double(tnchan) / 256.0      //   input hue, convert to 0.0 - 1.0 range
        if OOP.type == SYNTH_VOICE || OOP.type == SAMPLE_VOICE || OOP.type == HARMONY_VOICE
        {
            midiNote =  OVS.bottomMidi + Int(bmr * bmn);
        }
        else //percussion
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
                case 6:  tpchan = CC
                case 7:  tpchan = MM
                case 8:  tpchan = YY
                case 9:  tpchan = 0 // L pan
                case 10: tpchan = 255 // R pan
                case 11: tpchan = 128 // N/A mode: center!
                default: tpchan = 128 // error? center!
                }
            
        }//perc

        // Handle pitch shift
        if OVS.pitchShift != 0  //skip zero pitch shift
        {
            if OVS.pitchShift == 1  //use hue?
            {
                tschan = HHH
            }
            else if OVS.pitchShift == 2  //use luminance?
            {
                tschan = LLL
            }
            else if OVS.pitchShift == 3  //use red ?  is there a better use for mode 3?
            {
                tschan = chr
            }
            pf = Double(tschan)/255.0;   // scale to 0..1 range
            pf = (pf-0.5)*100.0;        // shift to a tonal offset range...
            //NSLog(@" ...setpf[%d]: %f",which,pf);
        }
        //DHS: pitchfloat is a special intermediately set variable...
        //     in the viewcontroller, this value gets pulled and sent to synth...
        //     awkward, huh???
        pitchFloat = pf
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
            //DO NOT RANDOMIZE!
            OVS.topMidi     = 90; //Int.random(in:20...100);
            OVS.bottomMidi  = 30; //Int.random(in:20...100);
            if OVS.bottomMidi > OVS.topMidi //keep in order
            {
                let tmp        = OVS.topMidi
                OVS.topMidi    = OVS.bottomMidi
                OVS.bottomMidi = tmp
            }
            else if OVS.bottomMidi == OVS.topMidi //No spread? guarantee one octave
            {
                OVS.topMidi    = OVS.bottomMidi + 12
            }
            OVS.keySig      = Int.random(in:0...12); //Randomize key signature too!
            OVS.panMode     = Int.random(in:0...12); //Pan MODE
            //panlr       = Double.random(0.0...1.0);  //Actual pan
            OVS.thresh      = Int.random(in:1...15);        //    perc threshold for soundoff
            OVS.detune      = 1; // STICK TO DETUNED! ??Int.random(in:0...1);        //    perc threshold for soundoff
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

