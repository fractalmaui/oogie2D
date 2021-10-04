//    ___              _      ____
//   / _ \  ___   __ _(_) ___/ ___|  ___ ___ _ __   ___
//  | | | |/ _ \ / _` | |/ _ \___ \ / __/ _ \ '_ \ / _ \
//  | |_| | (_) | (_| | |  __/___) | (_|  __/ | | |  __/
//   \___/ \___/ \__, |_|\___|____/ \___\___|_| |_|\___|
//               |___/
//
//  OogieScene.swift
//  oogie2D
//
//  Created by Dave Scruton on 4/29/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//
//  5/12 add getSceneCentroidAndRadius
//  9/13/21 make sure patch gets loaded in addVoiceSceneData!!
//          add loop quiet instead of halts/restarts
//  9/18    add OogieVoiceParams
//  9/25    switch to using UIDs for scenePipes access
//  9/26    switch to using UIDs for shapes, get rid of getNewShapeKey
//          pull updateMaxShapeKey
//  9/27    add saveSelectedVoiceBackToScene... fix bug in addVoiceSceneData
//  9/28    add saveEditBackToSceneWith
//  10/2    add applyEdits to addVoiceSceneData
//  10/3    change uid use in saveSelectedVoiceBackToScene
import Foundation
import SceneKit
class OogieScene: NSObject {

    var uid  = ""
    var OSC  = OSCStruct()  // codable scene struct for i/o, NOT used at runtime!
    var OVP  =  OogieVoiceParams.sharedInstance //9/19/21 oogie voice params
    var OSP  =  OogieShapeParams.sharedInstance //9/19/21 oogie voice params
    var OPP  =  OogiePipeParams.sharedInstance  //9/19/21 oogie pipe params
    var OPaP =  OogiePatchParams.sharedInstance //9/28

    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    
    //Dictionaries where scenes are operated on at runtime
    var sceneVoices = Dictionary<String, OogieVoice>()
    var sceneShapes = Dictionary<String, OogieShape>()
    var scenePipes  = Dictionary<String, OogiePipe>()
        
    var masterPitch = 0

    //Selected items
    var selectedFieldName    = ""
    var selectedFieldType    = ""
    var selectedFieldMin     : Float = 0.0
    var selectedFieldMax     : Float = 0.0
    var selectedFieldDefault : Float = 0.0
    var selectedFieldDMult   = 0.0
    var selectedFieldDOffset = 0.0
    var selectedFieldStringVals : [String] = []
    var selectedFieldDisplayVals : [String] = [] //10/18
    var selectedFieldDefaultString = ""
    //Can these 3 names be collapsed into selectedItemName?
    var selectedMarkerKey   = ""
    var selectedShapeKey    = ""
    var selectedPipeKey     = ""
    var selectedObjectIndex  = 0 //Points to marker/shape/latlon handles, etc
    var selectedField        = -1  //Which param we chose 0 = lat, 1 = lon, etc
    var selectedShape   = OogieShape()  //1/21
    var selectedVoice   = OogieVoice()
    var selectedPipe    = OogiePipe()   //11/30
    
    //For Remembering last param values...
    var lastFieldSelectionNumber : Int = 0
    var lastFieldDouble : Double = 0.0
    var lastFieldString : String = ""
    var lastFieldPatch  = OogiePatch()
    var lastFieldInt    : Int = -1 //used for haptics triggering ONLY
    var lastBackToValue : Bool = false
    
    var pipeUIDToName = Dictionary<String, String>()
    
    //For finding new marker lat/lons
    let llToler = Double.pi / 10.0
    let llStep  = Double.pi / 8.0 //must be larger than toler
    //For creating new shapes
    var shapeClockPos  : Int = 1   //0 = noon 1 = 3pm etc
    var sceneLoaded = false  //5/7
    var handlingLoop = false
    var quietLoop = false //9/13/21 just keep loop quiet instead of halting?
    var needToHaltLoop = false
    var needFreshLoop  = false
//    var loopTimer = Timer()
    var editing = "" //9/1 move this to property!
    
    //-----------(oogieScene)=============================================
    override init() {
    }
    
    //-----------(oogieScene)=============================================
    // BUG 9/13: this loads in the voice info from the scene, and
    //  makes a new voice to add to the working data...
    //  PROBLEM: playColors is using the OOP struct to get things
    //    like voice type and buffer number, but it doesnt look like
    //     OOP is getting copied?
    // Maybe we should look at the patchName item and get the patch???
    // this is the only place sceneVoices get loaded
    // 9/27 use uid as dict key
    func addVoiceSceneData(nextOVS : OVStruct , op : String) -> OogieVoice
    {
        var newOVS    = nextOVS
        var uid       = newOVS.uid
        let newVoice  = OogieVoice()
        newVoice.uid  = uid //10/3 wups forgot one!
        let paramEdits = edits.sharedInstance //10/2 NOTE objective C struct!
        if op == "load" //Loading? Remember name, keep key!!
        {
            newVoice.OVS = newOVS
            let pname = newOVS.patchName
            //9/13 go for patch???
            if let oop = allP.patchesDict[pname]
            {
                newVoice.OOP = oop;
                //10/2 apply any edits at load time!
                let editDict = (paramEdits() as! edits).getForPatch(pname)
                newVoice.applyEditsWith(dict: editDict)
            }
            else {
                print(" addVoice ERR: cant find patch \(pname)") //9/27
            }
        }
        else if op == "new" //4/30 new?
        {
            newOVS           = OVStruct() //get new ovs
            newOVS.patchName = "SineWave" //1/27 need to default to something!
            newOVS.shapeKey  = selectedShapeKey //4/29 use dict lookup name!
        }
        else if op == "clone"
        {
            newOVS.uid = newOVS.getNewUID()
        }
        //Finish filling out voice structures
        //6/29/21 FIX!  newVoice.OOP = allP.getPatchByName(name:newOVS.patchName)
        //10/27 support cloning.. just finds unused lat/lon space on same shape
        if op == "clone" || op == "new"
        {
            let llTuple = getFreshLatLon(key: newOVS.shapeKey ,
                                         lat: newOVS.yCoord, lon: newOVS.xCoord)
            newOVS.yCoord = llTuple.lat
            newOVS.xCoord = llTuple.lon
            uid           = newOVS.getNewUID() // 9/27
            newOVS.name   = getNewVoiceName()  // 9/27
        }
        
        newVoice.OVS = newOVS
        //5/8 set master pitch from app delegate.. better place for this?
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        newVoice.masterPitch = appDelegate.masterPitch  // 5/8 this has to come from app delegate!!!
        if newVoice.OOP.type == PERCKIT_VOICE { newVoice.getPercLooxBufferPointerSet()  }
        setupSynthOrSample(oov: newVoice); //More synth-specific stuff
        newVoice.OVS.key    = uid      // 9/27
        sceneVoices[uid] = newVoice   // 9/27 save latest voice to working dictionary
        return newVoice //voice is needed by next call to 3d constructor
    } //end addVoiceSceneData
    
    //-----------(oogieScene)=============================================
    // 9/26 redo for uid keying
    func addShapeSceneData (shapeOSS:OSStruct , op : String, startPosition : SCNVector3) -> (shape:OogieShape,pos3D:SCNVector3)
    {
        var pos3D  = getFreshXYZ()
        var uid    = shapeOSS.uid   //key / uid are the SAME
        //SceneData half------------------------------------------------------------------
        var newOSStruct = shapeOSS //Copy in our shape to be cloned...
        if op != "load" // 10/26 clone / new object? need to get new XYZ
        {
            uid              = shapeOSS.getNewUID() //9/26
            newOSStruct.name = getNewShapeName()
            newOSStruct.uid  = uid
        }
        else //load, use existing XYZ
        {
            pos3D = shapeOSS.getPosition() //10/24 / wups, need start pos!
            pos3D.x += startPosition.x
            pos3D.y += startPosition.y
            pos3D.z += startPosition.z
        }
        newOSStruct.xPos    = Double(pos3D.x) //break out 3d position
        newOSStruct.yPos    = Double(pos3D.y)
        newOSStruct.zPos    = Double(pos3D.z)
        newOSStruct.key     = uid  //9/26
        let newOogieShape   = OogieShape()   // 1/21 new shape struct
        newOogieShape.OOS   = newOSStruct
        //5/3 wups forgot texture!
        newOogieShape.setBitmap(s: shapeOSS.texture)
        newOogieShape.bmp.setScaleAndOffsets(  //5/3 bmp now in oogieShape
            sx: shapeOSS.uScale, sy: shapeOSS.vScale,
            ox: shapeOSS.uCoord, oy: shapeOSS.vCoord)
        newOogieShape.setupSpinTimer(rs: shapeOSS.rotSpeed) //5/7 start timer..
        sceneShapes[uid] = newOogieShape  //save latest shap to working dictionary
        return (newOogieShape,pos3D)
    } //end addShapeSceneData
    
    //-----------(oogieScene)=============================================
    // for load: incoming PipeStruct will have a UID we want to keep
    // otherwise fresh UID will come from the fresh OogiePipe oop
    func addPipeSceneData(ps : PipeStruct , name : String, op : String) -> OogiePipe?
    {
        var oop = OogiePipe()
        if op == "load" //loading from scene
        {
            oop.uid = ps.uid   //Copy incoming pipe UID
        }
        let uid   = ps.uid
        oop.PS    = ps
        //OK now for 3d representation. Find centers of two objects:
        let toObj = oop.PS.toObject
        if let shape = sceneShapes[toObj] //Found a shape as target?
        {
            oop.destination    = "shape"
            shape.inPipes.insert(oop.uid) //Add our UID to shape object
        }
        else if let voice = sceneVoices[toObj] //Assume voice instead...
        {
            oop.destination    = "voice"
            voice.inPipes.insert(oop.uid) //Add our UID to voice inpipes
        }
        else  //4/28
        {
            print("ERROR: pipe target not found!")
            return nil
        }
        if op != "load" //4/27 keep lo/hi range on loads, otherwise compute based on input
        {
            let loHiRange = getPipeRangeForParamName(pname:ps.toParam.lowercased(),dest:oop.destination)
            oop.setupRange(lo: loHiRange.lo, hi: loHiRange.hi) //1/14 REDO
            oop.PS.name = getNewPipeName() //9/25
        }
        else
        {
            oop.setupRange(lo: oop.PS.loRange, hi: oop.PS.hiRange) //5/2 wups forgot!
        }
        scenePipes[uid]    = oop         // 9/25 store pipe object
        pipeUIDToName[uid] = oop.PS.name // 9/25 pipe management and updates:
        let from = oop.PS.fromObject          // get matching voice for fromMarker
        if let fromVoice = sceneVoices[from]
        {
            fromVoice.outPipes.insert(uid) //Add our UID to voice object
        }
        return oop
    } //end addPipeSceneData

    //-----------(oogieScene)=============================================
    // Looks up a synth patch, changes current voice
    func changeVoicePatch(name:String)
    {
        // tprint("cvp \(name)")
        //6/29/21 FIX!          let sPatch = allP.getPatchByName(name: name)
        //6/29/21 FIX!          selectedVoice.OOP = sPatch //take oogiePatch, attach to voice
        selectedVoice.OVS.patchName = name //4/25 is this needed?
        self.setupSynthOrSample(oov: selectedVoice); //More synth-specific stuff
    }

    //-----------(oogieScene)=============================================
    // Changes voice type Sample, Synth, etc
    func changeVoiceType(typeString:String , needToRefreshOriginalValue:Bool )
    {
        if needToRefreshOriginalValue
        {
            selectedVoice.OOP = lastFieldPatch
            self.setupSynthOrSample(oov: selectedVoice); //More synth-specific stuff
        }
        else
        {
            selectedVoice.loadDefaultsForNewType(nt:typeString.lowercased())
        }
    } // end changeVoiceType
    
    //-----------(oogieScene)=============================================
    func cleanupPipeInsAndOuts(uid:String)
    {
        if let pipe = scenePipes[uid]
        {
            removeVoiceOutputPipe(pipe:pipe)
            if pipe.destination == "shape" //headed to a shape?
               { removeShapeInputPipe(pipe:pipe) }
            //... need to handle voice input later!
        }
    }  //end cleanupPipeInsAndOuts
    
    //-----------(oogieScene)=============================================
    // 4/30 creates new scene named sname,
    //       with default sphere with one default voice
    // 9/28 simplified
    func createDefaultScene(named sname:String)
    {
        OSC.name            = sname
        var shape           = OSStruct()
        shape.key           = shape.getNewUID() //9/26
        var voice           = OVStruct()
        voice.patchName     = "SineWave"
        voice.shapeKey      = shape.key
        //update our dictionaries
        OSC.voices[voice.key] = voice
        OSC.shapes[shape.key] = shape
    } //end createDefaultScene


    //-----------(oogieScene)=============================================
    // 1/22 data bookkeeping, remove pipe UID from source voice outPipes set
    func removeVoiceOutputPipe(pipe:OogiePipe)
    {
        let vname = pipe.PS.fromObject //get our voice name
        if let voice = sceneVoices[vname] //and the voice...
        {
            voice.outPipes.remove(pipe.uid) //delete UID entry
        }
    } //end removeVoiceOutputPipe
    
    //-----------(oogieScene)=============================================
    // 1/22 data bookkeeping, remove pipe UID from dest shapes inPipes set
    func removeShapeInputPipe(pipe:OogiePipe)
    {
        let sname = pipe.PS.toObject //get our voice name
        if let shape = sceneShapes[sname]  //and the shape...
        {
            shape.inPipes.remove(pipe.uid) //delete UID entry
        }
    } //end removeShapeInputPipe

    
    //-----------(oogieScene)=============================================
    // 2/1 clears internal dictionaries of oogieVoices, Shapes and Pipes
    func clearOogieStructs()
    {
        sceneVoices.removeAll()
        sceneShapes.removeAll()
        scenePipes.removeAll()
    } //end clearOogieStructs

    
    //-----------(oogieScene)=============================================
    func foundAMarker(key : String , lat:Double , lon:Double)  -> Bool
    {
        for (_,vvv) in sceneVoices
        {
            if vvv.OVS.shapeKey == key
            {
                let olat = vvv.OVS.xCoord
                let olon = vvv.OVS.yCoord
                if sqrt((lat-olat) + (lon-olon)) < llToler {return true}
            }
        }
        return false
    } //end foundAMarker
    
    //-----------(oogieScene)=============================================
    //9/28 a dict would be way better!!!
    func findSceneShapeUIDByName ( name: String)  -> String
    {
        var uid = ""
        for (_,shape) in sceneShapes
        {
            if shape.OOS.name == name {uid = shape.OOS.uid;break}
        }
        return uid
    }
    
    //-----------(oogieScene)=============================================
    //9/28 a dict would be way better!!!
    func findSceneVoiceUIDByName ( name: String)  -> String
    {
        var uid = ""
        for (_,voice) in sceneVoices
        {
            if voice.OVS.name == name {uid = voice.OVS.uid;break}
        }
        return uid
    }
    
    //-----------(oogieScene)=============================================
    // used to clone markers, find new lat/lon point on sphere
    func getFreshLatLon(key : String , lat:Double , lon:Double)  -> (lat:Double , lon:Double )
    {
        var tlon = lon
        for _ in 0...10 //should never go this long!
        {
            //first try this long, staggering positive/negative...
            var tlat : Double = lat
            for i in 1...8
            {
                var dsign : Double = 1.0
                if i % 2 == 0 {dsign = -1.0}
                tlat = tlat + dsign * Double(i) * llStep
                if !foundAMarker(key : key , lat: tlat, lon: tlon)
                {
                    return (tlat,tlon)
                }
            }
            //still not found? increment lon and try again
            tlon = tlon + llStep
        }
        return(0.0 ,0.0) //give up, return zeroes
    } //end getFreshLatLon
    
    //=====<oogie2D mainVC>====================================================
    //9/28 from mainVC for pipe addition
    func getListOfSceneShapeNames() -> [String]
    {
        var list : [String] = []
        for (_,shape) in sceneShapes { list.append(shape.OOS.name) }
        list.sort()  //sort alphabetically
        return list
    }
    
    //=====<oogie2D mainVC>====================================================
    //9/28 from mainVC for pipe addition
    func getListOfSceneVoiceNames() -> [String]
    {
        var list : [String] = []
        for (_,voice) in sceneVoices {list.append(voice.OVS.name)}
        return list
    }

    
    //-----------(oogieScene)=============================================
    // 5/12 new
    func getSceneCentroidAndRadius() ->(c:SCNVector3,r:Float)
    {
        //Bail on empty/nil scene
        if sceneShapes.count == 0 {return(SCNVector3Zero,0.0)}
        var X    : Double = 0.0
        var Y    : Double = 0.0
        var Z    : Double = 0.0
        var X0   : Double = 0.0
        var Z0   : Double = 0.0
        var c    : Double = 0.0
        //Get centroid of all shapes...
        for (_,nextShape) in sceneShapes
        {
            let xx = nextShape.OOS.xPos
            let yy = nextShape.OOS.yPos
            let zz = nextShape.OOS.zPos
            X = X + xx
            Y = Y + yy
            Z = Z + zz
            if c == 0 //remember first XZ coords
            {
                X0 = xx
                Z0 = zz
            }
            c = c + 1.0
        }
        let cx = Double(X/c) //Get centroid of all our shapes
        let cy = Double(Y/c) //  y isnt used now btw
        let cz = Double(Z/c)
        let centroid = SCNVector3Make(Float(cx), Float(cy), Float(cz)) // centroid!
        X0  = X0 - cx   //get xz distances from centroid to first shape
        Z0  = Z0 - cz
        let r = Float(sqrt(X0*X0 + Z0*Z0-cz))  //This is radius from centroid to all shapes
        return(centroid,r)
    } //end getSceneCentroidAndRadius

    //-----------(oogieScene)=============================================
    //   get centroid first, then go " around the clock"
    //   1/22 redo math, was wrong in computing new item offset from centroid
    func getFreshXYZ() -> SCNVector3
    {
        let crTuple = getSceneCentroidAndRadius() //5/12 new
        var newPos3D = crTuple.c
        var outerRad = crTuple.r
        #if VERSION_2D
        outerRad += 3.0   //1/22
        #elseif VERSION_AR
        outerRad += 0.5   //1/22  tighten spatial arrangement in AR
        #endif
        //Add our offset radius to the centroid to get fresh pos
        switch(shapeClockPos)
        {
        case 0:  newPos3D.z -= outerRad  //Midnight, away from user
        case 1:  newPos3D.x += outerRad  //3oclock, to right
        case 2:  newPos3D.z += outerRad  //6oclock, towards user
        case 3:  newPos3D.x -= outerRad  //9oclock, to left
        default: newPos3D.x += outerRad  //error?  to right
        }
        shapeClockPos = (shapeClockPos + 1) % 4  //advance positional clock
        return newPos3D
    } //end getFreshXYZ
    
    
    //-----------(oogieScene)=============================================
    // 4/22 redo: move param funcs out to objects
    // 9/1 remove editing arg
    func getLastParamValue(named name : String)
    {
        var paramTuple = (name:"",dParam:0.0,sParam:"") // params get returned here...
        var getNumberedDisplayValue = false // used in pipes only for now...
        if editing == "voice" // get last param for voice/marker...
        {
            // param get: returns tuple with name, double and string result
            paramTuple = selectedVoice.getParam(named:name)
            //Special processing for some params...
            switch (name)
            {
            case "type":      lastFieldPatch  = selectedVoice.OOP  //for type/patch, get patch
            case "patch":     lastFieldPatch  = selectedVoice.OOP
            //10/14 get patch index in array of names too!
            let pname = selectedVoice.OVS.patchName.lowercased()
            lastFieldDouble = 0.0
            if let pindex = selectedFieldStringVals.index(of:pname)
            {
                lastFieldDouble = Double(pindex)
                }
//4/29 MIGRATE BUG: MOVE TO MAINVC!!!
            //            case "comment":  selectedMarker.updatePanels(nameStr: selectedVoice.OVS.name)  //10/11
            default: break //Just do nothing here
            } //end switch
        } //end whatWeBeEditing
        else if editing == "shape" // get last param for shape...
        {
            // param get: returns tuple with name, double and string result
            paramTuple = selectedShape.getParam(named:name)
        }
        else if editing == "pipe" // get last param for pipe...
        {
            // param get: returns tuple with name, double and string result
            paramTuple = selectedPipe.getParam(named:name)
            switch (name) //input/output is special...
            {
            case "inputchannel":
                getNumberedDisplayValue = true
            case "outputparam":
                getNumberedDisplayValue = true
            default: break //Just do nothing here
            }
        } //end else
        
        // Special case: lookup up current string value, get numeric index
        if getNumberedDisplayValue
        {
            lastFieldString = paramTuple.sParam.lowercased() //4/27
            if let index = selectedFieldStringVals.index(of: lastFieldString)
            { lastFieldDouble = Double(index) }
        }
            //OK, break out param, be it string or double...
        else if selectedFieldType == "string"  ||  selectedFieldType == "text"   //4/26 Got a string back?
        {
            lastFieldDouble = paramTuple.dParam
            lastFieldString = paramTuple.sParam
        }
        else  //otherwise...Got numeric (double)?
        {
            lastFieldDouble = paramTuple.dParam
            lastFieldString = ""
        }
        //print("got lfs [\(lastFieldString)]")
    } //end getLastParamValue
    
    //-----------(oogieScene)=============================================
     // 1/14 need this when switching pipe output during edit!
     //  Where should this live? it may need stuff from voices and shapes???
     // 1/29 should this just use the ranges from the object param data???
     func getPipeRangeForParamName(pname:String, dest:String) -> (lo:Double , hi:Double )
     {
         var pmin = 0.0
         var pmax = 255.0
         if dest == "shape" //1/29 shape has variable params, must be done case-by-case{
         {
             switch(pname)
             {
             case "rotation":
                 pmin = 0.1
                 pmax = 80.0
             case "rotationtype":
                 pmin = 0.0
                 pmax = 8.0 //Is this right?
             case "xpos","ypos","zpos"  :
                 pmin = -10.0
                 pmax =  10.0
             case "texxoffset","texyoffset" :pmax = 1.0
             case "texxscale" ,"texyscale"  :
                 pmin = 0.01
                 pmax = 100.0 //5/2 why not bigger range?
             default:pmax = 255.0
             }
         }
         else if dest == "voice" //1/29
         {
             let ov   = OogieVoice() //get fresh oogievoice for work...
             let limz = ov.getParmLimsForPipe(name:pname)
             pmin     = limz.lolim
             pmax     = limz.hilim
         }
         return (pmin,pmax)
     } //end getPipeRangeForParamName

    
    //-----------(oogieScene)=============================================
    func getSelectedFieldStringForKnobValue (kv : Float) -> String
    {
        let ik = min( max(Int(kv),0),selectedFieldStringVals.count-1)
        return selectedFieldStringVals[ik]
    }
    
        
    //-----------(oogieScene)=============================================
    // 9/25 always increment voice key for each new/cloned shape
    func getNewPipeName() -> String
    {
        return "pipe_" + String(format: "%05d", scenePipes.count+1)
    }
    
    //-----------(oogieScene)=============================================
    // 9/25 always increment voice key for each new/cloned shape
    func getNewShapeName() -> String
    {
        return "shape_" + String(format: "%05d", sceneShapes.count+1)
    }
    
    //-----------(oogieScene)=============================================
    // 9/25 always increment voice key for each new/cloned shape
    func getNewVoiceName() -> String
    {
        return "voice_" + String(format: "%05d", sceneVoices.count+1)
    }
    

    //-----------(oogieScene)=============================================
    func getKeyNumericPart (key : String) -> Int
    {
        //peel off numeric part...
        var part2 = ""
        let ss = key.split(separator: "_")
        if ss.count == 2
        {
            part2 = String(ss[1]) //get second part, convert to integer
            if let knum  = Int(part2) { return knum }
        }
        return 1
    }
    
    //-----------(oogieScene)=============================================
    // called every time user switches param with the wheel...
    //  loads in an array of param limits, names, whatever,
    //   and preps for param editing
    // WHY CANT we use breakOutSelectedFields here???
    func loadCurrentVoiceParams()
    {
        if selectedFieldName == ""  {return}
        let sfname = selectedFieldName.lowercased()  //type, patch, etc...
        var vArray = [Any]()
        if sfname != "patch"  //All params but patches are canned: CLUGEY use of hardcoded value!
        { //load them here
//9/14/21 OLD            vArray = selectedVoice.getNthParams(n: selectedField)
            // 9/18 KRASH HERE???
            //print(" CRASH HERE??? \(selectedFieldName))");
            vArray = selectedVoice.getNamedParams(name:selectedFieldName) //9/14/21 use name now
        }
        else  //Get approp patches
        {
            vArray = selectedVoice.getPatchNameArray() //Get patches for synth, drums, etc based on type
        }
        //print("varray \(vArray) count \(vArray.count)")
        if (vArray.count < 3) {return} //avoid krash
        selectedFieldType = vArray[1] as! String
        if (selectedFieldType == "double" || selectedFieldType == "int") && //4/26 int ptype
            vArray.count > 6 //Get double range / default
        {
            selectedFieldMin     = Float(vArray[2] as! Double)
            selectedFieldMax     = Float(vArray[3] as! Double)
            selectedFieldDefault = Float(vArray[4] as! Double)
            selectedFieldDMult   = vArray[5] as! Double
            selectedFieldDOffset = vArray[6] as! Double
        }
        else if  selectedFieldType == "string"  //Get array of strings
        {
            selectedFieldStringVals.removeAll()
            selectedFieldDisplayVals.removeAll()
            //Preload list of options with user choices if possible...
            if sfname == "patch" //11/16 look for user patches to choose
            {
                //11/16 get user shtuff first?
// 6/29/21 fix               let yuserPatches = allP.getUserPatchesForVoiceType(type: selectedVoice.OOP.type)
//                //print("got uptch type\(selectedVoice.OOP.type) \(yuserPatches)")
//                for (name,_) in yuserPatches  //for each, add to string / display arrays
//                {
//                    selectedFieldStringVals.append(name)
//                    selectedFieldDisplayVals.append(name)
//                }
            }
            for i in 2...vArray.count-1 //OK add more fields from params or built-in filenames
            {
                let fname = vArray[i] as! String
                selectedFieldStringVals.append(fname)
                //10/26 handle GM SAMPLE patches specially..
// 6/29/21 FIX!               if sfname == "patch" &&
//                    selectedVoice.OOP.type == SAMPLE_VOICE
//                {
//                    selectedFieldDisplayVals.append( //try to get instrument name...
//                        allP.getInstrumentNameFromGMFilename(fname: fname))
//                }
//                else // non-patches, just display the field strings
//                { selectedFieldDisplayVals.append(fname) }
            }
            //New patch defaults? OK for every type?  11/16
            if sfname == "patch"   //11/16 wow this needs new stuff!!
            {
                var wstring = "bubbles" //Get default patch name for selected voice type
                if selectedVoice.OOP.type == PERCKIT_VOICE {wstring = "kit1"}
                selectedFieldDefaultString = wstring
            }
            selectedFieldMin = 0.0 //DHS 9/22 wups need range for strings
            selectedFieldMax = Float(selectedFieldStringVals.count - 1)
        }
        //print("sfsv \(selectedFieldStringVals)   sfdv \(selectedFieldDisplayVals)")
    } //end loadCurrentVoiceParams
    
    //-----------(oogieScene)=============================================
    // 10/18 almost identical to loadCurrentVoiceParams,
    //  maybe merge later?
    func loadCurrentShapeParams()
    {
        if let vArray = OSP.shapeParamsDictionary[selectedFieldName]
        {
            breakOutSelectedFields(vArray: vArray)
        }
    } //end loadCurrentShapeParams

    //-----------(oogieScene)=============================================
    // 9/22 redo
    func loadCurrentPipeParams()
    {
        if var vArray = OPP.pipeParamsDictionary[selectedFieldName] //9/22 wups
        {
            if selectedFieldName == "outputparam" //9/22 output? params may vary
            {
                if vArray.count == 3 {vArray.remove(at: 2)} //Get rid of trailer
                //append shape/voice/etc parameters....
                if selectedPipe.destination == "shape" {vArray = vArray + OSP.shapeParamNamesOKForPipe }
                else                                   {vArray = vArray + OVP.voiceParamNamesOKForPipe }   //9/19/21
            }
            breakOutSelectedFields(vArray: vArray)
        }
    } //end loadCurrentPipeParams

    //-----------(oogieScene)=============================================
    // 9/30 new for patch edit
    func loadCurrentPatchParams()
    {
        var pname = selectedFieldName
        //10/2 split up any fields that have underbar, keep first part only
        let a = pname.split(separator: "_")
        if a.count > 1
        {
            pname = String(a[0]) //keep first part
        }
        if let vArray = OPaP.patchParamsDictionary[pname] //9/22 wups
        {
            breakOutSelectedFields(vArray: vArray)
        }
    } //end loadCurrentPatchParams

    //-----------(oogieScene)=============================================
    // 12/1 why cant this work for voices?
    func breakOutSelectedFields(vArray : [Any])
    {
        if (vArray.count < 3) {return} //avoid krash
        selectedFieldName = vArray[0] as! String
        selectedFieldType = vArray[1] as! String
        if (selectedFieldType == "double" || selectedFieldType == "int") && //4/26 int ptype
            vArray.count > 6 //Get double range / default
        {
            selectedFieldMin     = Float(vArray[2] as! Double)
            selectedFieldMax     = Float(vArray[3] as! Double)
            selectedFieldDefault = Float(vArray[4] as! Double)
            selectedFieldDMult   = vArray[5] as! Double
            selectedFieldDOffset = vArray[6] as! Double
        }
        else if  selectedFieldType == "string"  //Get array of strings
        {
            selectedFieldStringVals.removeAll()
            selectedFieldDisplayVals.removeAll()
            for i in 2...vArray.count-1
            {
                let s = vArray[i] as! String
                selectedFieldStringVals.append(s.lowercased())
                selectedFieldDisplayVals.append(s)
            }
            selectedFieldMin = 0.0 //DHS 9/22 wups need range for strings
            selectedFieldMax = Float(selectedFieldStringVals.count - 1)
        }
    } //end breakOutSelectedFields

    
    //-----------(oogieScene)=============================================
    //SHIT. no clue. do I read in gm patches, percussion patches, what?
    //11/16 look at all voices. if patch name matches, reload the OOP part
    //   of that voice and save it back into the sceneVoices dict...
    func reloadAllPatchesInScene(namez : [String])
    {
        //HYUB HH?? WTF? why cant i find new patch loaded htere!
        for (name,voice) in sceneVoices
        {
            let nnnn = voice.OVS.patchName
            if namez.contains(nnnn)  // is this a patch of interest?
            {
                //6/29/21 FIX!                  let ppp = allP.getPatchByName(name: nnnn)
                print("  ...reloading patch\(nnnn)")
                //6/29/21 FIX!                  voice.OOP         = ppp   //reset voice patch, and save back to scene dictionary
                sceneVoices[name] = voice
            } //end if namez
        }    //end for
    } //end reloadAllPatchesInScene

    //-----------(oogieScene)=============================================
     // 1/14 reload voice from last saved scene
     func resetVoiceByKey(key:String)
     {
        // print("resetVoiceByName \(name)")
         for (vkey, s) in OSC.voices
         {
             if vkey == key
             {
                 if let voice = sceneVoices[key] //gawd this is awkward. get substructure ...
                 {
                     voice.OVS = s;
                     if key == selectedMarkerKey {selectedVoice = voice}  //Reset seleted voice?
                 }
             }
         }
     }  //end resetVoiceByKey

     //-----------(oogieScene)=============================================
     // 1/14 reload shape from last saved scene, also resets 3d shape spin rate
     func resetShapeByKey(key:String)
     {
         //print("resetShapeByName \(name)")
         for (skey, s) in OSC.shapes
         {
             if skey == key
             {
                 if let shape = sceneShapes[key] //1/21 redo all this
                 {
                     shape.OOS = s
                     if key == selectedShapeKey
                     { selectedShape = shape }  //1/21 Reset seleted shape?
                     break
                 }
             }
         }
     }  //end resetShapeByKey

    //-----------(oogieScene)=============================================
    // Handles shape, voice, and pipe param changes.
    //  lots can go wrong here, maybe break this up?
    // 9/1 remove editing arg

    func setNewParamValue(newEditState : String , named : String , toDouble : Double , toString : String ) -> [String]
    {
        editing = newEditState //9/1/21
        var workDouble          = toDouble //we may change incoming double val!
        var workString          = toString
        let intChoiceChanged    = (Int(toDouble) != lastFieldInt)
        let backToOriginalValue = (Int(workDouble) == lastFieldSelectionNumber)
        var needToRefreshOriginalValue = false
        if (backToOriginalValue != lastBackToValue)
        {
            if backToOriginalValue {needToRefreshOriginalValue = true}
        }
        //Save our old value...
        lastBackToValue     = backToOriginalValue
        var results = [String]() //outputs results back to caller
        if editing == "voice" //1/14  set new value for voice/marker...
        {
            switch (named)  //4/23 handle preprocessing of param info...
            {
            // 9/14/21: Note we arent choosing patches by a number now,
            //  maybe pass in the patch name as toString?
            case "patch":
                if intChoiceChanged{
                    //9/14/21 TEST workString = getSelectedFieldStringForKnobValue (kv : Float(workDouble))
                    changeVoicePatch(name:workString)
                }
            case "bottommidi": //midi limits, need hi/lo range check
                workDouble = Double(min(selectedVoice.OVS.topMidi-1,
                                        Int(unitToParam(inval: workDouble))))
            case "topmidi":
                workDouble = Double(max(selectedVoice.OVS.bottomMidi+1,
                                        Int(unitToParam(inval: workDouble))))
            case "midichannel": //fields that need pre-conversion before storage
                workDouble = unitToParam(inval: workDouble) //4/26 convert range!
            
            case "keysig" , "vibwave", "vibewave": break;//do nothing
            default:
                workDouble = unitToParam(inval: workDouble) //9/15/21 Convert to desired range
                break
            } //end preprocessing switch
            
            //4/25 string? only set val on change...
            if  selectedFieldType != "string" || intChoiceChanged
            {selectedVoice.setParam(named : named ,
                                    toDouble : workDouble ,
                                    toString : workString)
            }
            switch (named)  //Post processing after param set...
            {
            case "latitude", "longitude":
                results.append("movemarker")
                results.append("updatevoicepipe")
                //results.append("updateshapepipe") //9/20 what if we have a shape pipe?
            case "type":
                if intChoiceChanged
                {
                    workString = getSelectedFieldStringForKnobValue (kv : Float(workDouble))
                    //print(" change voice type...%d %@",workDouble,workString);
                    changeVoiceType(typeString:workString , needToRefreshOriginalValue: needToRefreshOriginalValue)
                    results.append("updatevoicetype")
                }
            case "name"  : results.append("updatevoicename")
            default: break; //needRefresh = false
            } //end switch
        } //end voice editing
        else if editing == "shape"
        {
            if named != "rotationtype" //10/3 rotation type? no convert please!
            {
                workDouble = unitToParam(inval: workDouble) //9/15/21 Convert to desired range
            }
            selectedShape.setParam(named : named,
                                   toDouble : workDouble,
                                   toString : workString)
            var needUpdate = true
            var newSpeed   = false
            var newType    = false
            switch (named)  // setup 3D updates back in caller
            {
                case "xpos" ,"ypos" ,"zpos" : results.append("updateshapepipe")
                // results.append("updatevoicepipe") //9/20 what if we have a voice?
                case "texture"  : needUpdate = false
                case "rotation" : needUpdate = false ; newSpeed = true
                case "rotationtype" : needUpdate = false ; newType = true
                case "name" , "comment" : results.append("updateshapename")
                default: break
            }
            if needUpdate { results.append("updateshape")}
            if newSpeed   { results.append("updaterotationspeed")}
            if newType    { results.append("updaterotationtype")}
        } //end shape editing
        else if editing == "pipe" //1/14 set new value for pipe...
        {
            //Handle param preprocessing first...
            var iknob = Int(workDouble)
            switch (named)
            {
            case "inputchannel" : iknob = min(iknob,OPP.InputChanParams.count-2)
                workString = OPP.InputChanParams[iknob+2] as! String
            case "outputparam" :   //ugggh! this is complex! lots of param resets needed here
                var menuNames = OVP.voiceParamNamesOKForPipe   //9/18/21
                if selectedPipe.destination == "shape" {menuNames = OSP.shapeParamNamesOKForPipe} //9/19/21
                iknob      = min(iknob,menuNames.count-1) //Double check range to avoid crash
                workString = menuNames[iknob]
            case "lorange","hirange": //4/27 ranges come in as text, convert!
                if let d = Double(workString) { workDouble = d }
                //9/13/21 obsolete workDouble = Double(workString) //9/13/21 as! Double
                print("pipe range \(named) : \(workDouble)")
            default: break
            }
            let oldToParam = selectedPipe.PS.toParam
            
            selectedPipe.setParam(named : named,
                                  toDouble : workDouble,
                                  toString : workString)
            
            //Handle post-processing (updates, etc)
            switch (named)
            {
            case "outputparam" :   //ugggh! this is complex! lots of param resets needed here
                var menuNames = OVP.voiceParamNamesOKForPipe    //9/18/21
                if selectedPipe.destination == "shape" {menuNames = OSP.shapeParamNamesOKForPipe} //9/19/21
                iknob         = min(iknob,menuNames.count-1) //Double check range to avoid crash
                let opChanged = (menuNames[iknob] != oldToParam) //1/14 changed?
                selectedPipe.PS.toParam = menuNames[iknob]
                // DHS 1/14 Change? reload any targeted pipe shape w old scene settings!
                if opChanged //1/14 need resettin'
                {
                    let shapeOrVoiceKey = selectedPipe.PS.toObject
                    if selectedPipe.destination == "voice"   //1/14
                    {
                        resetVoiceByKey(key: shapeOrVoiceKey)
                    }
                    else if selectedPipe.destination == "shape"   //1/14
                    {
                        resetShapeByKey(key: shapeOrVoiceKey)  //Reset shape object from scene
                    }
                }
                //Need to get fresh pipe range! (what about edits, they get lost!)
                let loHiRange = getPipeRangeForParamName(pname:selectedPipe.PS.toParam.lowercased(),
                                                         dest:selectedPipe.destination)
                selectedPipe.setupRange(lo: loHiRange.lo, hi: loHiRange.hi) //1/14 REDO
                
            default: results.append("updatepipe")

            } //end case
        } //end pipe editing
        else if editing == "patch" //10/1 new
        {
            switch (named)  // setup 3D updates back in caller
            {
                //integer types: no conversion?
                case "wave" ,"type": break
                default:
                    workDouble = unitToParam(inval: workDouble) //9/15/21 Convert to desired range
            }
            selectedVoice.setPatchParam(named: named, toDouble: workDouble, toString: toString)
        }
        //print("results \(results)")
        return results
    } //end setNewParamValue
    
    //-----------(oogieScene)=============================================
    // canned for synth 0
    func setupSynthOrSample(oov : OogieVoice)
    {
        //print("setupSynthOrSample \(oov.OOP.attack)")
        if oov.OOP.type == SYNTH_VOICE
        {
            (sfx() as! soundFX).setSynthAttack(Int32(oov.OOP.attack));
            (sfx() as! soundFX).setSynthDecay(Int32(oov.OOP.decay));
            (sfx() as! soundFX).setSynthSustain(Int32(oov.OOP.sustain));
            (sfx() as! soundFX).setSynthSustainL(Int32(oov.OOP.sLevel));
            (sfx() as! soundFX).setSynthRelease(Int32(oov.OOP.release));
            (sfx() as! soundFX).setSynthDuty(Int32(oov.OOP.duty));
            //print("SYNTH: build wave/env ADSR \(oov.OOP.attack) :  \(oov.OOP.decay) :  \(oov.OOP.sustain) :  \(oov.OOP.release)")
            (sfx() as! soundFX).buildaWaveTable(0,Int32(oov.OOP.wave));  //args whichvoice,whichsynth
            (sfx() as! soundFX).buildEnvelope(0,false); //arg whichvoice?
        }
        else if (oov.OOP.type == PERCUSSION_VOICE)
        {
            //DHS 10/14 set up pointer to percussion sample...
            oov.bufferPointer = Int((sfx() as! soundFX).getPercussionBuffer(oov.OOP.name.lowercased()))
        }
        else if (oov.OOP.type == SAMPLE_VOICE)
        {
            (sfx() as! soundFX).setSynthAttack(Int32(oov.OOP.attack)); //10/17 add ADSR
            (sfx() as! soundFX).setSynthDecay(Int32(oov.OOP.decay));
            (sfx() as! soundFX).setSynthSustain(Int32(oov.OOP.sustain));
            (sfx() as! soundFX).setSynthSustainL(Int32(oov.OOP.sLevel));
            (sfx() as! soundFX).setSynthRelease(Int32(oov.OOP.release));
            (sfx() as! soundFX).setSynthDuty(Int32(oov.OOP.duty));
            
            //DHS 10/14 set up pointer to GM sample...
            oov.bufferPointer = Int((sfx() as! soundFX).getGMBuffer(oov.OOP.name))
            //11/16 got any ADSR? Build!
            if  (oov.OOP.attack  != 0) || (oov.OOP.decay   != 0) ||
                (oov.OOP.sustain != 0) || (oov.OOP.release != 0)
            {
                (sfx() as! soundFX).buildEnvelope(Int32(oov.bufferPointer),false); //arg whichvoice?
            }
        }
    } //end setupSynthOrSample
    
    
    //-----------(oogieScene)=============================================
    // 4/30 replace name with key
    func packupSceneAndSave(sname:String)
    {
        //10/26 first we need to clean target...
        OSC.voices.removeAll()
        OSC.shapes.removeAll()
        //update scene with any changed voice paras...
        for (key, nextVoice) in sceneVoices //10/26 wups
        {
            nextVoice.OVS.key = key           //4/30 pack up key too!
            OSC.voices[key]   = nextVoice.OVS  //1/21 cleanup
        }
        for (key,nextShape) in sceneShapes
        {
            nextShape.OOS.key = key           //4/30 pack up key too!
            OSC.shapes[key]   = nextShape.OOS  //1/21 pack the codable part
        }
        //DHS 12/5 pipes may have been renamed!
        OSC.pipes.removeAll()
        for (key,nextPipe) in scenePipes  //11/24 add pipes to output!
        {
            var npwork     = nextPipe     //why do i need this?
            npwork.PS.key  = key           //4/30 pack up key too!
            OSC.pipes[key] = npwork.PS
        }
        OSC.packParams() //11/22 need to pack some stuff up first!
        DataManager.saveScene(self.OSC, with: sname)
    } //end packupSceneAndSave

    //-----------(oogieScene)=============================================
    // 5/8 starts the loop bkgd process
    func startLoop()
    {
        print(" OVSCENE: startLoop");
        // this is used to keep the background loop from running too fast
//        loopTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.loopTick), userInfo:  nil, repeats: true)
        needFreshLoop  = true
        needToHaltLoop = false
        DispatchQueue.global(qos: .background).async {
            self.handleLoop()
        }
    }
    
    //-----------(oogieScene)=============================================
    // 5/8 halts the loop bkgd process
    func haltLoop()
    {
        needToHaltLoop = true
//        loopTimer.invalidate()
        print("halted loop...")
    }
    
    //-----------(oogieScene)=============================================
    // 5/8 makes sure loop runs slower than all-out
//    @objc func loopTick()
//    {
//        needFreshLoop = true
//    }

    var lastSampleTime = Date()
    
    //-----------(oogieScene)=============================================
    @objc func setLoopQuiet(flag:Bool)
    {
        quietLoop = flag
    }

    //-----------(oogieScene)=============================================
    // stupidly simple: a timer periodically sets loopOK to true, while
    //  this method is called infinitely from a background queue dispatch
    // this method then clears loopOK so it matches the timer
    @objc func handleLoop()
    {
        while !needToHaltLoop
        {
            if sceneLoaded
            {
                let sampleTime = Date()
                if sampleTime.timeIntervalSince(lastSampleTime) > 0.1 //just 10 frames / second for now...
//9/1 old value                if sampleTime.timeIntervalSince(lastSampleTime) > 0.005
                {
                    if !quietLoop
                    {
                        playAllPipesMarkers(  knobMode: "select")
                        needFreshLoop = false
                        lastSampleTime = sampleTime
                    }
                }
                
            }
        }
        print("loop exited!")
    } //end handleLoop
    
    //-----------(oogieScene)=============================================
    // Fucking massive... needs to be moved to a background process
    //   which is independent of the UI and any VC!!
    // 5/3 move to scene, now returns list of 3D updates in key:operation format
    // 9/1 make editing class member, set in setParamValue for now
    @objc func playAllPipesMarkers( knobMode:String) // NOT NEEDED -> [String]
    {
        if (sceneVoices.count == 0) {return } //5/7 bogus errors?
        //let pstartTime = Date()
        var updates3D = [String]()
        //First thing we get all the data from pipes...
 
        for (key,p) in scenePipes //handle pipes, update pipe....
        {
            //print("n \(n) spm \(selectedPipeKey)")
            var pwork = p //get editable copy?
            //12/1 use selected pipe if editing!
            if key == selectedPipeKey  { pwork = selectedPipe }
            if pwork.gotData // Got data? Send to shape/voice parameter
            {
                //1/14 NO conversion needed, already happens in pipe!
                //9/22 pipeVal comes out in range 0.0 to 1.0
                let pipeVal = pwork.getFromOBuffer(clearFlags:true)
                if pwork.destination == "shape" //send out shape param
                {
                    let toParamName = pwork.PS.toParam.lowercased()
                    let toKey = pwork.PS.toObject
                    if let shape = sceneShapes[toKey]
                    {
                        var dval = Double(pipeVal)
                        //Dig up the param info for pipe target...
                        if let vArray = OSP.shapeParamsDictionary[toParamName]
                        {
                            if vArray.count > 6 //got mult/offset params?
                            {
                                let ptype = vArray[1] as! String
                                if ptype == "double" // adjust doubles as needed
                                {
                                    let dmult = vArray[5] as! Double
                                    let doff  = vArray[6] as! Double
                                    dval = (dval * dmult) + doff  //same math as unitToParam
                                }
                            }
                        }
                        //print("--------> pipe toshape  param \(toParamName)  pipeval \(pipeVal)")
                        shape.setParam(named : toParamName , toDouble : dval , toString : "")
                        switch(pwork.PS.toParam.lowercased())  //Post processing for certain params...
                        {
                        case "rotationtype"  :   //special processing for rotationtype
                            updates3D.append(String(format: "setTimerSpeed:%@:%f", toKey,pipeVal))
                            sceneShapes[toKey] = shape //save it back!
                        default: break //4/28
                        }
                        updates3D.append(String(format: "update3DShapeByKey:%@", pwork.PS.toObject))
                        //Assume pipe texture needs updating...
                        updates3D.append(String(format: "updatePipeTexture:%@", key))
                    }   //end shape
                } //end pwork.destination
                else if pwork.destination == "voice" //1/27 send out voice param
                {
                    let toKey = pwork.PS.toObject
                    if let voice = sceneVoices[toKey]
                    {
                        var needPipeUpdate = false
                        switch(pwork.PS.toParam.lowercased())  //WTF WHY NEED LOWERCASE!
                        {
                        case "latitude"   : voice.OVS.yCoord      = Double(pipeVal)
                        needPipeUpdate = true
                        case "longitude"  : voice.OVS.xCoord      = Double(pipeVal)
                        needPipeUpdate = true
                        default: break
                        }
                        //print("tovoice pipeval \(pipeVal)")
                        voice.setParam(named : pwork.PS.toParam.lowercased() , //4/27 set params from pipe
                            toDouble : Double(pipeVal) ,
                            toString : "")
                        if needPipeUpdate  //Move a pipe? move it and/or marker?
                        {
                            updates3D.append(String(format: "updateMarkerPosition:%@:%@",toKey))
                            updates3D.append(String(format: "updatePipePosition:%@", pwork.PS.fromObject))
                        }
                    } //end let voice
                } //end destination
            } //end pwork.gotData
        } //end for n,p
        
        //iterate thru dictionary of voices, play each one as needed...
        // 5/3 NOTE we need to know if a voice is being edited below!!
        // 5/7 saw access violation crash here!!! WTF?
        for (key,nextVoice) in sceneVoices //4/28 new dict
        {
            //KRASH HERE when loading fresh scene
            var workVoice  = OogieVoice() //WOW THIS IS HORRIBLY SHOW!!!
            if editing == "voice" && knobMode != "select" &&
                selectedFieldName.lowercased() == key //4/28 selected and editing?
            {
                workVoice = selectedVoice //load edited voice
            }
            else //otherwise load next voice from scene
            {
                workVoice = nextVoice
            }
            var playit = true //10/17 add solo support
            //SOLO??                   if soloVoiceID != "" && workVoice.uid != soloVoiceID {playit = false}
            if  playit && !workVoice.muted  //10/17 add mute
            {
                if let shape = sceneShapes[workVoice.OVS.shapeKey] //get our voice parent shape...
                {
                    let rgbaTuple = workVoice.getShapeColor(shape:shape) //find color under marker
                    //Update marker output to 3D
                    updates3D.append(String(format: "updateMarkerRGB:%@:%d:%d:%d", key,rgbaTuple.R,rgbaTuple.G,rgbaTuple.B))
                    setupSynthOrSample(oov: workVoice) //load synth ADSR, send note out
                    //DHS try and get current angle computed from shape
                    let gotPlayed = workVoice.playColors(angle: shape.computeCurrentAngle(),                                                            rr: rgbaTuple.R,
                                                         gg: rgbaTuple.G,
                                                         bb: rgbaTuple.B)
                    updates3D.append(String(format: "updateMarkerPlayed:%@:%d",key,gotPlayed))
                }
            }
        } //end for counter...
        
        //1/25 this is a cluge for now: updating any pipe? skip this part to avoid krash
        //11/25 Cleanup time! Feed any pipes that need data...
        for (n,p) in scenePipes
        {
            var pwork = p //get editable copy
            if n == selectedPipeKey  { pwork = selectedPipe } //1/14 editing?
            if let vvv = sceneVoices[p.PS.fromObject] //find pipe source voice
            {
                //get latest desired channel from the marker / voice
                let floatVal = Float(vvv.getChanValueByName(n:p.PS.fromChannel.lowercased()))
                //print("------>packpipe from chan \(p.PS.fromChannel) : \(floatVal)")
                pwork.addToBuffer(f: floatVal) //...and send to pipe
                scenePipes[n] = pwork //Save pipe back into scene
                if n == selectedPipeKey  { selectedPipe = pwork } //1/14 editing?
            }
        } //end for n,p
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "got3DUpdatesNotification"), object: "myObject", userInfo: ["updates3D": updates3D])
        //let pendTime = Date()
        //let algoTime = pendTime.timeIntervalSince(pstartTime)
        //NSLog(" ...algo time %f",algoTime)

        return //NOT NEEDED updates3D // pass 3D updates back to caller
    } //end playAllPipesMarkers
    
    
    //-----------(oogieScene)=============================================
    func paramToUnit (inval : Double) -> Double
    {
        if selectedFieldDMult == 0.0 {return 0.0}
        return (inval - selectedFieldDOffset) / selectedFieldDMult
    } //end paramToUnit
    
    //-----------(oogieScene)=============================================
    func unitToParam (inval : Double) -> Double
    {
        //print("unitToParam : \(inval) :: mult \(selectedFieldDMult) off \(selectedFieldDOffset)")
        return (inval * selectedFieldDMult) + selectedFieldDOffset
    } //end paramToUnit
    
    //-----------(oogieScene)=============================================
    // 9/28 new
    func saveEditBackToSceneWith(objType:String)
    {
        if      objType == "voice" {saveSelectedVoiceBackToScene()}
        else if objType == "shape" {saveSelectedShapeBackToScene()}
        else if objType == "pipe"  {saveSelectedPipeBackToScene()}
    }
    
    //-----------(oogieScene)=============================================
    // 9/27 saves back to working scene
    func saveSelectedVoiceBackToScene()
    {
        sceneVoices[selectedVoice.OVS.uid] = selectedVoice
    }
    func saveSelectedShapeBackToScene()
    {  //why is shape so different???
        sceneShapes[selectedShape.OOS.uid] = selectedShape
    }
    func saveSelectedPipeBackToScene()
    {
        scenePipes[selectedPipe.uid] = selectedPipe
    }

    //-----------(oogieScene)=============================================
     //DIAGNOSTIC: Write out empty synth patches by name, still need to fill
     //  in voice details!
     func writeSynthPatches()
     {
         let sNames : [String] = [
             "SineWave","Sawtooth","SquareWave","RampWave",
             "Mellow","Bubbles","Casio","SoftSynth"
         ]
         for name in sNames{
             var oop     = OogiePatch()
             oop.name    = name
             oop.attack  = 0
             oop.decay   = 0
             oop.sustain = 0
             oop.release = 0
             oop.sLevel  = 0
             oop.duty    = 0
             oop.wave    = 0
             oop.type    = Int(SYNTH_VOICE)
             oop.saveItem(filename:name, cat:"GM") //Write it out! 11/14 new arg
         }
     } //end writeSynthPatches
     
     //-----------(oogieScene)=============================================
     //DIAGNOSTIC: Write out fresh patches for all General MIDI samples...
     func writeGMPatches()
     {
         if let pNames = (sfx() as! soundFX).getGMBufferNames()
         {
             for name in pNames{
                 let patchName = name as! String
                 print("write GM patch \(patchName)...")
                 var oop     = OogiePatch()
                 oop.name    = patchName
                 oop.attack  = 0
                 oop.decay   = 0
                 oop.sustain = 0
                 oop.release = 0
                 oop.sLevel  = 0
                 oop.duty    = 0
                 oop.wave    = 0
                 oop.type    = Int(SAMPLE_VOICE)
                 oop.saveItem(filename:patchName, cat:"GM") //Write it out! 11/14 new arg
             }
         }
     } //end writeGMPatches
     
     //-----------(oogieScene)=============================================
     //DIAGNOSTIC: Write out fresh patches for all percussion samples...
     func writePercussionPatches()
     {
         if let pNames = (sfx() as! soundFX).getPercussionBufferNames()
         {
             
             for name in pNames{
                 let patchName = name as! String
                 var oop     = OogiePatch()
                 oop.name    = patchName
                 oop.attack  = 0
                 oop.decay   = 0
                 oop.sustain = 0
                 oop.release = 0
                 oop.sLevel  = 0
                 oop.duty    = 0
                 oop.wave    = 0
                 oop.type    = Int(PERCUSSION_VOICE)
                 oop.saveItem(filename:patchName, cat:"GM") //Write it out! 11/14 new arg
             }
         }
     } //end writePercussionPatches
     
     //-----------(oogieScene)=============================================
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
                 
                // if let pname = sf[0] as String
                // {
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

                // }
                 

             }
         }catch{
             fatalError("error: no percussion!")
         }
         
      
     }
     

}
