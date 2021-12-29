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
//  11/1   add patch do scene dump
//  11/5   add ADSR update in set New ParamValue for patch edit
//  11/8   add saveit to packupSceneAndSave
//  11/9   move in adds and deletes for 3D shapes
//  11/10  add quant support
//  11/16  add savingEdits check in handleLoop, set/clear in all deletes
//             clear selected keys in deletes
//  11/17  fix bug in getSceneCentroidAndRadius  sqrt of negative!!!
//           add pipe 3D setNewChannel in setParam
//  11/19  fix typo in addScalar 3DNode, also get rid of stack use in deletes
//  11/28  add texture wrapS/T support
//  11/29  add liveMarkers flag
//  12/3   add version to packupSceneAndSave
//  12/4   redo add VoiceSceneData, compound ops
//  12/5   use scene VoiceCount, etc for new getNewVoiceName , etc
//  12/6   fix bug in set New ParamValue, pipe lo/hi ranges
//  12/7   add noVoices 2 createDefauyltScene
//  12/10  add clonelat/lon in add VoiceSceneData
//  12/15  moved in updateScalarBy...
//  12/18  in playAllPipesMarkers get color even for muted Voices
//  12/23  redo scalar 3D model / coords
//  12/25  remove knobMode in play AllPipes...
import Foundation
import SceneKit
class OogieScene: NSObject {

    var uid  = ""
    var OSC  =  OSCStruct()  // codable scene struct for i/o, NOT used at runtime!
    var OVP  =  OogieVoiceParams.sharedInstance //9/19/21 oogie voice params
    var OSP  =  OogieShapeParams.sharedInstance //9/19/21 oogie voice params
    var OPP  =  OogiePipeParams.sharedInstance  //9/19/21 oogie pipe params
    var OPaP =  OogiePatchParams.sharedInstance //9/28
    var OScP =  OogieScalarParams.sharedInstance  //10/13 new scalar type

    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    
    //Dictionaries where scenes are operated on at runtime
    var sceneVoices  = Dictionary<String, OogieVoice>()
    var sceneShapes  = Dictionary<String, OogieShape>()
    var scenePipes   = Dictionary<String, OogiePipe>()
    var sceneScalars = Dictionary<String, OogieScalar>() // 10/14 add scalars
    var sceneVoiceCount  : Int = 0 //12/5 new
    var sceneShapeCount  : Int = 0
    var scenePipeCount   : Int = 0
    var sceneScalarCount : Int = 0
    var appDelegate  = AppDelegate() //11/21 need handle to appD for tempo change etc

    // 11/16 reuse these in playallpipesandmarkers
    var workVoice = OogieVoice()
    var workPipe  = OogiePipe()
    
    var masterPitch = 0
    var liveMarkers = 0 //11/29
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
    var selectedScalarKey   = ""
    var selectedShapeKey    = ""
    var selectedPipeKey     = ""
    var selectedObjectIndex  = 0 //Points to marker/shape/latlon handles, etc
    var selectedField        = -1  //Which param we chose 0 = lat, 1 = lon, etc
    var selectedShape   = OogieShape()  //1/21
    var selectedVoice   = OogieVoice()
    var selectedPipe    = OogiePipe()   //11/30
    var selectedScalar  = OogieScalar()  //1/21

    // Dictionaries of 3D nodes
    //11/9/21 move from mainVC
    var shapes3D  = Dictionary<String, SphereShape>()
    var markers3D = Dictionary<String, Marker>()
    var pipes3D   = Dictionary<String, PipeShape>()
    var scalars3D = Dictionary<String, ScalarShape>()

    //For Remembering last param values...
    var lastFieldSelectionNumber : Int = 0
    var lastFieldDouble : Double = 0.0
    var lastFieldString : String = ""
    var lastFieldPatch  = OogiePatch()
    var lastFieldInt    : Int = -1 //used for haptics triggering ONLY
    var lastBackToValue = false
    var savingEdits     = false  //11/9 prevent collisions during edits
    var updatingScalar  = false //12/15
    var updatingPipe    = false //12/15
    var soloVoiceID = ""   //10/20 for solo voices
    var lastSampleTime = Date()

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
    var editing = "" //9/1 move this to property!
    var verbose = false // 10/12 for devbug
    //-----------(oogieScene)=============================================
    override init() {
       appDelegate = UIApplication.shared.delegate as! AppDelegate

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
    // 12/4 add compound operations
    func addVoiceSceneData(nextOVS : OVStruct , op : String) -> OogieVoice
    {
        //nextOVS.dump()
        var newOVS    = nextOVS   //copy incoming voice struct (for loads)
        var uid       = newOVS.uid    //10/30 for clone
        let newVoice  = OogieVoice()
        newVoice.uid  = uid //10/3 wups forgot one!
        let paramEdits = edits.sharedInstance //10/2 NOTE objective C struct!
        if op == "load" //Loading? Remember name, keep key!!
        {
            newVoice.OVS = newOVS
            newVoice.unpackXtraParams() //10/26 handle future proofing
            let pname = newOVS.patchName
            //9/13 go for patch???
            if let oop = allP.patchesDict[pname]
            {
                newVoice.OOP = oop;
                //10/2 apply any edits at load time!
                //12/3 why unwrap error now?
                if let editDict = (paramEdits() as! edits).getForPatch(pname)
                      {newVoice.applyEditsWith(dict: editDict)}
            }
            else {
                print(" addVoice ERR: cant find patch \(pname)") //9/27
            }
        }
        else if op == "new" //12/4 redo new check
        {
            newOVS           = OVStruct() //get new ovs
            newOVS.patchName = "SineWave" //1/27 need to default to something!
            newOVS.shapeKey  = selectedShapeKey //4/29 use dict lookup name!
            newOVS.uid       = uid //10/12 pass in new uid to our voice
        }
        else if op.contains("clone")  //12/10 add multiple clone options
        {
            uid = newOVS.getNewUID()   //10/30  clone ? make sure UIDs OK
            newOVS.uid   = uid
            newVoice.uid = uid
        }
        
        //Finish filling out voice structures
        //6/29/21 FIX!  newVoice.OOP = allP.getPatchByName(name:newOVS.patchName)
        //10/27 support cloning.. just finds unused lat/lon space on same shape
        if op.contains("clone") || op == "new" //12/10
        {
            let latFirst:Bool = (op == "clonelat")  //12/10
            let llTuple = getNewLatLon(key: newOVS.shapeKey ,
                                         lat: newOVS.yCoord, lon: newOVS.xCoord,
                                       latFirst: latFirst) //12/10
            newOVS.yCoord = llTuple.lat
            newOVS.xCoord = llTuple.lon
            //10/12 OUCH WOW THIS WAS SAVING TO THE WRONG PLACE!!! !  uid           = newOVS.getNewUID() // 9/27
            newOVS.name   = getNewVoiceName()  // 9/27
        }
        newVoice.OVS = newOVS // store new voice struct...

        //ok we have a voice now.. handle any additional params.
        if op.contains("new_") //12/4 compound add? set parameters up front...
        {
            newVoice.OVS.name = getNewVoiceName()
            //lets get our stuff
            let pairs = op.split(separator: "_")   // get param pairs...
            for pair in pairs //get each pair
            {
                let paramValPair = pair.split(separator: ":")
                if paramValPair.count > 1
                {
                    let pname = String(paramValPair[0])
                    let psval = String(paramValPair[1])
                    if let pval  = Double(paramValPair[1])
                    {
                        newVoice.setParam(named: pname, toDouble: pval, toString: psval)
                    }
                }
            } //end for pair
        } //end if op

        
        //5/8 set master pitch from app delegate.. better place for this?
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        newVoice.masterPitch = appDelegate.masterPitch  // 5/8 this has to come from app delegate!!!
        newVoice.masterTempo = appDelegate.masterTempo
        newVoice.masterTune  = appDelegate.masterTune
        if newVoice.OOP.type == PERCKIT_VOICE { newVoice.getPercLooxBufferPointerSet()  }
        setupSynthOrSample(oov: newVoice); //More synth-specific stuff
        newVoice.OVS.key    = uid      // 9/27
        //let sss = newVoice.dumpParams()
        sceneVoices[uid] = newVoice   // 9/27 save latest voice to working dictionary
        return newVoice //voice is needed by next call to 3d constructor
    } //end addVoiceSceneData
    
    //-----------(oogieScene)=============================================
    // always adds sphere for now... 12/11 add touch pos
    func addVoice3DNode (voice:OogieVoice, op:String )
    {
        if op != "new"
        {
            if sceneShapes[voice.OVS.shapeKey] == nil {return} //1/27 bail on no shape
        }
        if let shape3D = shapes3D[voice.OVS.shapeKey] //10/21 find shape 3d object
        {
            let uid = voice.OVS.uid
            //print("add voice3dnode op \(op) uid \(uid)")
            //Lat / Lon Marker to select color
            let nextMarker  = Marker(newuid:uid)
            nextMarker.name = voice.OVS.name //9/16 point to voice
            nextMarker.allShapes.name = uid
            //10/29 here we have int type, not string...
            nextMarker.updateTypeInt(newTypeInt: Int32(voice.OOP.type))
            markers3D[uid] = nextMarker //4/28 new dict
            shape3D.addChildNode(nextMarker)
            nextMarker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
        }
        else
        {
            print("error finding shape for voice \(voice.OVS.name)")
        }
    } //end addVoice3DNode

    
    //-----------(oogieScene)=============================================
    //10/13/21 new scalar control,
    //          note on create a UID comes in via scalarSS!!
    func addScalarSceneData (scalarSS:ScalarStruct, op:String)  -> OogieScalar 
    {
        var controlPos     = SCNVector3(0,0,0)
        let uid            = scalarSS.uid   //10/14 assume UID is always valid!!!
        var newSStruct     = scalarSS //Copy in our scalar to be cloned...
        newSStruct.uid     = uid     //  and uid too!
        var newOogieScalar = OogieScalar()   // 1/21 new shape struct
        if op != "load" // 10/26 clone / new object? need to get new name
        {
            controlPos      = getNewXYZwith(spacing: 0.5) //10/26
            newSStruct.xPos = Double(controlPos.x) //save to scalarStruct
            newSStruct.yPos = Double(controlPos.y)
            newSStruct.zPos = Double(controlPos.z)
            newSStruct.name = getNewScalarName()
        }
        newOogieScalar.uid   = uid
        newOogieScalar.SS    = newSStruct //pack up new scalar data

        //here is object we are pointing to...
        newOogieScalar.SS.toObject = scalarSS.toObject
        //OK now get target object
        let toObj = scalarSS.toObject
        if let shape = sceneShapes[toObj] //Found a shape as target?
        {
            newOogieScalar.destination = "shape"
            shape.inScalars.insert(uid) //A10/21 dd our UID to shape inscalars
        }
        else if let voice = sceneVoices[toObj] //Assume voice instead...
        {
            newOogieScalar.destination    = "voice"
            voice.inScalars.insert(uid) //Add our UID to voice inscalars
        }
        else  //4/28
        {
            print("ERROR: scalar target not found!")
        }
        sceneScalars[uid]    = newOogieScalar  //save latest shap to working dictionary
        return newOogieScalar //12/23 no need for tuple?
    } //end addScalarSceneData

    //-----------(oogieScene)=============================================
    // 12/23 big changes...
    func addScalar3DNode (scalar:OogieScalar, newNode : Bool) -> SCNNode
    {
        var scalar3D   = ScalarShape() //make new 3d shape, texture it
        let uid        = scalar.SS.uid //9/27
        if (!newNode) //10/19 forgot this bit, need to get 3d model to edit!
        {
            if scalars3D[uid] == nil {return SCNNode()} //bail on nil
            scalar3D = scalars3D[uid]!   //else get scalar shape
        }
        //get target object...
        let toObj   = scalar.SS.toObject //
        let sPos00  = SCNVector3(Float(scalar.SS.xPos),Float(scalar.SS.yPos),Float(scalar.SS.zPos))
        var sPos01  = SCNVector3(0.0,0.0,0.0)
        var objType = "voice"
        var tlat : Double = 0.0
        var tlon : Double = 0.0
        if let sphereNode = shapes3D[toObj]  //Found a shape as target?
        {
            sPos01  = sphereNode.position
            objType = "shape"
        }
        else //Assume voice/marker?
        {
            if let tmarker =  markers3D[toObj]
            {
               tlat    = tmarker.lat
               tlon    = tmarker.lon
               sPos01  = getMarkerParentPositionByName(name:toObj) //12/21
            }
        }
        // complex, creates scalar and a pipe connecting w/ target object
        scalar3D.create3DScalar(uid: uid,sPos00 : sPos00,
                                                    tlat: tlat , tlon: tlon, sPos01 : sPos01, //12/21
                                                    objType : objType,newNode:newNode)
        //12/14 we need to init both panels at create time!
        let scalarValue = scalar.SS.value //12/17
        scalar3D.updateIndicator(toObject: scalar.SS.toObject, value: CGFloat(scalarValue), dvalue: CGFloat(scalarValue)) //12/14
        scalar3D.updatePedestalLabel(with : scalar.SS.name) //12/14

        scalar3D.uid = uid
        scalar3D.key = uid  //10/14 looks like key is redundant??
        //WHICH node gets the name???? maybe just the cylinder?
        scalar3D.cylNode.name = uid //try click on cylinder?
        scalar3D.name  = uid //10/15 for overall click?
        scalar3D.name  = scalar.SS.name
        scalars3D[uid] = scalar3D     // 9/26 Add shape to 3d dict
        return scalar3D //11/19 typo
    } //end addScalar3DNode
    
    //-----------(oogieScene)=============================================
    // 12/30 for adding pipes...
    func getMarkerParentPositionByName (name : String) -> SCNVector3
    {
        var result  = SCNVector3Zero
        if let tvoice  = sceneVoices[name] //find our voice...
        {
            let psName  = tvoice.OVS.shapeKey //get name of shape to retrieve position...
            if let tShape  = shapes3D[psName]    //ok look up shape
            {
                result = tShape.position       //and get result!
            }
        }
        return result
    } //end getMarkerParentPositionByName


    //-----------(oogieScene)=============================================
    // 9/26 redo for uid keying
    func addShapeSceneData (shapeOSS:OSStruct , op : String, startPosition : SCNVector3) -> (shape:OogieShape,pos3D:SCNVector3)
    {
        var pos3D  = getNewXYZwith(spacing: 1.0)  //10/26 units in meters for AR
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
    // 4/28 peel off from addShapeToScene
    // 9/27 redo uid handling
    // 11/11 redo uid
    func addShape3DNode (pst : (shape:OogieShape , pos3D:SCNVector3)) -> SCNNode
    {
        let shapeOOS   = pst.shape.OOS
        let uid        = shapeOOS.uid //9/27
        let sphereNode = SphereShape(newuid:uid) //make new 3d shape, texture it
        sphereNode.setBitmap(s: shapeOOS.texture)
        sphereNode.uid      = uid //9/27 pass incoming shape UID to 3D objectd
        sphereNode.key      = uid    //9/26
        sphereNode.shapeNode.name = uid  //9/27 pass uid to shape node too!
        sphereNode.position = pst.pos3D //Place 3D object as needed..
        // 11/28 add wrapS/T
        sphereNode.setTextureScaleTranslationAndWrap(xs: Float(shapeOOS.uScale), ys: Float(shapeOOS.vScale), xt: Float(shapeOOS.uCoord), yt: Float(shapeOOS.vCoord) , ws : shapeOOS.wrapS , wt : shapeOOS.wrapT)
        sphereNode.name = shapeOOS.name
        shapes3D[uid]   = sphereNode     // 9/26 Add shape to 3d dict
        return sphereNode
    } //end addShape3DNode

    
    //-----------(oogieScene)=============================================
    // for load: incoming PipeStruct will have a UID we want to keep
    // otherwise fresh UID will come from the fresh OogiePipe oop
    // 10/4 pull name arg
    func addPipeSceneData(ps : PipeStruct , op : String) -> OogiePipe?
    {
        var oop = OogiePipe()
        oop.uid = ps.uid   //Copy incoming pipe UID 10/9 use incoming ps UID no matter what
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
    // 9/25 redo for uid NOT name as index to pipe
    func addPipe3DNode (oop:OogiePipe , newNode : Bool) -> SCNNode
    {
        let name   = oop.PS.name
        var pipe3D = PipeShape()
        let uid    = oop.uid //9/25 our master key for pipe creation/access
        if (!newNode) //update? pull pipe shape
        {
            if pipes3D[uid] == nil {return SCNNode()} //bail on nil
            pipe3D = pipes3D[uid]!   //else get pipe shape
        }
        else //2/1 new pipe? set up uid/name
        {
            pipe3D.uid  = uid  //1/22 force UID to be same as data object
            pipe3D.name = name
        }

        //1/26 Need to get lats / lons the hard way for now...
        let from    = oop.PS.fromObject
        if let fmarker = markers3D[from] //4/28
        {
             let flat    = fmarker.lat
             let flon    = fmarker.lon
             let sPos00  = getMarkerParentPositionByName(name:from)
            
             //print("updatepipe lat/lon \(flat),\(flon) : markerpos \(sPos00)")
             let toObj   = oop.PS.toObject
             var sPos01  = fmarker.position
             var tlat    = Double.pi/2.0
             var tlon    = 0.0
             var objType = "voice" //12/24
             
             if let sphereNode = shapes3D[toObj]  //Found a shape as target?
             {
                 sPos01 = sphereNode.position
                 objType = "shape"
             }
             else //Assume voice/marker?
             {
                 if let tmarker =  markers3D[toObj]
                 {
                    tlat    = tmarker.lat
                    tlon    = tmarker.lon
                    sPos01  = getMarkerParentPositionByName(name:toObj) //12/30
                 }
             }
             //print("apn [\(uid)] flatlon \(flat),\(flon)  tlatlon \(tlat),\(tlon) nn \(newNode)")
             //  11/29 match pipe color in corners
             pipe3D.pipeColor = pipe3D.getColorForChan(chan: oop.PS.fromChannel)
            let pipeNode = pipe3D.create3DPipe(uid: uid ,  //9/25
                                               flat : flat , flon : flon , sPos00  : sPos00 ,
                                               tlat : tlat , tlon : tlon , sPos01  : sPos01 ,
                                               objType: objType, newNode : newNode)
             if (newNode) //1/30
             {
                 pipeNode.name = name
                 pipe3D.addChildNode(pipeNode)     // add pipe to 3d object
                 // 11/16 add pipe texture 
                 pipe3D.addPipeTexture(phase:0.0 , chan: oop.PS.fromChannel.lowercased(),
                                     vsize: 256 , bptr : oop.bptr)
                 pipes3D[uid] = pipe3D             //9/25  dictionary of 3d objects
             }
        }
        return pipe3D
     } //end addPipe3DNode


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
    // 10/21 redid, cleanup of pipe datastructures only...
    func cleanupPipeInsAndOuts(uid:String)
    {
        if let pipe = scenePipes[uid]
        {
            let destUID = pipe.PS.toObject
            if pipe.destination == "shape" //headed to a shape?
            {
                if let shape3D = sceneShapes[destUID] //find our shape...
                {
                    shape3D.inPipes.remove(uid)  //remove scalar input (note uid)
                }
            }
            else if pipe.destination == "voice" //headed to a voice?
            {
                if let voice3D = sceneVoices[destUID]
                {
                    voice3D.inPipes.remove(uid)  //remove input
                }
            } //end destination
            //Remove pipe as voice output...
            let sourceUID = pipe.PS.fromObject
            if let voice3D = sceneVoices[sourceUID]
            {
                voice3D.outPipes.remove(uid)  //remove output
            }
        }
    }  //end cleanupPipeInsAndOuts
    
    //-----------(oogieScene)=============================================
    // 10/21 removes connections between scalars and shapes/markers
    func cleanupScalarOuts(uid:String)
    {
        if let scalar = sceneScalars[uid]
        {
            let destUID = scalar.SS.toObject
            if scalar.destination == "shape" //headed to a shape?
            {
                if let shape3D = sceneShapes[destUID] //find our shape...
                {
                    shape3D.inScalars.remove(uid)  //remove scalar input (note uid)
                }
            } //end destination
            else if scalar.destination == "voice" //headed to a voice?
            {
                if let voice3D = sceneVoices[destUID]
                {
                    voice3D.inScalars.remove(uid)  //remove input
                }
            } //end destination
        } //end if let scalar
    }  //end cleanupPipeInsAndOuts
    
    //-----------(oogieScene)=============================================
    // 4/30 creates new scene named sname,
    //       with default sphere with one default voice
    // 12/7 add noVoices
    func createDefaultScene(named sname:String , noVoices:Bool)
    {
        OSC.name  = sname
        var shape = OSStruct()
        shape.key = shape.uid //10/7 shape comes w/ uid already
        if !noVoices
        {
            var voice           = OVStruct()
            voice.patchName     = "SineWave"
            voice.shapeKey      = shape.key
            OSC.voices[voice.key] = voice //add voice to scene...
        }
        //update our dictionaries
        OSC.shapes[shape.key] = shape
    } //end createDefaultScene

    
    //-----------(oogieScene)=============================================
    // 10/21 cleanup to use uid only.  assume always gets valid pipe uid
    func deletePipeBy( uid : String  )
    {
        savingEdits = true //11/16 prevent data collisions
        //print("deletePipeByUID \(uid)") //9/25 use uid now NOT name
        cleanupPipeInsAndOuts(uid:uid)         // 1/22 cleanup ins and outs...
        scenePipes.removeValue(forKey: uid)
        if pipes3D[uid] != nil //11/19
        {
            pipes3D[uid]!.removeFromParentNode()
            pipes3D.removeValue(forKey: uid)        // 11/16 Delete 3d Object
        }  // Clean up 3D
        if selectedPipeKey == uid {selectedPipeKey = "" }
        savingEdits = false //11/16
    } //end deletePipeBy

    //-----------(oogieScene)=============================================
    // 10/21 new
    func deleteScalarBy( uid : String)
    {
        savingEdits = true //11/16 prevent data collisions
        if let _ = sceneScalars[uid] //valid scalar?
        {
            cleanupScalarOuts(uid: uid)  // unhook plumbinb
            if scalars3D[uid] != nil //11/19 should be ok?
            {
                scalars3D[uid]!.removeFromParentNode()
                scalars3D.removeValue(forKey: uid)  //delete from dict
            }
            sceneScalars.removeValue(forKey: uid)  //delete from scene
        }
        //print("deleteScalarByUID \(uid)") //9/25 use uid now NOT name
        if selectedScalarKey == uid {selectedScalarKey = "" }
        savingEdits = false //11/16
    } //end deleteScalarBy
    
    //-----------(oogieScene)=============================================
    // 2/6 redo: removes shape from scene / SCNNode 5/4 use key
    func deleteShapeBy(uid:String)
    {
        savingEdits = true //11/16 prevent data collisions
        if shapes3D[uid] != nil && sceneShapes[uid] != nil //11/19  got something to delete?
        {
            //remove any incoming pipes
            for puid in sceneShapes[uid]!.inPipes  { deletePipeBy(uid: puid ) }
            //10/21 delete any scalars
            for uid in sceneShapes[uid]!.inScalars { deleteScalarBy(uid: uid ) }
            for (vkey,v) in sceneVoices   //2/6 delete any voices parented to this shape
            {
                if v.OVS.shapeKey == uid  { deleteVoiceBy(uid:vkey) }
            }
            shapes3D[uid]!.removeFromParentNode()       //Blow away 3d Shape
            shapes3D.removeValue(forKey: uid)          //  delete dict 3d entry
            sceneShapes[uid]!.haltSpinTimer()      //halt timer... seems to linger after delete!!!
            sceneShapes.removeValue(forKey: uid)  //  delete dict data entry
        } // end if shape3D...
        if selectedShapeKey == uid {selectedShapeKey = "" }
        savingEdits = false //11/16
    } //end deleteShapeBy

    //-----------(oogieScene)=============================================
    // 10/27 removes voice from scene / SCNNode
    func deleteVoiceBy(uid:String)  //9/27 uid
    {
        savingEdits = true //11/16 prevent data collisions
        if markers3D[uid] != nil  //11/19
        {
            markers3D[uid]!.removeFromParentNode()
            if let voice = sceneVoices[uid]
            {
                //10/21 delete any scalars going to this voice...
                for uid in voice.inPipes   { deletePipeBy(uid: uid) }
                for uid in voice.inScalars { deleteScalarBy(uid: uid ) }
            }
            markers3D.removeValue(forKey: uid) //4/28 new dict
            sceneVoices.removeValue(forKey: uid)       //  and remove data structure
        }
        // 2/6 what about input pipes?
        if selectedMarkerKey == uid {selectedMarkerKey = "" }
        savingEdits = false // 11/16
    } //end deleteVoiceBy


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
    // 2/1 clears internal dictionaries of oogieVoices, Shapes and Pipes
    func clearOogieStructs()
    {
        sceneVoices.removeAll()
        sceneShapes.removeAll()
        scenePipes.removeAll()
        sceneScalars.removeAll() //10/20 forgot dis wone!
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
    // 11/7 get list of all textures in scene...  
    func getTextureNames() -> [String]
    {
        var nlist = [String]()
        for (_,nextShape) in sceneShapes
        {
            let tname = nextShape.OOS.texture            //  pack up key
            if tname != "default" {nlist.append(tname)}  //  dont care bout default
        }
        return nlist
    }
    
    //-----------(oogieScene)=============================================
    // used to clone markers, find new lat/lon point on sphere
    // 12/4 new idea: add vertical arg, if false, do horizontal seek instead
    //  12/10 add lat first arg
    func getNewLatLon(key : String , lat:Double , lon:Double , latFirst:Bool )  -> (lat:Double , lon:Double )
    {
        var tlon = lon
        var tlat = lat
        if !latFirst
        {
            for _ in 0...10 //should never go this long!
            {
                tlat = lat // stagger pos/neg along long
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
                tlon = tlon + llStep  //still not found? incr lon,try again
            }
        } //end !latfirst
        else //do lat first?
        {
            for _ in 0...10 //should never go this long!
            {
                tlon = lon  // stagger pos/neg along lat
                for i in 1...8
                {
                    var dsign : Double = 1.0
                    if i % 2 == 0 {dsign = -1.0}
                    tlon = tlon + dsign * Double(i) * llStep
                    if !foundAMarker(key : key , lat: tlat, lon: tlon)
                    {
                        return (tlat,tlon)
                    }
                }
                //still not found? increment lon and try again
                tlat = tlat + llStep
            }
        }
        return(0.0 ,0.0) //give up, return zeroes
    } //end getNewLatLon
    
    //-----------(oogieScene)=============================================
    //9/28 from mainVC for pipe addition
    func getListOfSceneShapeNames() -> [String]
    {
        var list : [String] = []
        for (_,shape) in sceneShapes { list.append(shape.OOS.name) }
        list.sort()  //sort alphabetically
        return list
    }
    
    //-----------(oogieScene)=============================================
    //9/28 from mainVC for pipe addition
    func getListOfSceneVoiceNames() -> [String]
    {
        var list : [String] = []
        for (_,voice) in sceneVoices {list.append(voice.OVS.name)}
        return list
    }

    //-----------(oogieScene)=============================================
    // convenience func, gets dict of name -> UID pairs
    // 10/23 add scalar
    func getNameUIDDict(forEvery:String) -> Dictionary<String, String>
    {
        var d = Dictionary<String, String>()
        if forEvery == "voice"
        {
            for (_,v) in sceneVoices { d[v.OVS.name] = v.OVS.uid }
        }
        else if forEvery == "scalar"
        {
            for (_,sc) in sceneScalars {d[sc.SS.name] = sc.SS.uid}
        }
        else if forEvery == "shape"
        {
            for (_,s) in sceneShapes {d[s.OOS.name] = s.OOS.uid}
        }
        else if forEvery == "pipe"
        {
            for (_,p) in scenePipes {d[p.PS.name] = p.PS.uid}
        }
        return d
    } //end getNameUIDDict

    //-----------(oogieScene)=============================================
    // 11/17/21 see NaN coming back as radius, WTF?
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
        // 11/17 redo calc...
        let r = Float(sqrt(X0*X0 + Z0*Z0));
        
        
//        let r = Float(sqrt(X0*X0 + Z0*Z0-cz))  //This is radius from centroid to all shapes
        
        return(centroid,r)
    } //end getSceneCentroidAndRadius

    //-----------(oogieScene)=============================================
    //   get centroid first, then go " around the clock"
    //   1/22 redo math, was wrong in computing new item offset from centroid
    func getNewXYZwith(spacing : Float) -> SCNVector3
    {
        let crTuple = getSceneCentroidAndRadius() //5/12 new
        var newPos3D = crTuple.c
        var outerRad = crTuple.r
        //10/26 remove VERSION_2D crap
        outerRad += spacing    
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
        //print("newxyz \(newPos3D) centroid \(crTuple)")
        return newPos3D
    } //end getNewXYZ
    
    
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
        scenePipeCount = scenePipeCount + 1 //12/5
        return "pipe_" + String(format: "%05d", scenePipeCount)
    }
    
    //-----------(oogieScene)=============================================
    // 10/!5 new
    func getNewScalarName() -> String
    {
        sceneScalarCount = sceneScalarCount + 1 //12/5
        return "scalar_" + String(format: "%05d", sceneScalarCount)
    }
    
    //-----------(oogieScene)=============================================
    // 9/25 always increment voice key for each new/cloned shape
    func getNewShapeName() -> String
    {
        sceneShapeCount = sceneShapeCount + 1 //12/5
        return "shape_" + String(format: "%05d", sceneShapeCount)
    }
    
    //-----------(oogieScene)=============================================
    // 9/25 always increment voice key for each new/cloned shape
    func getNewVoiceName() -> String
    {
        sceneVoiceCount = sceneVoiceCount + 1 //12/5
        return "voice_" + String(format: "%05d", sceneVoiceCount)
    }
//12/5 WRONG! what if a voice is deleted / added? we may get same name 2c!
//    func getNewVoiceName() -> String
//    {
//        return "voice_" + String(format: "%05d", sceneVoices.count+1)
//    }


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
    // 10/16 new
    func loadCurrentScalarParams()
    {
        if var vArray = OScP.scalarParamsDictionary[selectedFieldName]
        {
            if selectedFieldName == "outputparam" //10/18  same as for pipe
            {
                if vArray.count == 3 {vArray.remove(at: 2)} //Get rid of trailer
                //append shape/voice/etc parameters....
                if selectedScalar.destination == "shape" {vArray = vArray + OSP.shapeParamNamesOKForPipe }
                else                                   {vArray = vArray + OVP.voiceParamNamesOKForPipe }   //9/19/21
            }
            breakOutSelectedFields(vArray: vArray)
        }
    } //end loadCurrentScalarParams


    //-----------(oogieScene)=============================================
    // 9/22 redo
    func loadCurrentPipeParams()
    {
        if var vArray = OPP.pipeParamsDictionary[selectedFieldName] // get metadata for param
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
    // 10/20 add scalar 3D support
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
        var sceneChanges = [String]() //outputs needed 3D changes back to caller
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
            
            case "keysig" , "vibwave", "vibewave", "nchan", "vchan", "pchan", "quant": break;//do nothing
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
                sceneChanges.append("movemarker")
                sceneChanges.append("updatevoicepipe")
                sceneChanges.append("updatevoicescalar") //10/20
            case "type":
                if intChoiceChanged
                {
                    workString = getSelectedFieldStringForKnobValue (kv : Float(workDouble))
                    changeVoiceType(typeString:workString , needToRefreshOriginalValue: needToRefreshOriginalValue)
                    sceneChanges.append("updatevoicetype")
                }
            case "name"  : sceneChanges.append("updatevoicename")
            default: break; //needRefresh = false
            } //end switch
        } //end voice editing
        else if editing == "scalar" //10/17/21 new: edit scalar
        {
            if named != "rotationtype" //10/3 rotation type? no convert please!
            {
                workDouble = unitToParam(inval: workDouble) //9/15/21 Convert to desired range
            }
            selectedScalar.setParam(named : named,
                                   toDouble : workDouble,
                                   toString : workString)
            //Hmm what could be changed by resetting a scalar params?
            //  maybe just resend info to scalar and let it figure it out?
            switch (named)  // 12/14 3D updates...
            {
                case "name"  : sceneChanges.append("updatescalarname")
                case "xpos" , "ypos", "zpos"  : sceneChanges.append("updatescalarxyz") //12/21
                default: break
            }
        } //end shape editing
        else if editing == "shape"
        {
            if !["rotationtype","wraps","wrapt"].contains( named ) //11/28 now 3 params dont get converted
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
                case "xpos" ,"ypos" ,"zpos" : sceneChanges.append("updateshapepipe")
                sceneChanges.append("updateshapescalar") //10/26
                case "texture"  : needUpdate = false
                case "rotation" : needUpdate = false ; newSpeed = true
                case "rotationtype" : needUpdate = false ; newType = true
                case "name" , "comment" : sceneChanges.append("updateshapename")
                default: break
            }
            if needUpdate { sceneChanges.append("updateshape")}
            if newSpeed   { sceneChanges.append("updaterotationspeed")}
            if newType    { sceneChanges.append("updaterotationtype")}
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
            case "delay","lorange","hirange": //12/6 pipe delay needs convert...(and ranges)
                 workDouble = unitToParam(inval: workDouble) //9/15/21 Convert to desired range
            default: break
            }
            let oldToParam = selectedPipe.PS.toParam
            
            selectedPipe.setParam(named : named,
                                  toDouble : workDouble,
                                  toString : workString)
            
            //Handle post-processing (updates, etc)
            switch (named)
            {
            case "inputchannel" : //11/17 keep abreast of input channel
                if pipes3D[selectedPipe.uid] != nil
                {
                    pipes3D[selectedPipe.uid]!.setNewChannel(chan:workString.lowercased())
                }
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
                
            default: sceneChanges.append("updatepipe")

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
            selectedVoice.OOP.setParam(named: named, toDouble: workDouble, toString: toString) //12/13 new patch get/sets
            //11/5 handle ADSR changes...
            if ["attack","decay","sustain","slevel","release"].contains(named) //ADSR?
            {
                (sfx() as! soundFX).buildEnvelope(Int32(selectedVoice.OOP.wave),true); // update envelope
            }
        }
        return sceneChanges
    } //end setNewParamValue
    
    //-----------(oogieScene)=============================================
    // 12/17 called after new scene is loaded, returns scene changes
    func setupAllScalarDownstreamObjects() -> [String]
    {
        var sChangeSet = Set<String>()
        for (_,nextScalar) in sceneScalars
        {
            let paramTuple = setNewScalarValue(sobj:nextScalar , value: nextScalar.SS.value , pvalue : "")
            for s in paramTuple.sceneChanges { sChangeSet.insert(s) } //add to our set...avoid dupes!
        }
        var results = [String]()
        for s in sChangeSet {results.append(s)} //convert from set to [string]
        return results
    } //end setupAllScalarDownstreamObjects

    //-----------(oogieScene)=============================================
    // 12/15 add return array of 3d updates
    func setNewScalarValue(sobj : OogieScalar , value : Double , pvalue: String) ->
    (toobj:String , param : String ,val:Double , sceneChanges: [String])
    {
        var val   = value  //this will be changed below...
        var dmult :Double = 1.0
        var doff  :Double = 0.0
        let lorange :Double = sobj.SS.loRange
        let hirange :Double = sobj.SS.hiRange
        let invert = sobj.SS.invert   //Int vsl
        if invert != 0  { val = 1.0 - val }   // 10/18 FLIPIT        
        // lets fit val into the lo/hi range...
        val = lorange + val * (hirange-lorange)
        //print("...finalparamval \(val)")
        var ftype     = "double"
        let tobject   = sobj.SS.toObject //get target UID
        let paramName = sobj.SS.toParam.lowercased()
        var gotshape  = false
        var gotvoice  = false
        var toObjName = ""
        
        //get apropr. array for shape/voice param name
        var vArray = [Any]()
        var sceneChanges = [String]() //outputs needed 3D changes back to caller

        if let shape  = sceneShapes[tobject]
        {
            gotshape = true
            toObjName = shape.OOS.name
            // load up param metadata
            if let testArray = OSP.shapeParamsDictionary[paramName]
                { vArray = testArray  }
        }
        if let voice  = sceneVoices[tobject]
        {
            gotvoice  = true
            toObjName = voice.OVS.name
            // load up param metadata
            if let testArray = OVP.voiceParamsDictionary[paramName]
            { vArray = testArray }
        }
        if vArray.count > 0   //got legit param array?
        {
            // unbundle metadata and handle param...
            ftype   = vArray[1] as! String
            if ftype == "double" //convert to full param value range
            {
                if vArray.count > 6   //gotta get to 5th / 6th elt...
                {
                    dmult   = vArray[5] as! Double
                    doff    = vArray[6] as! Double
                    val = (val * dmult) + doff  //use mult/off fromparam...
                }
            }
            else  if ftype == "string" //chooser?
            {
                let nchoices = vArray.count - 3
                if nchoices > 1
                {
                    val = val * Double(nchoices)  //normalize to possible choice count
                }
            }
        } //end count ...
        
        //OK params are ready, time to apply...
        if gotshape
        {
            if sceneShapes[tobject] != nil //12/15 reduce mem leaks
            {
                sceneShapes[tobject]!.setParam(named: paramName, toDouble: val, toString: pvalue)
                update3DShapeBy(uid:tobject)
                sceneChanges.append("updateshape") //12/17
            }
        }
        else if gotvoice
        {
            if sceneVoices[tobject] != nil //12/15 reduce mem leaks
            {
                sceneVoices[tobject]!.setParam(named: paramName, toDouble: val, toString: pvalue)
                update3DShapeBy(uid:tobject)
                if paramName == "latitude" || paramName == "longitude" //require 3d update?
                {
                    sceneChanges.append("updatescalarmarker") //12/23 new opcode
                }
            }
        } //end gotvoice
        //print(" ....scalar -> set[\(tobject)] \(paramName) to \(val)")
        return( toObjName, paramName , val , sceneChanges) //let caller know what was changed
    } //end setNewScalarValue

    
    //-----------(oogieScene)=============================================
    // canned for synth 0 , used for keyboard in oogie2D
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
            (sfx() as! soundFX).buildEnvelope(Int32(oov.OOP.wave),false); // 10/8 synth waves 0..4
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
    func packupSceneAndSave(sname:String , saveit: Bool)
    {
        //10/26 first we need to clean target...
        OSC.voices.removeAll()
        OSC.shapes.removeAll()
        OSC.pipes.removeAll()
        OSC.scalars.removeAll() //10/18/21 new for scalars
        //update scene with any changed voice paras...
        for (key, nextVoice) in sceneVoices //10/26 wups
        {
            nextVoice.OVS.key = key            //  pack up key
            OSC.voices[key]   = nextVoice.OVS  // pack the codable part
        }
        for (key,nextScalar) in sceneScalars
        {
            // 10/18 weird bug. just save the SS somehow..
//            nextScalar.SS.key = key              //  pack up key
            var SS2 = nextScalar.SS
            SS2.key = key      //  pack up key
            OSC.scalars[key]   = SS2  // pack the codable part
        }
        for (key,nextShape) in sceneShapes
        {
            nextShape.OOS.key = key             //  pack up key
            OSC.shapes[key]   = nextShape.OOS  // pack the codable part
        }
        //DHS 12/5 pipes may have been renamed!
        for (key,nextPipe) in scenePipes  //11/24 add pipes to output!
        {
            var npwork     = nextPipe       //why do i need this?
            npwork.PS.key  = key           //  pack up key
            OSC.pipes[key] = npwork.PS    // pack the codable part
        }
        OSC.packParams() //11/22 need to pack some stuff up first!
        // 12/3 pack current version too
        OSC.ooversion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String

        if saveit { DataManager.saveScene(self.OSC, with: sname) } //11/8/21
    } //end packupSceneAndSave

    //-----------(oogieScene)=============================================
    // 5/8 starts the loop bkgd process
    func startLoop()
    {
        //print(" OVSCENE: startLoop");
        // this is used to keep the background loop from running too fast
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
        print("halted loop...")
    }
    
    
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
        if handlingLoop
        {
            print("ERROR scene:handleLoop called more than once!")
            return
        }

        handlingLoop = true
        while !needToHaltLoop
        {
            if sceneLoaded && !savingEdits  //11/16 add edit check
            {
                let sampleTime = Date()
                if sampleTime.timeIntervalSince(lastSampleTime) > 0.1 //just 10 frames / second for now...
                {
                    if !quietLoop
                    {
                        playAllPipesMarkers()
                        needFreshLoop = false
                        lastSampleTime = sampleTime
                    }
                }
                updateAllShapeRotations()  //11/9
                //11/19 move back to mainVC...updateAllMarkers() //11/15 OUCH! looks like  memory leak here!
            }
        }
    } //end handleLoop
    
    //-----------(oogieScene)=============================================
    // Called when a 3d shape params are changed.
    // Makes sure the 3D representation matches the data
    //  called by param set , restore, pipe data, and cancel
    func update3DShapeBy(uid : String)
    {
        if let sshape3d = shapes3D[uid] //get named SphereShape
        {
            var shapeStruct = selectedShape  //Get current shape object
            //print("update3DShapeBy:\(uid)  xyscale \(shapeStruct.OOS.uScale),\(shapeStruct.OOS.vScale)")
            if uid != selectedShapeKey
            {
                shapeStruct = sceneShapes[uid]!
            }
            //1/21 new struct...
            sshape3d.position = SCNVector3(shapeStruct.OOS.xPos ,shapeStruct.OOS.yPos ,shapeStruct.OOS.zPos )
            sshape3d.setTextureScaleTranslationAndWrap(xs: Float(shapeStruct.OOS.uScale),
                                                   ys: Float(shapeStruct.OOS.vScale),
                                                   xt: Float(shapeStruct.OOS.uCoord),
                                                   yt: Float(shapeStruct.OOS.vCoord),
                                                   ws : shapeStruct.OOS.wrapS , wt : shapeStruct.OOS.wrapT  //11/28
            )
            //5/3 moved bmp to oogieShape
            shapeStruct.bmp.setScaleAndOffsets(
                sx: shapeStruct.OOS.uScale, sy: shapeStruct.OOS.vScale,
                ox: shapeStruct.OOS.uCoord, oy: shapeStruct.OOS.vCoord)
        }
    } //end update3DShapeBy

    //-----------(oogieScene)=============================================
    func updateAllMarkers()
    {
        // iterate thru dictionary of markers... and update color
        // 11/16 KRASH HERE clearing scene!
        for (_,nextMarker) in markers3D
        {
            // 11/15 looks like a memoryleak here but HOW???
            nextMarker.updateMarkerPetalsAndColor(liveMarkers: liveMarkers) //11/29 add flag
            if nextMarker.gotPlayed  //10/31 put back, wups
            {
                nextMarker.updateActivity()
                nextMarker.gotPlayed = false //update our flag
 //12/25 NO NEED?                markers3D[key] = nextMarker //11/5 and resave marker
            }
        } //end for name...
    } //end updateAllMarkers
    
    //-----------(oogieScene)=============================================
    //11/9 test move in from mainVC
    func updateAllShapeRotations()
    {
        if savingEdits {return} //11/9 avoid collisions
        for (uid,shape3D) in shapes3D
        {
            //get rotation from oogieshape
            //KRASH how is this producing a bad access when rotation rate changes?
            //Trying to rewrite while its changing?
            //11/16 ANOTHER KRASH, while setting texture!!! 11/24 KRASH on shape dice!
            if let shape = sceneShapes[uid]
            {
                //print("uid \(uid) shape \(shape) angle \(shape.angle)")
                shape3D.setAngle(a:shape.angle)  //update 3d Shape
            }
        }
    } //end updateAllShapeRotations
    
    
    //-----------(oogieScene)=============================================
    func updatePipeByShape(s:OogieShape)
    {
        if updatingPipe {return} // 5/3 fail on multiple calls
        updatingPipe = true
        for (_,v) in sceneVoices // loop over voices, match with shape
        {
            if v.OVS.shapeKey == s.OOS.key //match key? update!
               {
                updatingPipe = false //9/22 clear flag for 2nd update
                updatePipeByVoice(v:v)
                //10/20 good chance scalars need updating too!
                updateScalarBy(voice: v)
               }
        }
        //Get all incoming pipes to shape, update positions
        for puid in s.inPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByShape
    
    //-----------(oogieScene)=============================================
    //12/15 updates pipes going FROM a voice,
    //  bool updatingPipe prevents redundant calls
    func updatePipeByVoice(v:OogieVoice)
    {
        if updatingPipe {return}  // 5/3 fail on multiple calls
        updatingPipe = true
        //Get all outgoing pipes from voice, update positions
        for puid in v.outPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByVoice
    
    //-----------(oogieScene)=============================================
    //12/15  broke out from updatePipeByVoice...only should be called if we are selected!!!
    func updatePipeByUID(_ puid:String)
    {
        if let pipeObj = scenePipes[puid]           //   find pipe struct
        {
            let _ = addPipe3DNode(oop: pipeObj, newNode : false) //1/30
            if let pipe3D = pipes3D[puid]    // get Pipe 3dobject itself to restore texture
            {
                pipe3D.updatePipeTexture( bptr : pipeObj.bptr) //11/16 translate texture now
            }
        }
    } //end updatePipeByUID

    
    //-----------(oogieScene)=============================================
    //12/15 update scalar if voice lat/lon changes
    func updateScalarBy(voice:OogieVoice)
    {
        if updatingScalar {return}
        updatingScalar = true
        //Get all incoming scalars from voice, update positions
        for puid in voice.inScalars { updateScalarBy(uid:puid) }
        updatingScalar = false
    } //end updateScalarByVoice
    
    //-----------(oogieScene)=============================================
    // 12/15 sometimes scalars must move...
    func updateScalarBy(uid:String)
    {
        if let scalarObj = sceneScalars[uid]    //   find scalar struct
        {
            let _ = addScalar3DNode(scalar:scalarObj, newNode : false) //12/23 pull pos arg
        }
    } //end updateScalarBy uid

    //-----------(oogieScene)=============================================
    // 12/15
    func updateScalarBy(shape:OogieShape)
    {
        if updatingScalar {return} // fail on multiple calls
        updatingScalar = true
        for uid in shape.inScalars
        {
            updateScalarBy(uid: uid)
        }
        updatingScalar = false
    } //end updateScalarBy shape
 
    //-----------(oogieScene)=============================================
    // Fucking massive... needs to be moved to a background process
    //   which is independent of the UI and any VC!!
    // 5/3 move to scene, now returns list of 3D updates in key:operation format
    // 9/1 make editing class member, set in setParamValue for now
    // 11/16 cleanup, removed all optional lets on large objects
    @objc func playAllPipesMarkers()
    {
        if (sceneVoices.count == 0) {return } //5/7 bogus errors?
        //let pstartTime = Date()
        var updates3D = [String]()
        //First thing we get all the data from pipes and apply it as needed
        for (key,_) in scenePipes //handle pipes, update pipe....
        {
            if scenePipes[key] != nil && scenePipes[key]!.gotData//11/16 remove optionals...
            {
                let toKey = scenePipes[key]!.PS.toObject
                var pipeVal = scenePipes[key]!.getFromOBuffer(clearFlags:true) //9/22 pipeVal comes out in range 0.0 to 1.0
                if scenePipes[key]!.PS.invert == 1 //10/5 INVERT , just flip over range 0.0 to 1.0
                    { pipeVal = 1.0 - pipeVal }
                if scenePipes[key]!.destination == "shape" //send out shape param
                {
                    let toParamName = scenePipes[key]!.PS.toParam.lowercased()
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
                        if verbose   //11/3
                        {
                            print("--------> pipe toshape  param \(toParamName)  pipeval \(pipeVal)")
                        }
                        shape.setParam(named : toParamName , toDouble : dval , toString : "")
                        switch(scenePipes[key]!.PS.toParam.lowercased())  //Post processing for certain params...
                        {
                        case "rotationtype"  :   //special processing for rotationtype
                            updates3D.append(String(format: "setTimerSpeed:%@:%f", toKey,pipeVal))
                            sceneShapes[toKey] = shape //save it back!
                        default: break //4/28
                        }
                        updates3D.append(String(format: "update3DShapeByKey:%@", scenePipes[key]!.PS.toObject))
                        //Assume pipe texture needs updating...
                        updates3D.append(String(format: "updatePipeTexture:%@", key))
                    }   //end shape
                } //end pwork.destination
                else if scenePipes[key]!.destination == "voice" //1/27 send out voice param
                {
                    if sceneVoices[toKey] != nil //11/16 get rid of optionals
                    {
                        var needPipeUpdate = false
                        switch(scenePipes[key]!.PS.toParam.lowercased())  //WTF WHY NEED LOWERCASE!
                        {
                        case "latitude"   : sceneVoices[toKey]!.OVS.yCoord      = Double(pipeVal)
                            needPipeUpdate = true
                        case "longitude"  : sceneVoices[toKey]!.OVS.xCoord      = Double(pipeVal)
                            needPipeUpdate = true
                        default: break
                        }
                        if verbose   //11/3
                        {
                            print("--------> pipe tovoice  param \(scenePipes[key]!.PS.toParam)  pipeval \(pipeVal)")
                        }
                        sceneVoices[toKey]!.setParam(named : scenePipes[key]!.PS.toParam.lowercased() , //4/27 set params from pipe
                                                     toDouble : Double(pipeVal) ,
                                                     toString : "")
                        if needPipeUpdate  //Move a pipe? move it and/or marker?
                        {  // KRASH HERE 11/16/21!! EXC_BAD_ACCESS   typo?
                            updates3D.append(String(format: "updateMarkerPosition:%@",toKey))
//                            updates3D.append(String(format: "updateMarkerPosition:%@:%@",toKey))
                            updates3D.append(String(format: "updatePipePosition:%@", scenePipes[key]!.PS.fromObject))
                        }
                    } //end sceneVoices
                } //end destination
            } //end scenePipes != nil
        } //end for key,_
        
        //iterate thru dictionary of voices, play each one as needed...
        // 5/3 NOTE we need to know if a voice is being edited below!!
        // 5/7 saw access violation crash here!!! WTF?
        for (key,nextVoice) in sceneVoices //4/28 new dict
        {
            workVoice = nextVoice //10/27 speedup?
           // 12/12 not possible? if workVoice.OVS == nil {print("ERROR: nil workvoice in playallpipes...")}
            if editing == "voice" &&
                selectedFieldName.lowercased() == key //4/28 selected and editing?
            {
                workVoice = selectedVoice //load edited voice
            }
            //11/21/21 is this the best place?
            workVoice.masterPitch = appDelegate.masterPitch
            workVoice.masterTempo = appDelegate.masterTempo
            workVoice.masterTune  = appDelegate.masterTune

            var playit = true //10/17 add solo support
            if soloVoiceID != "" && workVoice.uid != soloVoiceID {playit = false}
            //12/18 moved above muted check
            let rgbaTuple = workVoice.getShapeColor(shape:sceneShapes[workVoice.OVS.shapeKey]!) //find color under marker
            if  playit && !workVoice.muted  //10/17 add mute
            {
                if sceneShapes[workVoice.OVS.shapeKey] != nil //11/16 remove optionals
                {
                    //Update marker output to 3D
                    updates3D.append(String(format: "updateMarkerRGB:%@:%d:%d:%d", key,rgbaTuple.R,rgbaTuple.G,rgbaTuple.B))
                    setupSynthOrSample(oov: workVoice) //load synth ADSR, send note out
                    //DHS try and get current angle computed from shape
                    // 10/27 returns int now for gotPlayed
                    let gotPlayed = workVoice.playColors(angle: sceneShapes[workVoice.OVS.shapeKey]!.computeCurrentAngle(),                                                            rr: rgbaTuple.R,  gg: rgbaTuple.G, bb: rgbaTuple.B,verbose:verbose) //10/12 add verbose
                    updates3D.append(String(format: "updateMarkerPlayed:%@:%d",key,gotPlayed))
                }
            }
            else //12/18 muted? get color anyway for any pipes
            {
                workVoice.setInputColor(chr: rgbaTuple.R, chg: rgbaTuple.G, chb: rgbaTuple.B)
            }
        } //end for nextVoice...
        
        //1/25 this is a cluge for now: updating any pipe? skip this part to avoid krash
        //11/16 Cleanup time! Feed any pipes that need data... cleaned up code to, removed optionals
        for (n,p) in scenePipes
        {
            workVoice = sceneVoices[scenePipes[n]!.PS.fromObject]! //11/16 force unwrap find pipe source voice  e
            //get latest desired channel from the marker / voice
            let floatVal = Float(self.workVoice.getChanValueByName(n:p.PS.fromChannel.lowercased()))
            //print("------>packpipe from chan \(p.PS.fromChannel) : \(floatVal)")
            scenePipes[n]!.addToBuffer(f: floatVal) //...and send to pipe
        } //end for n,p
        if selectedPipeKey != ""   //editing? pipe may have changed!
        {  //11/16 KRASH HERE!!!
            selectedPipe = scenePipes[selectedPipeKey]!  //11/16 set selected pipe
        }

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
    //11/9 redo, cleanup
    func saveEditBackToSceneWith(objType:String)
    {
        savingEdits = true
        if      objType == "voice"  {sceneVoices[selectedVoice.OVS.uid] = selectedVoice}
        else if objType == "shape"  {sceneShapes[selectedShape.OOS.uid] = selectedShape}
        else if objType == "pipe"   {scenePipes[selectedPipe.uid]       = selectedPipe}
        else if objType == "scalar" {sceneScalars[selectedScalar.uid]   = selectedScalar}
        savingEdits = false
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
             let oop     = OogiePatch()   //12/25
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
                 let oop     = OogiePatch()   //12/25
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
                     let oop     = OogiePatch()    //12/25
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

    
    //-----------(oogieScene)=============================================
    //10/10 dump currently edited scene
    func getCurrentSceneDumpString() -> String
    {
        let delimiter = "-----------------------"
        var s = delimiter + delimiter + delimiter
        s = s + "Scene Dump:" + OSC.name + "\nVoices" + delimiter
        for (_,voice) in sceneVoices
        {
            s = s + voice.dumpParams() + "\n"
            s = s + "Patch:" + voice.OVS.patchName + delimiter + "\n"
            s = s + voice.OOP.dumpParams()  + "\n"   //11/1 add patch dump
        }
        s = s + "Shapes:" + delimiter + "\n"
        for (_,shape) in sceneShapes
        {
            s = s + shape.dumpParams() + "\n"
        }
        s = s + "Pipes:" + delimiter + "\n"
        for (_,shape) in scenePipes
        {
            s = s + shape.dumpParams() + "\n"
        }
        s = s + "Scalars:" + delimiter + "\n"  //10/21 new
        for (_,scalar) in sceneScalars
        {
            s = s + scalar.dumpParams() + "\n"
        }
        s = s + "\nEnd Scene Dump\n"
        return s
    }

    //-----------(oogieScene)=============================================
    //10/10 simple scene OK / not OK
    //  first all uids must match keys
    //  voices should point to valid shapes
    //  pipe from/to connections should be valid
    func validate() -> String
    {
        var err = false
        var s = "Scene Validation:"
        var suids = [String]() //keep track of shape uids...
        var vuids = [String]() //keep track of voice uids...
        for (key,shape) in sceneShapes
        {
            let uid = shape.OOS.uid
            suids.append(uid)
            if key != uid {s = s + "\nshape uid err \(key) vs \(uid)";err=true}
        }
        for (key,voice) in sceneVoices
        {
            let uid = voice.uid
            vuids.append(uid)
            if key != uid {s = s + "\nvoice uid err \(key) vs \(uid)";err=true}
            let skey = voice.OVS.shapeKey
            if !suids.contains(skey)   //Next, look for voices w/o shapes...
                {s = s + "\nvoice shapekey err \(key) : \(skey)";err=true}
        }
        for (key,pipe) in scenePipes
        {
            let uid = pipe.PS.uid
            if key != uid {s = s + "\npipe uid err \(key) vs \(uid)"}
            if !vuids.contains(pipe.PS.fromObject)   //Pipe w/o valid fromobject?
                {s = s + "\npipe fromObject err \(key) : \(pipe.PS.fromObject)";err=true}
            if !vuids.contains(pipe.PS.toObject) &&   //Pipe w/o valid toobject?
               !suids.contains(pipe.PS.toObject)
                {s = s + "\npipe toObject err \(key) : \(pipe.PS.toObject)";err=true}
        }
        if !err {s = "OK"}
        return s
    } //end validate


    
}
