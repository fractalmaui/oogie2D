//  __     ___                ____            _             _ _
//  \ \   / (_) _____      __/ ___|___  _ __ | |_ _ __ ___ | | | ___ _ __
//   \ \ / /| |/ _ \ \ /\ / / |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
//    \ V / | |  __/\ V  V /| |__| (_) | | | | |_| | | (_) | | |  __/ |
//     \_/  |_|\___| \_/\_/  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|
//
//  ViewController.swift
//  oogie2D
//
// ... see older impounds for earlier change comments
//  Dec 1   add edit for pipes, make editParams generic
//  Dec 2   add haptic feedback for param select / knob changes
//  Dec 5:  BUG:? pipes are stored by name, but name gets changed. So name is new but
//               pipes object and 3d data still indexed by loadtime name!
//  Dec 9: in updateSelectParamName add handlers for lo/hi range on pipes
//  12/15   hide / show pLabel and textEdit depending on parameter type
//  12/30  bug: addPipeStepTwo, use SCENE shapes/voices
//  1/14   pipe debugging, lots of changes
//  1/20   add oogieOrigin for all scene objects,pull allPipes
//  1/21   architecture: change OogieShape to OSStruct, make new oogieShape with pipe interfaces
//  1/22   add platform-dependent getFreshXYZ, redo math
//         add pipeUIDToName, new properties to OogiePipe, add updatePipeByVoice
//         add cleanupPipeInsAndOuts
//  1/25   Add updatingPipe flag to handle arbitration between pipe updates and pipe data i/o
//         ...needs improvement!!
//  1/26   wups lats/lons in pipeObject was a MISTAKE, redoing addPipeNode,
//           add texturePipe call in updatePipe,change knobMode to enum
//  1/27   fix deleteVoice bug
//  1/29   change getPipeRangeForParamName
//  2/4    redo name , comment fields for voice and ahape
//  2/5    move name into pipeStruct, add comment there too
import UIKit
import SceneKit
import Photos

let pi    = 3.141592627
let twoPi = 6.2831852

//Scene unpacked params live here for now...
var OVtempo = 135 //Move to params ASAP
var camXform = SCNMatrix4()

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,chooserDelegate,UIGestureRecognizerDelegate,patchEditVCDelegate {

    @IBOutlet weak var skView: SCNView!
    @IBOutlet weak var spnl: synthPanel!
    @IBOutlet weak var editButtonView: UIView!
    @IBOutlet weak var paramKnob: Knob!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var editButton: UIButton!

    var frakkinNote = 0
    
    var fadeTimer = Timer()
    var colorTimer = Timer()
    var pLabel = infoText()
    //10/29 version #
    var version = ""
    var build   = ""
    //10/17 solo
    var soloVoiceID = ""
    var touchLocation = CGPoint()
    var touchDown     = false //10/26
    var latestTouch   = UITouch()
    var testSample = 8
    var chooserMode = "loadAllPatches"
    var shouldNOTUpdateMarkers = false

    var updatingPipe = false   //1/25
    //12/2 haptics for wheel controls
    var fbgenerator = UISelectionFeedbackGenerator()

    
    @IBAction func testSelect(_ sender: Any) {
        dumpDebugShit()
 
    } //end testSelect
    
    var oogieOrigin = SCNNode()
    
    //Constructed shapes / handles
    var allMarkers    : [Marker]     = []
    var selectedUids  : [String]     = []
    var sceneVoices   = Dictionary<String, OogieVoice>()
    var shapes        = Dictionary<String, SphereShape>()  //10/21
    var sceneShapes   = Dictionary<String, OogieShape>()   //1/21
    var scenePipes    = Dictionary<String, OogiePipe>()
    var pipes         = Dictionary<String, PipeShape>()  //10/21
    var pipeUIDToName = Dictionary<String, String>()      //1/22
    //10/27 for finding new marker lat/lons
    let llToler = Double.pi / 10.0
    let llStep  = Double.pi / 8.0 //must be larger than toler

    
    //10/25 test pattern support
    #if USE_TESTPATTERN
    let ifname = "tp"
    #else
    let ifname = "oog2-stripey00t"
    #endif

    var whatWeBeEditing = ""

    //Params knob
    var oldKnobValue : Float = 0.0
    var oldKnobInt   : Int = 0    //1/14
    var knobValue    : Float = 0.0 //9/17 rename
    var lastBackToValue : Bool = false
    var selectedObjectIndex = 0 //Points to marker/shape/latlon handles, etc
    var selectedField = -1  //Which param we chose 0 = lat, 1 = lon, etc
    var selectedMarkerName   = ""
    var selectedShapeName    = ""
    var selectedPipeName     = ""
    var selectedFieldName    = ""
    var oselectedFieldName    = ""
    var selectedFieldType    = ""
    var paramWheelMin        : Float = 0.0 //These 5 fields are used w/ the knob -> floats
    var paramWheelMax        : Float = 0.0
    var selectedFieldMin     : Float = 0.0
    var selectedFieldMax     : Float = 0.0
    var selectedFieldDefault : Float = 0.0
    var selectedFieldDMult   = 0.0
    var selectedFieldDOffset = 0.0
    var selectedFieldStringVals : [String] = []
    var selectedFieldDisplayVals : [String] = [] //10/18
    var selectedFieldDefaultString = ""
    var lastFieldSelectionNumber : Int = 0
    var lastFieldDouble : Double = 0.0
    var lastFieldString : String = ""
    var lastFieldPatch  = OogiePatch()
    var lastFieldInt    : Int = -1
    enum KnobStates { case SELECT_PARAM, EDIT_PARAM }
    var knobMode = KnobStates.SELECT_PARAM
    
    var startPosition = SCNVector3(x: 0, y: 0, z:0)

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    
    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    var recentlyEditedPatches : [String] = []
    var tc = texCache.sharedInstance //9/3 texture cache

    var cameraNode      = SCNNode()
    let scene           = SCNScene()
    var OVScene         = OogieScene()
    var OVSceneName     = "default"
    var selectedShape   = OogieShape()  //1/21
    var selectedVoice   = OogieVoice()
    var selectedPipe    = OogiePipe()   //11/30
    var selectedMarker  = Marker()
    var selectedSphere  = SphereShape()  //10/18
    var selectedPipeShape = PipeShape()   //11/30

    //For creating new shapes
    var shapeClockPos  : Int = 1   //0 = noon 1 = 3pm etc
    var isPlaying = false


    let pitchShiftDefault = 0 //WILL BECOME An Appdelegate field
    let masterPitch = 0 //WILL BECOME An Appdelegate field
    let quantTime = 0  //using this or what?
    let MAX_CBOX_FRAMES = 20 //where does this go?
    //=====<oogie2D mainVC>====================================================
    override func viewDidLoad() {
        
        
        super.viewDidLoad()
        //Cleanup any margin problems w/ 3D view not perfectly fitting
        self.view.backgroundColor = .black

        //Our basic camera, out on the Z axis
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x:0, y: 0, z: 6)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 2)
        
        scene.rootNode.addChildNode(lightNode)
        let sceneView   = skView!
        sceneView.scene = scene
        sceneView.showsStatistics = true
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true
        
        //1/20 new origin for scene objects
        scene.rootNode.addChildNode(oogieOrigin)

        // 10/27 add longpress...
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        lpgr.minimumPressDuration = 0.5
        lpgr.delaysTouchesBegan = true
        lpgr.delegate = self
        self.view.addGestureRecognizer(lpgr)
        
        
        camXform = SCNMatrix4Identity //11/24 add camera matrix from scene file
        
        //Get our default scene, move to appdelegate?
        if DataManager.sceneExists(fileName : "default")
        {
            self.OVScene = DataManager.loadScene("default", with: OogieScene.self)
            self.OVScene.unpackParams()       //DHS 11/22 unpack scene params
            setCamXYZ() //11/24 get any 3D scene cam position...
            //print("...load default scene")
        }
        else
        {
            self.OVScene.createDefaultScene(sname: "default")
            self.OVScene.setDefaultParams()
            //print("...no default scene found, create!")
        }
        spnl = UINib(nibName: "synthPanel", bundle: .main).instantiate(withOwner: nil, options: nil).first as? synthPanel
        // let view = Bundle.main.loadNibNamed("CustomView", owner: nil, options: nil)!.first as! UIView // does the same as above
        spnl.frame = CGRect(x: 0, y: 450, width: 375, height: 220)
        self.view.addSubview(spnl)
        spnl.isHidden = true
        spnl.dButton.addTarget(self, action: #selector(synthXClicked), for: .touchUpInside)

        //Place bottom buttons / knobs automagically...
        let csz = UIScreen.main.bounds.size;
        var viewWid = csz.width   //10/27 enforce portrait aspect ratio!
        var viewHit = csz.height
        if (viewWid > viewHit) //wups? started in landscape, fixit!
        {
            viewHit = csz.width
            viewWid = csz.height
        }
        var pwh : CGFloat   = 256
        let inset : CGFloat = 160
        var pRect = CGRect(x: viewWid - inset, y: viewHit - inset, width: pwh, height: pwh)
        paramKnob.frame = pRect
        paramKnob.isHidden = true
        //Add tap gesture to knob...
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(wheelTap(sender:)))
        paramKnob.addGestureRecognizer(tapGesture)
        //paramKnob.verbose = true  //10/10  test
        
        pwh = 80
        let inset2  : CGFloat = 80
        pRect = CGRect(x: viewWid - inset2 , y: viewHit - inset2, width: pwh, height: pwh)
        //make edit button round
        editButtonView.frame = pRect
        editButtonView.layer.cornerRadius = 40
        editButtonView.isHidden = true
        //10/24 bug: menuBotton seems to accept toucnes from ehtier screen
        // deleted / recreated button.
        pRect = CGRect(x: 0 , y: viewHit - inset2, width: pwh, height: pwh)
        menuButton.frame = pRect
        menuButton.layer.cornerRadius = 40

        //9/13 reset button
        pRect = CGRect(x: 100 , y: viewHit - inset2, width: pwh, height: pwh)
        resetButton.frame = pRect
        resetButton.layer.cornerRadius = 40
        resetButton.isHidden = true

        //Sept 28 NEW top label!
        pLabel = infoText(frame: CGRect(x: 0,y: 32,width: viewWid,height: 80))

        pLabel.frame = CGRect(x: 0 , y: 32, width: 375, height: 80)
        self.view.addSubview(pLabel)
        pLabel.infoView.alpha = 0 //Hide label initially
        
        textField.frame = pLabel.frame
        textField.text  = "..."
        textField.isHidden = true
        textField.delegate = self
        
        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        
        //10/16 add notification to see when samples are loaded...
        NotificationCenter.default.addObserver(self, selector: #selector(self.samplesLoaded(notification:)), name: Notification.Name("samplesLoadedNotification"), object: nil)

        //11/18  Update markers UI in foreground on a timer
        colorTimer = Timer.scheduledTimer(timeInterval: 0.03, target: self, selector: #selector(self.updateAllMarkers), userInfo:  nil, repeats: true)
        //...handle pipes and music production in background
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.03) {
            self.playAllPipesMarkersBkgdHandler()
        }
        
        
        //2/3 DHS test
        _ = DataManager.getSceneVersion(fname:"default")

        

        

    } //end viewDidLoad

    
    //=====<oogie2D mainVC>====================================================
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask(rawValue: UIInterfaceOrientationMask.portrait.rawValue | UIInterfaceOrientationMask.portraitUpsideDown.rawValue)
    }

    //=====<oogie2D mainVC>====================================================
    func startPlayingMusic()
    {
        isPlaying = true
    }
    //=====<oogie2D mainVC>====================================================
    func stopPlayingMusic()
    {
        isPlaying = false   //NO Sounds!
    }

    
    //=====<oogie2D mainVC>====================================================
    // 10/16 we can only create voices AFTER samples load!
    @objc func samplesLoaded(notification: NSNotification)
    {
        //DHS 11/22 all patches needs to do a final sweep...
        allP.getAllPatchInfo() //11/22 Get sample rates, key offsets, etc.
        allP.loadGMOffsets()  //11/22
        //DHS 10/16 create our scene?
        create3DScene(scene: scene)
    }

    //=====<oogie2D mainVC>====================================================
    @objc func wheelTap(sender:UITapGestureRecognizer)
    {
        pLabel.fadeIn()  //interpret user tap as wanting to see more info
    }

    //=====<oogie2D mainVC>====================================================
    //MARK: - UILongPressGestureRecognizer Action -
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer)
    {
        if gestureReconizer.state != UIGestureRecognizer.State.ended {
            let pp = gestureReconizer.location(ofTouch: 0, in: self.view)
            // 11/3 make sure longpress is near original touch spot!
            if ((abs(pp.x - touchLocation.x) < 40) &&
                (abs(pp.y - touchLocation.y) < 40))
            {
                if whatWeBeEditing == "voice" { voiceMenu() }
                if whatWeBeEditing == "shape" { shapeMenu() }
                if whatWeBeEditing == "pipe"  { pipeMenu() }
            }
        }
        else {
        }
    } //end handleLongPress
    
 
    //=====<oogie2D mainVC>====================================================
    // 9/13 reset parameter to default
    @IBAction func resetSelect(_ sender: Any) {
        //print("reset to default \(selectedFieldDefault)")
        restoreLastParamValue(oldD: Double(selectedFieldDefault),oldS: selectedFieldDefaultString) //DHS 1/26
        knobValue = Float(selectedFieldDefault)  //9/17 make sure knob is set to param value
        selectedMarker.updateLatLon(llat: selectedVoice.OVS.yCoord, llon: selectedVoice.OVS.xCoord)
        resetKnobToNewValues(kval:knobValue , kmin : selectedFieldMin , kmax : selectedFieldMax)
    }

    //=====<oogie2D mainVC>====================================================
    // 9/12 RH edit button, over rotary knob, toggles edit / param mode
    @IBAction func editSelect(_ sender: Any) {
        if (knobMode == KnobStates.SELECT_PARAM)  //Change to Edit parameter??
        {
            knobMode = KnobStates.EDIT_PARAM
            getLastParamValue(fname : selectedFieldName.lowercased()) //Load up old vals for cancel operation
            knobValue = Float(lastFieldDouble)  //9/17 make sure knob is set to param value
            lastFieldSelectionNumber = Int(knobValue) //remember knob value to restore old deault
            pLabel.updateLabelOnly(lStr:"Edit:" + selectedFieldName)

            if selectedFieldMax == selectedFieldMin {print("ERROR: no param range")}
            //12/15 textfield and plabel occupy same screen space!
            //  maybe a ui update area is where this belongs!??
            textField.isHidden = selectedFieldType != "text"
            pLabel.isHidden    = selectedFieldType == "text" //12/15

            if selectedFieldType == "double" //9/28 set up display for this param
            {
                pLabel.setupForParam( pname : selectedFieldName , ptype : TFLOAT_TTYPE , //9/28 new
                    pmin : selectedFieldDMult * Double(selectedFieldMin) , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : [])
                paramKnob.wraparound = false //10/5 wraparound
                pLabel.showWarnings  = true  // 10/5 warnings OK
            }
            else if selectedFieldType == "string"
            {
                //10/18 DHS for GM patches, here we need to substitute
                
                pLabel.setupForParam( pname : selectedFieldName , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : selectedFieldDisplayVals) //10/18 separate display vals from string vals
                paramKnob.wraparound = true   //10/5 wraparound
                pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
            }
            else if selectedFieldType == "text" //10/9 new field type
            {
                print("12/5 duh set text to \(lastFieldString)")
                textField.text = lastFieldString //10/9 from OVS
                textField.becomeFirstResponder() //12/5 OK KB!
            }
            else if selectedFieldType == "texture" //10/21 handle textures
            {
                self.performSegue(withIdentifier: "textureSegue", sender: self)
            }
        } //end knobmode KnobStates.SELECT_PARAM
        else{   //Done editing? back to param select?
            knobMode  = KnobStates.SELECT_PARAM //NOT editing now...
            if whatWeBeEditing == "voice" //10/18 voice vs shape edit
            {
                print("done edit xycoord \(selectedVoice.OVS.xCoord), \(selectedVoice.OVS.yCoord)")

                sceneVoices[selectedMarkerName] = selectedVoice    //save latest voice to sceneVoices
                allMarkers[selectedObjectIndex] = selectedMarker //save any marker changes...
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : voiceParamNames)
            }
            else if whatWeBeEditing == "shape"
            {
                sceneShapes[selectedShapeName] = selectedShape    //10/21 save latest voice to sceneVoices
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : shapeParamNames)
            }
            else if whatWeBeEditing == "pipe" //DHS 12/4
            {
                
                //Save our pipe info back to scene
                scenePipes[selectedPipeName] = selectedPipe
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : pipeParamNames)
            }
            pLabel.updateLabelOnly(lStr:"Done:" + selectedFieldName)
            knobValue = Float(selectedField)  // 9/17  set knob value to old param index...
            paramWheelMin     = 0.0
            var count = voiceParamNames.count
            if whatWeBeEditing == "shape" {count = shapeParamNames.count}
            paramWheelMax        = Float(count - 1)
            paramKnob.wraparound = true //10/5 wraparound
            pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
        }

        updateWheelAndParamButtons()
    } //end editSelect
    
    

    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if knobMode == KnobStates.EDIT_PARAM {cancelEdit()}  //1/14 Editing? Not any more!
        stopPlayingMusic()
        if segue.identifier == "textureSegue" {
            if let nextViewController = segue.destination as? TextureVC {
                    nextViewController.delegate = self
            }
        }
        // 11/4 add scene chooser
        else if segue.identifier == "chooserLoadSegue" {
            if let chooser = segue.destination as? chooserVC {
                chooser.delegate = self
                chooser.mode     = chooserMode
            }
        }
        else if segue.identifier == "chooserSaveSegue" {
            if let chooser = segue.destination as? chooserVC {
                chooser.delegate = self
                chooser.mode     = chooserMode
            }
        }
        //11/8
        else if segue.identifier == "EditPatchSegue" {
            if let nextViewController = segue.destination as? PatchEditVC {
                    nextViewController.delegate = self
                //plass in selected patch if popup appeared...
                if whatWeBeEditing == "voice"
                    {nextViewController.opatch = self.selectedVoice.OOP //10/18
                     nextViewController.patchName = self.selectedVoice.OVS.patchName
                    }
            }
        }

    } //end prepareForSegue

    override func unwind(for unwindSegue: UIStoryboardSegue, towardsViewController subsequentVC: UIViewController) {
        print("unwind from segue")
    }
    //=====<oogie2D mainVC>====================================================
    override func canPerformUnwindSegueAction(_ action: Selector, from fromViewController: UIViewController, sender: Any?) -> Bool {
        print("can? unwind from segue")
        return false
    }
    
    //=====<oogie2D mainVC>====================================================
    func resetKnobToNewValues(kval:Float , kmin : Float , kmax : Float)
    {
        paramKnob.minimumValue = kmin
        paramKnob.maximumValue = kmax
        paramKnob.setValue(kval) //and set knob control
    } //end resetKnobToNewValues

    
    //=====<oogie2D mainVC>====================================================
    //  9/13 uses knobMode, updates buttons / wheels at bottom of screen
    func updateWheelAndParamButtons()
    {
        var knobName            = "fineGear" //assume edit
        paramKnob.isHidden      = false
        editButtonView.isHidden = false
        if (knobMode == KnobStates.EDIT_PARAM)  //Edit?
        {
            paramKnob.isHidden      = selectedFieldType == "text"  //10/9
            resetButton.isHidden    = selectedFieldType == "text"  //10/9
            editButtonView.isHidden = false
            editButton.setTitle("OK", for: .normal)
            menuButton.setTitle("X", for: .normal)
            if selectedFieldType == "double"  //get range for wheel...
            {//9/23 test
            }
            if selectedFieldType == "string"  //string array?
            {
                let maxxx = Float(selectedFieldStringVals.count - 1)
                //print("set param minmax to 0.0 , \(maxxx)")
                selectedFieldMin = 0.0
                selectedFieldMax = maxxx
            }
            resetKnobToNewValues(kval: knobValue ,kmin: selectedFieldMin ,kmax: selectedFieldMax)
        } //end edit select
        else{   //back to param select?
            knobName = "wheel01"
            resetButton.isHidden = true
            textField.isHidden   = true //10/9
            editButton.setTitle("Edit", for: .normal)
            menuButton.setTitle("Menu", for: .normal)
            paramWheelMin = 0
            paramWheelMax = Float(Float(selectedVoice.getParamCount() - 1))
            resetKnobToNewValues(kval: knobValue ,kmin:paramWheelMin ,kmax: paramWheelMax)
        } //end param select
        paramKnob.setKnobBitmap(bname: knobName)
    } //end updateWheelAndParamButtons


    //=======>ARKit MainVC===================================
    //Param knob change...
    @IBAction func paramChanged(_ sender: Any) {
        knobValue = paramKnob.value //Assume value is pre-clamped to range
        if knobMode == KnobStates.SELECT_PARAM //select param  9/13 changes
        {
            let ikv = Int(knobValue)
            if ikv != oldKnobInt //1/14 only react to int steps!
            {
                fbgenerator.prepare() // 1/14 haptics
                fbgenerator.selectionChanged()
                selectedField = ikv  //1/14
                if whatWeBeEditing == "voice"  {loadCurrentVoiceParams()} //10/18
                if whatWeBeEditing == "shape"  {loadCurrentShapeParams()} //10/18
                if whatWeBeEditing == "pipe"   {loadCurrentPipeParams()} //12/1
                updateSelectParamName()
            }
            oldKnobInt = ikv
        }
        else //edit param
        {
            //12.2 add haptics feedback on knob change
            if  oldKnobValue !=  paramKnob.value  //new param?
            {
                fbgenerator.prepare()
                fbgenerator.selectionChanged()
            }
            let fname = selectedFieldName.lowercased()
            setNewParamValue(fname: fname,newval: knobValue) //11/25
        } //end else
        oldKnobValue = paramKnob.value //12/2 move to bottom

    } //end paramChanged

    
    //=======>ARKit MainVC===================================
    // Move object-related chunks to proper objects!
      //=======>ARKit MainVC===================================
       // Move object-related chunks to proper objects!
       func getLastParamValue(fname : String)
       {
           if whatWeBeEditing == "voice" // get last param for voice/marker...
           {
               switch (fname)  //10/9 cleanup
               {
               case "latitude":  lastFieldDouble = selectedVoice.OVS.yCoord
               case "longitude": lastFieldDouble = selectedVoice.OVS.xCoord
               case "type":      lastFieldDouble = Double(selectedVoice.OOP.type)    //DHS 10/13
               lastFieldPatch  = selectedVoice.OOP //DHS 10/15
               case "patch":     lastFieldPatch  = selectedVoice.OOP
               //10/14 get patch index in array of names too!
               let pname = selectedVoice.OVS.patchName.lowercased()
               lastFieldDouble = 0.0
               if let pindex = selectedFieldStringVals.index(of:pname)
               {
                   lastFieldDouble = Double(pindex)
                   }
               case "scale":     lastFieldDouble = Double(selectedVoice.OVS.keySig)
               case "level":     lastFieldDouble = selectedVoice.OVS.level
               case "nchan":     lastFieldDouble = Double(selectedVoice.OVS.noteMode)
               case "vchan":     lastFieldDouble = Double(selectedVoice.OVS.volMode)
               case "pchan":     lastFieldDouble = Double(selectedVoice.OVS.panMode)
               case "nfixed":    lastFieldDouble = Double(selectedVoice.OVS.noteFixed)
               case "pfixed":    lastFieldDouble = Double(selectedVoice.OVS.panFixed)
               case "vfixed":    lastFieldDouble = Double(selectedVoice.OVS.volFixed)
               case "topmidi":   lastFieldDouble = Double(selectedVoice.OVS.topMidi)
               case "bottommidi":  lastFieldDouble = Double(selectedVoice.OVS.bottomMidi)
               case "midichannel": lastFieldDouble = Double(selectedVoice.OVS.midiChannel)
               case "name":      lastFieldString = selectedVoice.OVS.name    //2/4
               case "comment":   lastFieldString = selectedVoice.OVS.comment //2/4
               selectedMarker.updatePanels(nameStr: selectedVoice.OVS.name)  //10/11
               default:print("Error:Bad voice param")
               }
           } //end whatWeBeEditing
           else if whatWeBeEditing == "shape" // get last param for shape...
           {
               switch (fname)
               {
               case "texture" : lastFieldString = selectedShape.OOS.texture
               case "rotation": lastFieldDouble = selectedShape.OOS.rotSpeed
               case "rotationtype": lastFieldDouble = selectedShape.OOS.rotation
               case "xpos": lastFieldDouble = selectedShape.OOS.xPos
               case "ypos": lastFieldDouble = selectedShape.OOS.yPos
               case "zpos": lastFieldDouble = selectedShape.OOS.zPos
               case "texxoffset": lastFieldDouble = selectedShape.OOS.uCoord
               case "texyoffset": lastFieldDouble = selectedShape.OOS.vCoord
               case "texxscale": lastFieldDouble = selectedShape.OOS.uScale
               case "texyscale": lastFieldDouble = selectedShape.OOS.vScale
               case "name":      lastFieldString = selectedShape.OOS.name    //2/4
               case "comment":   lastFieldString = selectedShape.OOS.comment //2/4
               default:print("Error:Bad shape param")
               }
           }
           else if whatWeBeEditing == "pipe" // get last param for pipe...
           {
               var getNumberedDisplayValue = false
               var pstr = ""
               switch (fname) //12/1 ouch!!! we need to set lastFieldDouble for multipoe chyoices!
               {
               case "inputchannel":
                   pstr = selectedPipe.PS.fromChannel
                   lastFieldString = pstr  //1/26
                   getNumberedDisplayValue = true
               case "outputparam":
                   pstr = selectedPipe.PS.toParam
                   lastFieldString = pstr  //1/26
                   getNumberedDisplayValue = true
               case "lorange" : // 12/9 add lo/hi range as strings
                   let lorg = selectedPipe.PS.loRange
                   lastFieldString = String(lorg)
               case "hirange" :
                   let horg = selectedPipe.PS.hiRange
                   lastFieldString = String(horg)
               case "name"    :
                   lastFieldString = selectedPipe.PS.name
               case "comment"    :
                   lastFieldString = selectedPipe.PS.comment
               default:print("Error:Bad pipe param")
               }
               //12/4  need to find which display value we are indicating?
               if getNumberedDisplayValue
               {
                   //12/1 NOTE: this needs to be case-sensitive. why arent displayvals lowercased?
                   if let index = selectedFieldStringVals.index(of: pstr) //1/26
                   { lastFieldDouble = Double(index) }
               }
           } //end else
       } //end getLastParamValue
    
    //=======>ARKit MainVC===================================
    // Called when a 3d shape params are changed.
    // Makes sure the 3D representation matches the data
    //  called by param set , restore, pipe data, and cancel
    func update3DShapeByName (n : String)
    {
        if let sshape3d = shapes[n] //get named SphereShape
        {
            var shapeStruct = selectedShape  //Get current shape object
            if n != selectedShapeName
            {
                shapeStruct = sceneShapes[n]!
            }
            //1/21 new struct...
            sshape3d.position = SCNVector3(shapeStruct.OOS.xPos ,shapeStruct.OOS.yPos ,shapeStruct.OOS.zPos )
            sshape3d.setTextureScaleAndTranslation(xs: Float(shapeStruct.OOS.uScale),
                                                   ys: Float(shapeStruct.OOS.vScale),
                                                   xt: Float(shapeStruct.OOS.uCoord),
                                                   yt: Float(shapeStruct.OOS.vCoord)
            )
            //10/23 pass texture scaling/offsets to bitmap object too
            sshape3d.bmp.setScaleAndOffsets(
                sx: shapeStruct.OOS.uScale, sy: shapeStruct.OOS.vScale,
                ox: shapeStruct.OOS.uCoord, oy: shapeStruct.OOS.vCoord)
        }
    } //end update3DShapeBYName

    //=======>ARKit MainVC===================================
    func paramToUnit (inval : Double) -> Double
    {
        if selectedFieldDMult == 0.0 {return 0.0}
        return (inval - selectedFieldDOffset) / selectedFieldDMult
    } //end paramToUnit
    
    //=======>ARKit MainVC===================================
    func unitToParam (inval : Double) -> Double
    {
        return (inval * selectedFieldDMult) + selectedFieldDOffset
    } //end paramToUnit
    
    //=======>ARKit MainVC===================================
    // Handles shape, voice, and pipe param changes.
    //  lots can go wrong here, maybe break this up?
    func setNewParamValue(fname : String,newval : Float )
     {
         //We only want updates if there is a new fname!
         //This logic lets the original saved param value (patch for example) be retreived
         //  if user is just rolling through the options back and forth...
         let dknobval            = Double(knobValue)
         let intChoiceChanged    = (Int(newval) != lastFieldInt)
         let backToOriginalValue = (Int(newval) == lastFieldSelectionNumber)
         var needToRefreshOriginalValue = false
         let intKnobCValue = Int((dknobval * selectedFieldDMult) + selectedFieldDOffset)
         if (backToOriginalValue != lastBackToValue)
         {
             if backToOriginalValue {needToRefreshOriginalValue = true}
         }
         //Save our old values...
         lastBackToValue = backToOriginalValue
         lastFieldInt    = Int(newval)
         
         var needRefresh = true
         var workString  = ""
         if whatWeBeEditing == "voice" //1/14  set new value for voice/marker...
         {
             var needPipeUpdate = false // 1/22 pipe must track markers!
             switch (fname)  //10/9 cleanup
             {
             case "latitude":
                 selectedVoice.OVS.yCoord = dknobval
                 selectedMarker.updateLatLon(llat: selectedVoice.OVS.yCoord, llon: selectedVoice.OVS.xCoord)
                 needPipeUpdate = true  //1/22
             case "longitude":
                 selectedVoice.OVS.xCoord = dknobval
                 selectedMarker.updateLatLon(llat: selectedVoice.OVS.yCoord, llon: selectedVoice.OVS.xCoord)
                 needPipeUpdate = true  //1/22
             case "patch":
                 if intChoiceChanged{ changeVoicePatch(name:getSelectedFieldStringForKnobValue (kv : knobValue))}
             case "type":
                 if intChoiceChanged
                 {
                     workString = getSelectedFieldStringForKnobValue (kv : knobValue)
                     changeVoiceType(typeString:workString , needToRefreshOriginalValue: needToRefreshOriginalValue)
                     selectedMarker.updateTypeString(newType : workString)
                 }
             case "key":
                 if intChoiceChanged{
                     selectedVoice.OVS.pitchShift = Int(knobValue) % 12
                 }
             case "scale":
                 if intChoiceChanged{
                     selectedVoice.OVS.keySig = Int(knobValue)
                 }
             case "level":  selectedVoice.OVS.level      = dknobval
             case "nchan":  selectedVoice.OVS.noteMode   = Int(knobValue)
             case "vchan":  selectedVoice.OVS.volMode    = Int(knobValue)
             case "pchan":  selectedVoice.OVS.panMode    = Int(knobValue)
             case "nfixed": selectedVoice.OVS.noteFixed  = intKnobCValue
             case "vfixed": selectedVoice.OVS.volFixed   = intKnobCValue
             case "ofixed": selectedVoice.OVS.panFixed   = intKnobCValue
             case "bottommidi":
                 let workInt = Int(unitToParam(inval: dknobval))
                 selectedVoice.OVS.bottomMidi = min(selectedVoice.OVS.topMidi-1,workInt)
             case "topmidi":
                 let workInt = Int(unitToParam(inval: dknobval))
                 selectedVoice.OVS.topMidi = max(selectedVoice.OVS.bottomMidi+1,workInt)
             case "midichannel":
                 selectedVoice.OVS.midiChannel = Int(unitToParam(inval: dknobval))
             case "name": selectedVoice.OVS.name = lastFieldString
                 selectedMarker.updatePanels(nameStr: selectedVoice.OVS.name)  //10/11
             case "comment": selectedVoice.OVS.comment = lastFieldString  //2/4
             default: needRefresh = false
             } //end switch
            if needPipeUpdate && !updatingPipe { updatePipeByVoice(v:selectedVoice) } //1/31 prevent crash?
         } //end voice edit
         else if whatWeBeEditing == "shape"  //1/14  set new value for shape...
         {
             var needUpdate = true
             var newSpeed   = false
             switch (fname)
             {
             case "texture"     : selectedShape.OOS.texture = lastFieldString //WTF?? TBD
                 print("new tex \(lastFieldString)")
                 needUpdate = false
             case "rotation"    : selectedShape.OOS.rotSpeed = dknobval
                 needUpdate = false
                 newSpeed   = true
             case "rotationtype": selectedShape.OOS.rotation = dknobval
                 setRotationTypeForSelectedShape()
                 newSpeed   = true
             case "xpos"        : selectedShape.OOS.xPos   = dknobval
             case "ypos"        : selectedShape.OOS.yPos   = dknobval
             case "zpos"        : selectedShape.OOS.zPos   = dknobval
             case "texxoffset"  : selectedShape.OOS.uCoord = dknobval
             case "texyoffset"  : selectedShape.OOS.vCoord = dknobval
             case "texxscale"   : selectedShape.OOS.uScale = dknobval
             case "texyscale"   : selectedShape.OOS.vScale = dknobval
             case "name"        : selectedShape.OOS.name   = lastFieldString  //2/4
             case "comment"     : selectedShape.OOS.comment = lastFieldString  //2/4
             default: needRefresh = false
             }
             if needUpdate { update3DShapeByName (n:selectedShapeName) }
             if newSpeed   { setRotationSpeedForSelectedShape(s : selectedShape.OOS.rotSpeed)}
         }
         else if whatWeBeEditing == "pipe" //1/14 set new value for pipe...
         {
             var needUpdate = true
             var iknob = Int(dknobval)
             var pdv :Double = 0.0
             if let dogDouble = Double(lastFieldString)
             {
                 pdv = dogDouble
             }
             switch (fname)
             {
             case "inputchannel" : iknob = min(iknob,InputChanParams.count-2)
                                   let icp = InputChanParams[iknob+2] as! String
                                   selectedPipe.PS.fromChannel = icp
             case "outputparam" :   //ugggh! this is complex! lots of param resets needed here
                 var menuNames = voiceParamNamesOKForPipe
                 if selectedPipe.destination == "shape" {menuNames = shapeParamNamesOKForPipe}
                 iknob         = min(iknob,menuNames.count-1) //Double check range to avoid crash
                 let opp       = menuNames[iknob]
                 let opChanged = (opp != selectedPipe.PS.toParam) //1/14 changed?
                 selectedPipe.PS.toParam = opp
                 // DHS 1/14 Change? reload any targeted pipe shape w old scene settings!
                 if opChanged //1/14 need resettin'
                 {
                     let shapeOrVoiceName = selectedPipe.PS.toObject
                     if selectedPipe.destination == "voice"   //1/14
                     {
                         resetVoiceByName(name: shapeOrVoiceName)
                     }
                     else if selectedPipe.destination == "shape"   //1/14
                     {
                         resetShapeByName(name: shapeOrVoiceName)  //Reset shape object from scene
                     }
                     print(" bing! reset voice/shape  \(selectedPipe.PS.toObject)")
                 }
                 //Need to get fresh pipe range! (what about edits, they get lost!)
                 let loHiRange = getPipeRangeForParamName(pname:selectedPipe.PS.toParam.lowercased(),
                                                           dest:selectedPipe.destination)
                 selectedPipe.setupRange(lo: loHiRange.lo, hi: loHiRange.hi) //1/14 REDO

             case "lorange"      : selectedPipe.PS.loRange        = pdv
             case "hirange"      : selectedPipe.PS.hiRange        = pdv
             case "name"         : selectedPipe.PS.name           = lastFieldString
             case "comment"      : selectedPipe.PS.comment        = lastFieldString
             default: needUpdate = false
             }
             if needUpdate
             {
                 //12/5 NOTE pipe name may be different! but objects are still indexed by name!
                 if let popj = pipes[selectedPipeName] //12/5 USE SCENE-LOADED NAME!
                 {
                     //12/5 update pipe label and graphfff
                         popj.updateInfo(nameStr: selectedPipe.PS.name, vals: selectedPipe.ibuffer)
                                     popj.pipeColor = popj.getColorForChan(chan: selectedPipe.PS.fromChannel)
                                     pipes[selectedPipeName] = popj
                 }
             }
         }
         
         if needRefresh
         {
             //Update top label: is this the right place for this?
             var pstring = fname + " = "
             if selectedFieldType == "double"
             {
                 let displayValue = selectedFieldDMult * dknobval +
                     selectedFieldDOffset //9/17 display value differs from knob value
                 //print("knobv \(knobValue) dv \(displayValue)  dmult \(selectedFieldDMult)   dmult \(selectedFieldDMult)  doff \(selectedFieldDOffset)")
                 pstring = pstring + String(format: "%4.2f", displayValue)
                 pLabel.updateit(value: displayValue) //DHS 9/28 new display
             }
             else
             {
                 pstring = pstring + workString
                 pLabel.updateit(value: dknobval) //DHS 9/28 new display
             }
         } //end needRefresh
     } //end setNewParamValue

    //=======>ARKit MainVC===================================
    // 10/29 types: manual, BPMX1..8
    func setRotationTypeForSelectedShape()
    {
        var rspeed = 8.0
        var irot = Int(selectedShape.OOS.rotation)
        if irot > 0
        {
            if irot > 8 {irot = 8}
            rspeed = 60.0 / Double(OVtempo) //time for one beat
            //11/23 change rotation speed mapping
            rspeed = rspeed * 1.0 * Double(irot) //4/4 timing, apply rot type
        }
        //OK set up rotation
        setRotationSpeedForSelectedShape(s : rspeed)
    } //end setRotationTypeForSelectedShape
    
    //=======>ARKit MainVC===================================
    func setRotationSpeedForSelectedShape(s : Double)
    {
        if let sshape = shapes[selectedShapeName]
        {
            selectedShape.OOS.rotSpeed = s
            sshape.setTimerSpeed(rs: selectedShape.OOS.rotSpeed)
        }
    } //end setRotationSpeedForSelectedShape
    
    //=======>ARKit MainVC===================================
    // Looks up a synth patch, changes current voice
    func changeVoicePatch(name:String)
    {
        let sPatch = allP.getPatchByName(name: name)
        selectedVoice.OOP = sPatch //take oogiePatch, attach to voice
        selectedVoice.OVS.patchName = sPatch.name //10/14 save name to voice too!
        self.setupSynthOrSample(oov: selectedVoice); //More synth-specific stuff
    }

    //=======>ARKit MainVC===================================
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
    

    //=======>ARKit MainVC===================================
    // 12/1 make generic for all types of params...
    func editParams(v:String)
    {
        whatWeBeEditing = v
        selectedField = 0
        knobMode = KnobStates.SELECT_PARAM
        updateWheelAndParamButtons()
        var choiceStrings : [String] = []
        switch(v)
        {
            case  "voice" : loadCurrentVoiceParams()
                            choiceStrings = voiceParamNames
            case  "shape" : loadCurrentShapeParams()
                            choiceStrings = shapeParamNames
            case  "pipe"  : loadCurrentPipeParams()
                            choiceStrings = pipeParamNames
            default: return; //Bail on bad type
        }
        pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
            pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
            choiceStrings : choiceStrings)
        pLabel.showWarnings  = false
        paramKnob.wraparound = true
    } //end editParams
    
    
    //=======>ARKit MainVC===================================
    // Move each object-based chunk to appropriate object!
    func restoreLastParamValue(oldD : Double , oldS : String)
    {
        let fname = selectedFieldName.lowercased()
        if whatWeBeEditing == "voice" //10/18
        {
            switch (fname)  //which param?
            {
            case "latitude":    selectedVoice.OVS.yCoord      = oldD
            case "longitude":   selectedVoice.OVS.xCoord      = oldD
            case "type":        selectedVoice.OOP.type        = Int(oldD)
            case "patch":       selectedVoice.OOP             = lastFieldPatch
            case "scale":       selectedVoice.OVS.keySig      = Int(oldD)
            case "level":       selectedVoice.OVS.level       = oldD
            case "nchan":       selectedVoice.OVS.noteMode    = Int(oldD)
            case "vchan":       selectedVoice.OVS.volMode     = Int(oldD)
            case "pchan":       selectedVoice.OVS.panMode     = Int(oldD)
            case "nfixed":      selectedVoice.OVS.noteFixed   = Int(oldD)
            case "pfixed":      selectedVoice.OVS.panFixed    = Int(oldD)
            case "vfixed":      selectedVoice.OVS.volFixed    = Int(oldD)
            case "topmidi":     selectedVoice.OVS.topMidi     = Int(oldD)
            case "bottommidi":  selectedVoice.OVS.bottomMidi  = Int(oldD)
            case "midichannel": selectedVoice.OVS.midiChannel = Int(oldD)
            case "name":        selectedVoice.OVS.name        = oldS  //2/4
            case "comment":     selectedVoice.OVS.comment     = oldS  //2/4
            default: print("restoreLastParam: bad voice ptype")
            }
        } //end voice
        else if whatWeBeEditing == "shape"
        {
            var needUpdate = true
            var newSpeed   = false
            switch (fname)
            {
            case "texture" : selectedShape.OOS.texture  = oldS
                needUpdate = false
            case "rotation": selectedShape.OOS.rotSpeed =  oldD
                needUpdate = false
                newSpeed   = true
            case "rotationtype": selectedShape.OOS.rotation = oldD
                needUpdate = false
                newSpeed   = true
            case "xpos":       selectedShape.OOS.xPos = oldD
            case "ypos":       selectedShape.OOS.yPos = oldD
            case "zpos":       selectedShape.OOS.zPos = oldD
            case "texxoffset": selectedShape.OOS.uCoord = oldD
            case "texyoffset": selectedShape.OOS.vCoord = oldD
            case "texxscale":  selectedShape.OOS.uScale = oldD
            case "texyscale":  selectedShape.OOS.vScale = oldD
            case "name":       selectedShape.OOS.name   = oldS  //2/4
            case "comment":    selectedShape.OOS.comment = oldS //2/4
            default: print("restoreLastParam: bad shape ptype")
            }
            if needUpdate { update3DShapeByName (n:selectedShapeName) }
            if newSpeed   { setRotationSpeedForSelectedShape(s : selectedShape.OOS.rotSpeed)}
        } //end shape
        else if whatWeBeEditing == "pipe" //1/26 forgot this!
        {
            switch (fname)
            {
            case "inputchannel": selectedPipe.PS.fromChannel  = oldS
            case "outputparam" :  selectedPipe.PS.toParam     = oldS
            case "lorange"     :     selectedPipe.PS.loRange  = oldD
            case "hirange"     :     selectedPipe.PS.hiRange  = oldD
            case "name"        :     selectedPipe.PS.name     = oldS
            case "comment"     :     selectedPipe.PS.name     = oldS
            default: print("restoreLastParam: bad pipe ptype")
            }
            //Note this is a duplicate of code in restoreLastParamValue
            let shapeOrVoiceName = selectedPipe.PS.toObject
            if selectedPipe.destination == "voice"   //1/14
            {
                resetVoiceByName(name: shapeOrVoiceName)
            }
            else if selectedPipe.destination == "shape"   //1/14
            {
                resetShapeByName(name: shapeOrVoiceName)  //Reset shape object from scene
            }
            //Need to get fresh pipe range! (what about edits, they get lost!)
            let loHiRange = getPipeRangeForParamName(pname:selectedPipe.PS.toParam.lowercased(),
                                                      dest:selectedPipe.destination)
            selectedPipe.setupRange(lo: loHiRange.lo, hi: loHiRange.hi) //1/14 REDO
            //End duplicate area

        } //end pipe

    } //end restoreLastParamValue
    
    //=======>ARKit MainVC===================================
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
                let ppp = allP.getPatchByName(name: nnnn)
                print("  ...reloading patch\(nnnn)")
                voice.OOP         = ppp   //reset voice patch, and save back to scene dictionary
                sceneVoices[name] = voice
            } //end if namez
        }    //end for
    } //end reloadAllPatchesInScene
    
    //=======>ARKit MainVC===================================
    // called every time user switches param with the wheel...
    //  loads in an array of param limits, names, whatever,
    //   and preps for param editing
    func loadCurrentVoiceParams()
    {
        if (selectedField < 0) {return}
        var vArray = [Any]()
        if selectedField != 3 //All params but patches are canned: CLUGEY use of hardcoded value!
        { //load them here
            vArray = selectedVoice.getNthParams(n: selectedField)
        }
        else  //Get approp patches
        {
           vArray = selectedVoice.getPatchNameArray() //Get patches for synth, drums, etc based on type
        }
        print("varray \(vArray) count \(vArray.count)")
        if (vArray.count < 3) {return} //avoid krash
        selectedFieldName = vArray[0] as! String
        selectedFieldType = vArray[1] as! String
        let sfname = selectedFieldName.lowercased()  //type, patch, etc...
        if selectedFieldType == "double" && vArray.count > 6 //Get double range / default
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
                let yuserPatches = allP.getUserPatchesForVoiceType(type: selectedVoice.OOP.type)
                //print("got uptch type\(selectedVoice.OOP.type) \(yuserPatches)")
                for (name,_) in yuserPatches  //for each, add to string / display arrays
                {
                    selectedFieldStringVals.append(name)
                    selectedFieldDisplayVals.append(name)
                }
            }
            for i in 2...vArray.count-1 //OK add more fields from params or built-in filenames
            {
                let fname = vArray[i] as! String
                selectedFieldStringVals.append(fname)
                //10/26 handle GM SAMPLE patches specially..
                if sfname == "patch" &&
                    selectedVoice.OOP.type == SAMPLE_VOICE
                {
                    selectedFieldDisplayVals.append( //try to get instrument name...
                        allP.getInstrumentNameFromGMFilename(fname: fname))
                }
                else // non-patches, just display the field strings
                { selectedFieldDisplayVals.append(fname) }
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
        getLastParamValue(fname : selectedFieldName.lowercased()) //10/12 Load up current param
        //print("sfsv \(selectedFieldStringVals)   sfdv \(selectedFieldDisplayVals)")
    } //end loadCurrentVoiceParams
    
   
    
    //=======>ARKit MainVC===================================
    // 10/18 almost identical to loadCurrentVoiceParams,
    //  maybe merge later?
    func loadCurrentShapeParams()
    {
        if (selectedField < 0) {return}
        var vArray = [Any]()
        vArray = selectedShape.OOS.getNthParams(n: selectedField) //1/21
        breakOutSelectedFields(vArray: vArray)
    } //end loadCurrentShapeParams

    //=======>ARKit MainVC===================================
    // 12/1 add pipe edit
    func loadCurrentPipeParams()
    {
        if (selectedField < 0) {return}
        var vArray = selectedPipe.getNthParams(n: selectedField)
        if selectedField == 1 //String field: output param name
        {
            if vArray.count == 3 {vArray.remove(at: 2)} //Get rid of trailer
            //append shape/voice/etc parameters....
            if selectedPipe.destination == "shape" {vArray = vArray + shapeParamNamesOKForPipe }
            else                                   {vArray = vArray + voiceParamNamesOKForPipe }
        }
        breakOutSelectedFields(vArray: vArray)
    } //end loadCurrentPipeParams

    //=======>ARKit MainVC===================================
    // 12/1 why cant this work for voices?
    func breakOutSelectedFields(vArray : [Any])
    {
        if (vArray.count < 3) {return} //avoid krash
        selectedFieldName = vArray[0] as! String
        selectedFieldType = vArray[1] as! String
        if selectedFieldType == "double" && vArray.count > 6 //Get double range / default
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
        getLastParamValue(fname : selectedFieldName.lowercased()) //10/12 Load up current param
    } //end breakOutSelectedFields
    
    //=======>ARKit MainVC===================================
    //1/22 updates pipes going FROM a voice,
    //  bool updatingPipe prevents redundant calls
    func updatePipeByVoice(v:OogieVoice)
    {
        updatingPipe = true
        for puid in v.outPipes //look at output pipes
        {
	       if let n = pipeUIDToName[puid]                // get pipes name
            {
                if let pipeObj = scenePipes[n]           //   find pipe struct
                    {
                        addPipeNode(oop: pipeObj, newNode : false) //1/30
                        let vals = pipeObj.ibuffer //11/28 want raw unscaled here!
                        if let pipe = pipes[n]    // get Pipe 3dobject itself to restore texture
                        {
                            pipe.texturePipe(phase:0.0 , chan: pipeObj.PS.fromChannel.lowercased(),
                                               vals: vals, vsize: vals.count , bptr : pipeObj.bptr)
                        }
                    }
            }
        }
        updatingPipe = false
    } //end updatePipeByVoice
    
    //=======>ARKit MainVC===================================
    // updates param display w/ current param and value
    func updateSelectParamName()
    {
        let dogStrings = ["nfixed","vfixed","pfixed","topmidi","bottommidi","midichannel"]
        //12/2 add haptics feedback on knob change
        if  selectedFieldName != oselectedFieldName  //new param?
        {
            fbgenerator.prepare()
            fbgenerator.selectionChanged()
            oselectedFieldName = selectedFieldName
        }

        var infoStr = selectedFieldName
        var pstr    = ""
        if selectedFieldType == "double"
        {
            var dval = unitToParam(inval: lastFieldDouble)
            //some fields don't need converting
            if  dogStrings.contains( selectedFieldName.lowercased())
            {
                dval = lastFieldDouble;
            }
            pstr = String(format: "%4.2f", dval) //10/24 wups was int!
        }
        else if selectedFieldType == "string"
        {
            let index = Int(lastFieldDouble)
            //10/19 prevent crash on bad display values
            if index < selectedFieldDisplayVals.count
            {
                //print("lfd \(lastFieldDouble) vals count \(selectedFieldDisplayVals.count)")
                //print("displayvals \(selectedFieldDisplayVals)")
                pstr = selectedFieldDisplayVals[Int(lastFieldDouble)]  //10/19 wups forgot
            }
        }
        else if selectedFieldType == "text" //10/9 new field type
        {
            //12/5 DUH what kinda edit we be doin?
            if whatWeBeEditing == "voice"    //2/3 handle name/comment
            {
                switch(selectedFieldName.lowercased())
                {
                    case "name"    : pstr = selectedVoice.OVS.name //2/3 new
                    case "comment" : pstr = selectedVoice.OVS.comment
                    default        : pstr = "empty"
                }
            }
            else if whatWeBeEditing == "shape"    //2/3 handle name/comment
            {
                switch(selectedFieldName.lowercased())
                {
                    case "name"    : pstr = selectedShape.OOS.name //2/3 new
                    case "comment" : pstr = selectedShape.OOS.comment
                    default        : pstr = "empty"
                }
            }
            else if whatWeBeEditing == "pipe"
            {
                //12/9 which to handle? name, lo/hi ranges...
                switch(selectedFieldName.lowercased())
                {
                    case "lorange" : pstr = lastFieldString
                    case "hirange" : pstr = lastFieldString
                    case "name"    : pstr = selectedPipe.PS.name //2/3 new
                    case "comment" : pstr = selectedPipe.PS.comment
                    default        : pstr = "empty"
                }
            }
        }
        else if selectedFieldType == "texture" //10/9 new field type
        {
            pstr = selectedShape.OOS.texture //10/22 is this the only texture?
        }
        infoStr = selectedFieldName + ":" + pstr

        pLabel.updateLabelOnly(lStr: infoStr)
    } //end updateSelectParamName
    
    
    //=======>ARKit MainVC===================================
    // 10/17 there isnt a real double-tap detector, so instead
    //  we will use touchesMoved to put up a popup for the marker...
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        latestTouch = touch
        getCamXYZ() //11/24 Save new 3D cam position
    } //end touchesMoved
    
    //=======>ARKit MainVC===================================
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDown = false
    }
    
    //=======>ARKit MainVC===================================
    // Used to select items in the AR 3D world...
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        latestTouch = touch
        touchDown = false
        handleTouch(touch: touch)
    } //end touchesBegan
    
    //=====<oogie2D mainVC>====================================================
    //10/29 called by touchesDown
    func handleTouch(touch:UITouch)
    {
        //  user selects object they are long touching on!
        // Make all of this a subroutine called handleTouches!!!
        guard let sceneView   = skView else {return}
        touchLocation  = latestTouch.location(in: sceneView)
        guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
        let hitNode    = nodeHitTest.node
        var bailOnEdit = false
        var deselected = false
        if let name = hitNode.name
        {
            if name.contains("shape") //Found a shape? get which one
            {
                let testName = findShape(uid: name)
                if (testName != "")
                {
                    unselectAnyOldStuff(name: testName) //11/30
                    if let testShape = shapes[testName] //1/26
                    {
                        selectedShapeName = testName
                        selectedSphere    = testShape
                        selectedSphere.toggleHighlight()
                        //Wow is this redundant?
                        if selectedSphere.highlighted  //hilited? Set up edit
                        {
                            self.pLabel.updateLabelOnly(lStr:"Selected " + self.selectedSphere.name!)
                            if let smname = selectedSphere.name
                            {
                                if let testShape = sceneShapes[smname] //got legit voice?
                                {
                                    selectedShape     = testShape
                                    selectedShapeName = smname //10/21
                                    //2/3 add name/comment to 3d shape info box
                                    selectedSphere.updatePanels(nameStr: selectedShape.OOS.name,
                                                                   comm: selectedShape.OOS.comment)
                                    editParams(v: "shape") //this also update screen
                                }
                            }
                        }
                        else //unhighlighted?
                        {
                            bailOnEdit = true //1/26 redo
                            deselected = true
                        }
                    }
                } //end selectedobjectindex...
            } //end name... shape
            else if name.contains("marker") //Found a marker? get which one
            {
                selectedObjectIndex = findMarker(uid: name)
                if (selectedObjectIndex != -1)
                {
                    let newMarker = allMarkers[selectedObjectIndex]
                    unselectAnyOldStuff(name:newMarker.name!) //11/30
                    selectedMarker = newMarker           // get our marker...
                    selectedMarker.toggleHighlight()
                    if selectedMarker.highlighted  //hilited? Set up edit
                    {
                        if let smname = selectedMarker.name
                        {
                            //DHS 1/16:this looks to get OLD values not edited values!
                            if let testVoice = sceneVoices[smname] //got legit voice?
                            {
                                self.pLabel.updateLabelOnly(lStr:"Selected " + smname)
                                selectedVoice = testVoice //Get associated voice for this marker
                                selectedMarkerName = smname //points to OVS struct in scene
                                selectedMarker.updatePanels(nameStr: selectedMarkerName) //10/11 add name panels
                                //1/14 was redundantly pulling OVS struct from OVScene.voices!
                                editParams(v: "voice") //1/14 switch to edit mode
                            }
                        } //end if let
                    }
                    else
                    {
                        bailOnEdit = true  //1/26 redo
                        deselected = true
                    }
                } //end if selected...
            } //end if name
            else if name.contains("pipe") //Found a pipe? get which one
            {
               let pipeName = findPipe(uid: name)
                if let sp = pipes[pipeName]
                 {
                     selectedPipeShape = sp
                     unselectAnyOldStuff(name:pipeName) //11/30
                     selectedPipeName = pipeName
                     selectedPipeShape.toggleHighlight()
                     if let spo = scenePipes[pipeName] //now get pipe record...
                     {
                         selectedPipe = spo // get 3d scene object...
                         //Beam pipe name and output buffer to a texture in the pipe...
                         // ideally this should be updaged on a timer!
                         selectedPipeShape.updateInfo(nameStr: pipeName, vals: spo.ibuffer)
                        if selectedPipeShape.highlighted  //hilited? Set up edit
                        {
                            self.pLabel.updateLabelOnly(lStr:"Selected " + pipeName)
                            editParams(v:"pipe") //this also update screen
                        }
                        else
                        {
                            bailOnEdit = true //1/26 redo
                            deselected = true
                        }
                     }
                 }
            }
        }    // end if let name
        if bailOnEdit
        {
            cancelEdit() //DHS 11/3 if editing, cancel
            whatWeBeEditing = ""
        }
        if deselected
        {
            updateUIForDeselectVoiceOrShape()
        }

    } //end handleTouch
    
    //=====<oogie2D mainVC>====================================================
    // called when user selects something, unhighlights old crap
    func unselectAnyOldStuff(name:String)
    {
        if whatWeBeEditing == "voice"
        {
            //selectedMarker.unHighlight()
            // is a different marker selected? deselect!
            if  selectedMarker.highlighted &&
                 selectedMarkerName != name
                { selectedMarker.unHighlight() }
            selectedMarkerName = ""
        }
        else if whatWeBeEditing == "shape"
        {
            //selectedSphere.unHighlight()
            if selectedSphere.highlighted &&
                selectedShapeName != name
                { selectedSphere.unHighlight() }
            selectedShapeName = ""
        }
        else if whatWeBeEditing == "pipe"
        {
            //selectedPipeShape.unHighlight()
            if selectedPipeShape.highlighted &&
                selectedPipeName != name
                { selectedPipeShape.unHighlight() }
            selectedPipeName = ""
        }

       // if selectedSphere.highlighted && selectedShapeName != testName

    } //end unselectAnyOldStuff
    

    //=====<oogie2D mainVC>====================================================
    func updateUIForDeselectVoiceOrShape()
    {
        paramKnob.isHidden      = true
        editButtonView.isHidden = true
    }
    
    
    
    
    //=====<oogie2D mainVC>====================================================
    @objc func synthXClicked(sender : UIButton){
        spnl.isHidden = true
// 9/7 redo       OV = spnl.OV
        //THIS RANDOMIZES!!! OV.loadSynthPatch(voice: 0, which: 0); //patch-specific stuff
// 9/7 redo        setupSynthOrSample(); //More synth-specific stuff
    }
    
    //=====<oogie2D mainVC>====================================================
    func menu()
    {
        let tstr = "Menu (V" + version + ")"
        // 11/25 add big dark title
        let attStr = NSMutableAttributedString(string: tstr)
        attStr.addAttribute(NSAttributedStringKey.font, value: UIFont.boldSystemFont(ofSize: 25), range: NSMakeRange(0, attStr.length))
        let alert = UIAlertController(title: tstr, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.setValue(attStr, forKey: "attributedTitle")
        alert.view.tintColor = UIColor.black //lightText, works in darkmode
        alert.addAction(UIAlertAction(title: "Load Scene", style: .default, handler: { action in
            self.chooserMode = "load" //11/22
            self.performSegue(withIdentifier: "chooserLoadSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene", style: .default, handler: { action in
            self.packupSceneAndSave(sname:self.OVSceneName)
            self.pLabel.updateLabelOnly(lStr:"Saved " + self.OVSceneName)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene As...", style: .default, handler: { action in
            self.chooserMode = "save" //11/22
            self.performSegue(withIdentifier: "chooserSaveSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Patch Editor", style: .default, handler: { action in
            self.performSegue(withIdentifier: "EditPatchSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Clear Scene", style: .default, handler: { action in
            self.clearScenePrompt()
        }))
        alert.addAction(UIAlertAction(title: "Textures...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "textureSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Dump Scene", style: .default, handler: { action in
            self.OVScene.dump()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end menu
    
    
    //=====<oogie2D mainVC>====================================================
    // voice popup... various functions
    func voiceMenu()
    {
        let alert = UIAlertController(title: self.selectedVoice.OVS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)

            alert.addAction(UIAlertAction(title: "Edit this Patch...", style: .default, handler: { action in
                self.performSegue(withIdentifier: "EditPatchSegue", sender: self)
        }))

        var tstr = "Solo"
        if soloVoiceID != "" {tstr = "UnSolo"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            if self.soloVoiceID == ""
            {
                self.soloVoiceID = self.selectedVoice.uid
            }
            else
            {
                self.soloVoiceID = ""
            }
            self.selectedMarker.toggleHighlight()
            self.updateUIForDeselectVoiceOrShape()
        }))

        tstr = "Mute"
        if selectedVoice.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            self.selectedVoice.muted = !self.selectedVoice.muted
            self.selectedMarker.toggleHighlight()
            self.updateUIForDeselectVoiceOrShape()
        }))
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.selectedVoice.OVS, name: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete...", style: .default, handler: { action in
           self.deleteVoicePrompt(voice: self.selectedVoice)
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            let name = self.selectedVoice.OVS.name
            self.resetVoiceByName(name: name)  //1/14 Reset shape object from scene
            var index = 0; //point to allMarkers so we can modify!
            for marker in self.allMarkers   //look for our marker by name, update 3d representation and save!
            {
                if marker.name == name
                {
                    marker.updateLatLon(llat: self.selectedVoice.OVS.yCoord, llon: self.selectedVoice.OVS.xCoord)
                    self.allMarkers[index] = marker
                    break //get outta here!
                }
                index+=1;
            } //end for marker
        }))
        alert.addAction(UIAlertAction(title: "Add Pipe...", style: .default, handler: { action in
           self.addPipeStepOne(voice: self.selectedVoice)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end voiceMenu
    
    //=====<oogie2D mainVC>====================================================
    // operations available to selected shape...
    func shapeMenu()
    {
        let alert = UIAlertController(title: self.selectedShape.OOS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addShapeToScene(shape: self.selectedShape.OOS, name: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShapePrompt(shape: self.selectedShape.OOS)
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            let newName = "voice" + String(format: "%03d", 1 + self.sceneVoices.count)
            self.addVoiceToScene(nextOVS: self.selectedVoice.OVS, name: newName, op: "new")
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            self.resetShapeByName(name: self.selectedShape.OOS.name)  //Reset shape object from scene
            self.update3DShapeByName(n:self.selectedShape.OOS.name)  //Ripple change thru to 3D
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end shapeMenu

    //=====<oogie2D mainVC>====================================================
    // 11/30 pipe menu options
    func pipeMenu()
    {
        let alert = UIAlertController(title: self.selectedPipe.PS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Delete Pipe...", style: .default, handler: { action in
            self.deletePipePrompt(pipe: self.selectedPipe)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end pipeMenu

    
    //=====<oogie2D mainVC>====================================================
    func deleteShapePrompt(shape:OSStruct)
    {
        print("Delete Shape... \(shape.name)")
        let alert = UIAlertController(title: "Delete Selected Shape?", message: "Shape will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.deleteShape(shape: shape)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteShapePrompt
    
    //=====<oogie2D mainVC>====================================================
    // 10/26 removes shape from scene / SCNNode
    func deleteShape(shape:OSStruct)
    {
        let name = shape.name
        if let shape3D = shapes[name]
        {
            shape3D.removeFromParentNode()    //Blow away 3d Shape
            shapes.removeValue(forKey: name) // delete of dict entries
            if let shapeNode = sceneShapes[name] //Get rid of any pipes!
            {
                if shapeNode.inPipes.count > 0
                {
                    for puid in shapeNode.inPipes
                    {
                        print("pipeuid \(puid)")
                        deletePipeByUID(puid: puid, nodeOnly : false)
                    }
                }
            }
            sceneShapes.removeValue(forKey: name)
        }
    } //end deleteShape
    
    //=====<oogie2D mainVC>====================================================
    // 1/21 when a pipe source or destination is deleted, the pipe must go too...
    //   uid is best because pipe name may have changed
    func deletePipeByUID( puid : String , nodeOnly : Bool)
    {
        if let name = pipeUIDToName[puid]
        {
            //print ("scnpc \(scenePipes.count)")
            // 1/22 delete pipes data?
            if !nodeOnly {
                cleanupPipeInsAndOuts(name:name)         // 1/22 cleanup ins and outs...
                //print("delete scenepipe \(name)")
                scenePipes.removeValue(forKey: name)
            }       // Get rid of pipeObject
            // Always get rid of pipe 3D node
            print("deletePipeByUID \(name)")
            if let pipe3D = pipes[name]
            {
                //print(".....delete3d pipe");
                pipe3D.removeFromParentNode()
                
            }       // Clean up SCNNode
            pipes.removeValue(forKey: name)        // Delete 3d Object
        }
    } //end deletePipeByUID
    
    //=====<oogie2D mainVC>====================================================
    // spawns a series of other stoopid submenus, until there is a smart way
    //    to do it in AR.  like point at something and select?????
    //  Step 1: get output channel, Step 2: pick target , Step 3: choose parameter
    func addPipeStepOne(voice:OogieVoice)
    {
        let alert = UIAlertController(title: "Choose Output Channel", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //DHS 12/1 REPLACE!!!
        let chanz = ["Red","Green","Blue","Hue","Saturation","Luminosity","Cyan", "Magenta" ,"Yellow"]
        for chan in chanz
        {
            alert.addAction(UIAlertAction(title: chan, style: .default, handler: { action in
                self.addPipeStepTwo(voice: voice,channel: chan.lowercased())
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end addPipeStepOne
    
    //=====<oogie2D mainVC>====================================================
    //12/30 for pipe addition
    func getListOfSceneShapes() -> [String]
    {
        var troutput : [String] = []
        for (n,_) in sceneShapes {troutput.append(n)}
        return troutput
    }
    //=====<oogie2D mainVC>====================================================
    //12/30 for pipe addition
    func getListOfSceneVoices() -> [String]
    {
        var troutput : [String] = []
        for (n,_) in sceneVoices {troutput.append(n)}
        return troutput
    }

    //=====<oogie2D mainVC>====================================================
    func addPipeStepTwo(voice:OogieVoice , channel : String)
    {
        //print("step 2 chan \(channel)")
        //12/30 we should look in sceneShapes/sceneVoices for our list...
        let list1 = getListOfSceneShapes()
        let list2 = getListOfSceneVoices()
        let alert = UIAlertController(title: "Choose Destination", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        for l11 in list1
        {
            alert.addAction(UIAlertAction(title: l11, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : l11.lowercased(),isShape: true)
            }))
        }
        for l12 in list2
        {
            alert.addAction(UIAlertAction(title: l12, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : l12.lowercased(),isShape: false)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)


    } //end addPipeStepTwo

    
    //=====<oogie2D mainVC>====================================================
    func addPipeStepThree(voice:OogieVoice , channel : String , destination : String , isShape : Bool)
    {
        //print("step 3 chan \(channel) destination \(destination) shape \(isShape)")
        let alert = UIAlertController(title: "Choose Parameter", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        var menuNames = shapeParamNamesOKForPipe
        if !isShape {menuNames = voiceParamNamesOKForPipe}
        for pname in menuNames
            {
                alert.addAction(UIAlertAction(title: pname, style: .default, handler: { action in
                    //Add our pipe to scene... (BREAK OUT TO METHOD WHEN WORKING!)
                    let ps = PipeStruct(fromObject: voice.OVS.name, fromChannel: channel.lowercased(), toObject: destination, toParam: pname.lowercased())
                    let pcount = 1 + self.scenePipes.count //use count to get name
                    self.addPipeToScene(ps: ps, name: String(format: "pipe%4.4d", pcount), op: "load")

                }))
            }
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }

    //=====<oogie2D mainVC>====================================================
    // 11/30
    func deletePipePrompt(pipe:OogiePipe)
    {
        let alert = UIAlertController(title: "Delete Selected Pipe?", message: "Pipe will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.deletePipe(name: self.selectedPipe.PS.name)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deletePipePrompt

    //=====<oogie2D mainVC>====================================================
    // 11/30 removes pipe from scene / SCNNode
    // 1/21 WUPS? this assumes selected pipe but takes a pipe arg. WTF?
    func deletePipe(name:String)
    {
        if let pipe3D = pipes[name]
        {
            pipe3D.removeFromParentNode()                //Blow away 3d Shape
            cleanupPipeInsAndOuts(name:name)            // 1/22 cleanup ins and outs...
            scenePipes.removeValue(forKey: name)       //  and clear entry from
            pipes.removeValue(forKey: name)           //   and data / shape dicts
            selectedPipeName = ""
        }
    } //end deletePipe
    
    //=====<oogie2D mainVC>====================================================
    func cleanupPipeInsAndOuts(name:String)
    {
        if let pipe = scenePipes[name]
        {
            removeVoiceOutputPipe(pipe:pipe)
            if pipe.destination == "shape" //headed to a shape?
               { removeShapeInputPipe(pipe:pipe) }
            //... need to handle voice input later!
        }
    }  //end cleanupPipeInsAndOuts

    //=====<oogie2D mainVC>====================================================
    // 1/22 data bookkeeping, remove pipe UID from source voice outPipes set
    func removeVoiceOutputPipe(pipe:OogiePipe)
    {
        let vname = pipe.PS.fromObject //get our voice name
        if let voice = sceneVoices[vname] //and the voice...
        {
            voice.outPipes.remove(pipe.uid) //delete UID entry
            sceneVoices[vname] = voice     // save voice back
        }
    } //end removeVoiceOutputPipe
    
    //=====<oogie2D mainVC>====================================================
    // 1/22 data bookkeeping, remove pipe UID from dest shapes inPipes set
    func removeShapeInputPipe(pipe:OogiePipe)
    {
        let sname = pipe.PS.toObject //get our voice name
        if let shape = sceneShapes[sname]  //and the shape...
        {
            shape.inPipes.remove(pipe.uid) //delete UID entry
            sceneShapes[sname] = shape    // save shape back
        }
    } //end removeShapeInputPipe

    
    //=====<oogie2D mainVC>====================================================
    // 10/27
    func deleteVoicePrompt(voice:OogieVoice)
    {
        print("Delete Voice... \(voice.OVS.name)")
        let alert = UIAlertController(title: "Delete Selected Voice?", message: "Voice will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.deleteVoice(voice: voice)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteVoicePrompt

    //=====<oogie2D mainVC>====================================================
    // 10/27 removes voice from scene / SCNNode
    func deleteVoice(voice:OogieVoice)
    {
        let name = voice.OVS.name
        let marker = allMarkers[selectedObjectIndex]   //1/27 forgot to remove marker 3d object!
        marker.removeFromParentNode()
        allMarkers.remove(at: selectedObjectIndex)   // Delete from marker array
        sceneVoices.removeValue(forKey: name)       //  and remove data structure
    } //end deleteVoice

    //=====<oogie2D mainVC>====================================================
    // 1/14 reload voice from last saved scene
    func resetVoiceByName(name:String)
    {
        print("resetVoiceByName \(name)")
        for (n, s) in OVScene.voices
        {
            if n == name
            {
                if let sss = sceneVoices[name] //gawd this is awkward. get substructure ...
                {
                    sss.OVS = s;
                    sceneVoices[name] = sss; //store it back
                    print("...match \(sss)")
                    if n == selectedVoice.OVS.name {selectedVoice = sss}  //Reset seleted voice?
                }
            }
        }
    }  //end resetVoiceByName

    //=====<oogie2D mainVC>====================================================
    // 1/14 reload shape from last saved scene, also resets 3d shape spin rate
    func resetShapeByName(name:String)
    {
        print("resetShapeByName \(name)")
        for (n, s) in OVScene.shapes
        {
            if n == name
            {
                if let shape = sceneShapes[name] //1/21 redo all this
                {
                    shape.OOS = s
                    if n == selectedShapeName
                    { selectedShape = shape }  //1/21 Reset seleted shape?
                    if let sshape = shapes[name] //also set 3d node spin rate!@
                       {  sshape.setTimerSpeed(rs: s.rotSpeed) //1/14 invalidate/reset timer
                           print("set rotspeed \(s.rotSpeed)")
                       }
                    break
                }
            }
        }
    }  //end resetShapeByName

    //=====<oogie2D mainVC>====================================================
    func removeVoice()
    {
        print("Remove Voice...")
        let alert = UIAlertController(title: "Remove Selected Voice?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    //=====<oogie2D mainVC>====================================================
    func clearScenePrompt()
    {
        let alert = UIAlertController(title: "Clear Current Scene?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.pLabel.updateLabelOnly(lStr:"Clear Scene...")
            self.clearScene()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end clearScenePrompt
    
    //=====<oogie2D mainVC>====================================================
    // 2/1 clears internal dictionaries of oogieVoices, Shapes and Pipes  asdf
    func clearOogieStructs()
    {
        sceneVoices.removeAll()
        sceneShapes.removeAll()
        scenePipes.removeAll()
    } //end clearOogieStructs
    
    //=====<oogie2D mainVC>====================================================
    func clearScene()
    {
        
        self.OVScene.clearScene()       //   and scene structs
        self.clearOogieStructs()       //2/1
        self.clearAllNodes(scene:scene)  // Clear any SCNNodes
        self.OVScene.createDefaultScene(sname: "default")  //2/1/20 add an object
        self.create3DScene(scene:scene) //  then create new scene from file
        cameraNode.transform = SCNMatrix4Identity
        cameraNode.position  = SCNVector3(x:0, y: 0, z: 6) //put camera back away from origin
    } //end clearScene
    
    //=====<oogie2D mainVC>====================================================
    func clearAllNodes(scene:SCNScene)
    {
        oogieOrigin.enumerateChildNodes { (node, _) in //1/20 new origin
        //print("remove node \(node.name)")
            if (node.name != nil) {node.removeFromParentNode()}
        }
        allMarkers.removeAll() //DHS 11/4 blow away all 3D references
        shapes.removeAll()
        pipes.removeAll()          //1/21 wups?
        pipeUIDToName.removeAll()  //1/22
    } //end clearAllNodes
    
    
    //=====<oogie2D mainVC>====================================================
    // Assumes shapes already loaded..
    func create3DScene(scene:SCNScene)
    {
        //iterate thru dictionary of shapes...
        for (name, nextShape) in OVScene.shapes
            { addShapeToScene(shape: nextShape, name: name, op: "load") }
        //iterate thru dictionary of shapes...
        for (name, nextOVS) in OVScene.voices
            { addVoiceToScene(nextOVS: nextOVS, name: name, op: "load") }
        //OK add pipes too
        for (name, nextPipe) in OVScene.pipes
            { addPipeToScene(ps: nextPipe, name: name, op: "load") }

        //let axes = createAxes() //1/11/20 test azesa
        //oogieOrigin.addChildNode(axes)
        //scene.rootNode.addChildNode(axes)
        
    } //end create3DScene

      //Hopefully dumps enuf for debugging anything?
      //-----------(oogiePipe)=============================================
      func dumpDebugShit()
      {
          let appDelegate = UIApplication.shared.delegate as! AppDelegate
          var elDumpo     = appDelegate.versionStr
          //Get scene start pos
          let sPOz =  String(format: "StartPos XYZ %4.2f,%4.2f,%4.2f",
                             startPosition.x, startPosition.y, startPosition.z)
          elDumpo         = elDumpo + "\n--------SceneDump--------\n" + OVScene.getDumpString() + "\n" + sPOz
          let sceneFilez  = DataManager.getDirectoryContents(whichDir: "scenes")
          let sf          = sceneFilez.joined(separator: ",")
          elDumpo         = elDumpo + "\n--------SceneFiles--------\n" + sf
          print("\(elDumpo)")
          let alert = UIAlertController(title: "Dump of scene / folder", message: elDumpo, preferredStyle: UIAlertControllerStyle.alert)
          alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
          }))
          self.present(alert, animated: true, completion: nil)

      }

    
    
    //-----------(oogiePipe)=============================================
     func createAxes() -> SCNNode
     {
        
        let brad : CGFloat = 0.05
        
         let parent = SCNNode()
         let lilsize : CGFloat = 0.02
         let bigsize : CGFloat = 10.0
         let xbox = SCNBox(width: bigsize, height: lilsize, length: lilsize, chamferRadius: 0)
         xbox.firstMaterial?.diffuse.contents  = UIColor.red
         parent.addChildNode(SCNNode(geometry: xbox))
        
        //x axis ballz
        for i in 0...5
        {
            let sphere = SCNSphere(radius: brad)
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            let sphereNode = SCNNode(geometry:sphere)
            sphereNode.position = SCNVector3(CGFloat(i),0.0,0.0)
            parent.addChildNode(sphereNode)
        }

         let ybox = SCNBox(width: lilsize, height: bigsize, length: lilsize, chamferRadius: 0)
         ybox.firstMaterial?.diffuse.contents  = UIColor.green
         parent.addChildNode(SCNNode(geometry: ybox))
        
        //y axis ballz
        for i in 0...5
        {
            let sphere = SCNSphere(radius: brad)
            sphere.firstMaterial?.diffuse.contents = UIColor.green
            let sphereNode = SCNNode(geometry:sphere)
            sphereNode.position = SCNVector3(0.0,CGFloat(i),0.0)
            parent.addChildNode(sphereNode)
        }


         let zbox = SCNBox(width: lilsize, height: lilsize, length: bigsize, chamferRadius: 0)
         zbox.firstMaterial?.diffuse.contents  = UIColor.blue
         parent.addChildNode(SCNNode(geometry: zbox))

        //z axis ballz
        for i in 0...5
        {
            let sphere = SCNSphere(radius: brad)
            sphere.firstMaterial?.diffuse.contents = UIColor.blue
            let sphereNode = SCNNode(geometry:sphere)
            sphereNode.position = SCNVector3(0.0,0.0,CGFloat(i))
            parent.addChildNode(sphereNode)
        }

         return parent
     }

    //=====<oogie2D mainVC>====================================================
    // 10/26 break out for cloning / creating / etc
    func addShapeToScene (shape:OSStruct , name : String, op : String)
    {
        if shape.primitive == "sphere"
        {
            var newName       = name
            let sphereNode    = SphereShape() //make new 3d shape, texture it
            var newOSStruct   = OSStruct() // make new data model for shape too
            sphereNode.setBitmap(s: shape.texture)
            sphereNode.bmp.setScaleAndOffsets(
                sx: shape.uScale, sy: shape.vScale,
                ox: shape.uCoord, oy: shape.vCoord)
            //finally, place 3D object as needed..
            newOSStruct     = shape //Copy in our shape to be cloned...
            if op != "load" // 10/26 clone / new object? need to get new XYZ
            {
                sphereNode.position = getFreshXYZ()
                newOSStruct.xPos = Double(sphereNode.position.x)
                newOSStruct.yPos = Double(sphereNode.position.y)
                newOSStruct.zPos = Double(sphereNode.position.z)
                newName = "shape" + String(format: "%03d", 1 + sceneShapes.count)
                newOSStruct.name = newName
            }
            else //Load, assume we already have XYZ data in place
            {
                let poz = shape.getPosition() //10/24 / wups, need start pos!
                sphereNode.position = SCNVector3(poz.x + startPosition.x,
                                                 poz.y + startPosition.y,
                                                 poz.z + startPosition.z)
            }
            sphereNode.setTextureScaleAndTranslation(xs: Float(shape.uScale), ys: Float(shape.vScale), xt: Float(shape.uCoord), yt: Float(shape.vCoord))
            sphereNode.setupTimer(rs: shape.rotSpeed)    
            sphereNode.name      = newName
            oogieOrigin.addChildNode(sphereNode)  //1/20 new origin
            let newOogieShape    = OogieShape()   // 1/21 new shape struct
            newOogieShape.OOS    = newOSStruct
            sceneShapes[newName] = newOogieShape  //save latest shap to working dictionary
            shapes[newName]      = sphereNode     //10/21
        } //end if primitive...
    } //end addShapeToScene
    
    //=====<oogie2D mainVC>====================================================
    // 11/24 load canned 3D pos back from where we got it!
    // BROKEN: sets position and rotation OK but orientation is a 4x4 and it isn't set!
    //  OUCH! do i have to save the entire 4x4?
    //  https://stackoverflow.com/questions/42029347/position-a-scenekit-object-in-front-of-scncameras-current-orientation
    func setCamXYZ()
    {
        if let pov = skView.pointOfView
        {
            pov.transform = camXform
        }

    } //end setCamXYZ
    
    
    //=====<oogie2D mainVC>====================================================
    // 11/24 captures 3D scene cam position, etc every time user
    //   drags around in the scene
    func getCamXYZ()
    {
        if let pov = skView.pointOfView
        {
            camXform = pov.transform
        }

    }
    
    //=====<oogie2D mainVC>====================================================
    //   get centroid first, then go " around the clock"
    //   1/22 redo math, was wrong in computing new item offset from centroid
       func getFreshXYZ() -> SCNVector3
        {
            var X    : Double = 0.0
            var Y    : Double = 0.0
            var Z    : Double = 0.0
            var Xmin : Double =  9999.0
            var Xmax : Double = -9999.0
            var Ymin : Double =  9999.0
            var Ymax : Double = -9999.0
            var Zmin : Double =  9999.0
            var Zmax : Double = -9999.0
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
                Xmin = min(Xmin,xx)
                Xmax = max(Xmax,xx)
                Ymin = min(Ymin,yy)
                Ymax = max(Ymax,yy)
                Zmin = min(Zmin,zz)
                Zmax = max(Zmax,zz)
                if c == 0 //remember first XZ coords
                {
                    X0 = xx
                    Z0 = zz
                }
                c = c + 1.0
            }
            if c == 0 {return SCNVector3Zero} //Nothing? centroid is origin
            let cx = Double(X/c) //Get centroid of all our shapes
            let cy = Double(Y/c) //  y isnt used now btw
            let cz = Double(Z/c)
            var newPos3D = SCNVector3Make(Float(cx), Float(cy), Float(cz)) // centroid!
            X0  = X0 - cx   //get xz distances from centroid to first shape
            Z0  = Z0 - cz
            var outerRad = Float(sqrt(X0*X0 + Z0*Z0-cz))  //This is radius from centroid to all shapes
            if c != 0 //1/22 got shape(s)?
            {
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
            }
            shapeClockPos = (shapeClockPos + 1) % 4  //advance positional clock
            return newPos3D
        } //end getFreshXYZ

    //=====<oogie2D mainVC>====================================================
    // 10/26 break out for cloning / creating / etc
    func addVoiceToScene(nextOVS : OVStruct , name : String, op : String)
    {
        var voiceShape = selectedShape // Try selected shape first (for new voice)
        if op != "new"
        {
            if sceneShapes[nextOVS.shapeName] == nil {return} //1/27 bail on no shape
            voiceShape = sceneShapes[nextOVS.shapeName]!     // we know it exists, force unwrap
        }
        
        var newOVS    = nextOVS
        var newName   = newOVS.name
        let nextVoice = OogieVoice()
        if op == "load" //Loading? Remember name!
        {
            nextVoice.OVS = newOVS
        }
        else if op == "new" //1/12/20
        {
            newOVS           = OVStruct() //get new ovs
            newOVS.patchName = "SineWave" //1/27 need to default to something!
            newOVS.shapeName = selectedShape.OOS.name
        }
        //Finish filling out voice structures
        nextVoice.OOP = allP.getPatchByName(name:newOVS.patchName)
        //10/27 support cloning.. just finds unused lat/lon space on same shape
        if op == "clone" || op == "new"
        {
            let llTuple = getFreshLatLon(sname: nextOVS.shapeName ,
                                         lat: newOVS.yCoord, lon: newOVS.xCoord)
            newOVS.yCoord = llTuple.lat
            newOVS.xCoord = llTuple.lon
            newName = "voice" + String(format: "%03d", 1 + sceneVoices.count)
        }
        
        nextVoice.OVS = newOVS
        if nextVoice.OOP.type == PERCKIT_VOICE { nextVoice.getPercLooxBufferPointerSet()  }
        self.setupSynthOrSample(oov: nextVoice); //More synth-specific stuff
        nextVoice.OVS.name = newName //10/27 Make sure name is saved in OVS struct
        sceneVoices[newName]  = nextVoice //save latest voice to working dictionary
        //Hmm is default always a sphere< should defauls scene use sphere as primitive name?
        if voiceShape.OOS.primitive == "sphere" || voiceShape.OOS.primitive == "default" //1/21 Sphere has 2 handles...
        {
            if let shape3D = shapes[nextVoice.OVS.shapeName] //10/21 find shape 3d object
            {
                //Lat / Lon Marker to select color
                let nextMarker = Marker()
                nextMarker.name = newName //9/16 point to voice
                //10/29 here we have int type, not string...
                nextMarker.updateTypeInt(newTypeInt: Int32(nextVoice.OOP.type))
                allMarkers.append(nextMarker)
                shape3D.addChildNode(nextMarker)
                nextMarker.updateLatLon(llat: nextVoice.OVS.yCoord, llon: nextVoice.OVS.xCoord)
            }
            else
            {
                print("error find shape for voice \(nextVoice.OVS.name)")
            }
        }
    } //end addVoiceToScene
    
    //=====<oogie2D mainVC>====================================================
    // 12/30 for adding pipes...
    func getMarkerParentPositionByName (name : String) -> SCNVector3
    {
        var result  = SCNVector3Zero
        if let tvoice  = sceneVoices[name] //find our voice...
        {
            let psName  = tvoice.OVS.shapeName //get name of shape to retrieve position...
            if let tShape  = shapes[psName]    //ok look up shape
            {
                result = tShape.position       //and get result!
            }
        }
        return result
    } //end getMarkerParentPositionByName
    
    
    //=====<oogie2D mainVC>====================================================
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
                pmax = 10.0
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

    //=====<oogie2D mainVC>====================================================
    //1/20 looks like we need to store stuff into our pipe object that the
    //  3d scene node needs, like flat, tlat??
    // ...or just delete pipe & call this over and over as a marker is moved?
    // 1/22 new properties in OogiePipe...
    func addPipeToScene(ps : PipeStruct , name : String, op : String)
    {
        var oop  = OogiePipe()
        oop.PS   = ps
        //OK now for 3d representation. Find centers of two objects:
        let from    = oop.PS.fromObject
        let toObj   = oop.PS.toObject
        if shapes[toObj] != nil  //Found a shape as target?
        {
            oop.destination  = "shape"
            if let shapeNode = sceneShapes[toObj] //get matching shape object
            {
                shapeNode.inPipes.insert(oop.uid) //Add our UID to shape object
            }
        }
        else // Found voice/marker?
        {
            oop.destination = "voice"
        }
        
        //1/29 (moved) Now we need to scale things so pipe will work
        let loHiRange = getPipeRangeForParamName(pname:ps.toParam.lowercased(),dest:oop.destination)
        oop.setupRange(lo: loHiRange.lo, hi: loHiRange.hi) //1/14 REDO
        
        self.scenePipes[name] = oop //store pipe object
        // 1/22 for pipe management and updates:
        pipeUIDToName[oop.uid] = name
        // 1/22 need to get matching voice for fromMarker!
        if let fromVoice = sceneVoices[from]
        {
            fromVoice.outPipes.insert(oop.uid) //Add our UID to voice object
            sceneVoices[from] = fromVoice //DUH 1/25
        }
        // 1/22 split off 3d portion
        addPipeNode(oop : oop , newNode : true) //1/30
    } //end addPipeToScene

    //=====<oogie2D mainVC>====================================================
    // 1/22 new,  1/30 add newNode arg
    func addPipeNode (oop:OogiePipe , newNode : Bool)
    {
        let n             = oop.PS.name
        var pipe3DObject  = PipeShape()
        if (!newNode) //update? pull pipe shape
        {
            if pipes[n] == nil {return} //bail on nil
            pipe3DObject = pipes[n]!   //else get pipe shape
        }
        else //2/1 new pipe? set up uid/name
        {
            pipe3DObject.uid  = oop.uid  //1/22 force UID to be same as data object
            pipe3DObject.name = n
        }

        //1/26 Need to get lats / lons the hard way for now...
        let from    = oop.PS.fromObject
        let fmarker = findMarkerByName(name:from)
        let flat    = fmarker.lat
        let flon    = fmarker.lon
        let sPos00  = getMarkerParentPositionByName(name:from)
        let toObj   = oop.PS.toObject
        var sPos01  = fmarker.position
        var tlat    = Double.pi/2.0
        var tlon    = 0.0
        var isShape = false   //1/28
        
        if let sphereNode = shapes[toObj]  //Found a shape as target?
        {
            sPos01 = sphereNode.position
            isShape = true
        }
        else //Assume voice/marker?
        {
            let tmarker = findMarkerByName(name:toObj)
            tlat    = tmarker.lat
            tlon    = tmarker.lon
            sPos01  = getMarkerParentPositionByName(name:toObj) //12/30
        }
        //print("apn flatlon \(flat),\(flon)  tlatlon \(tlat),\(tlon) nn \(newNode)")
        //  11/29 match pipe color in corners
        pipe3DObject.pipeColor = pipe3DObject.getColorForChan(chan: oop.PS.fromChannel)
        let pipeNode = pipe3DObject.create3DPipe(flat : flat , flon : flon , sPos00  : sPos00 ,
                                                 tlat : tlat , tlon : tlon , sPos01  : sPos01 ,
                                                 isShape: isShape, newNode : newNode)
        if (newNode) //1/30
        {
            pipeNode.name = n
            pipe3DObject.addChildNode(pipeNode)     // add pipe to 3d object
            oogieOrigin.addChildNode(pipe3DObject)  //1/20 new origin
            pipes[n] = pipe3DObject  // dictionary of 3d objects
        }
    } //end addPipeNode

    //=====<oogie2D mainVC>====================================================
    func foundAMarker(sname : String , lat:Double , lon:Double)  -> Bool
    {
        for (_,vvv) in sceneVoices
        {
            if vvv.OVS.shapeName == sname
            {
                let olat = vvv.OVS.xCoord
                let olon = vvv.OVS.yCoord
                if sqrt((lat-olat) + (lon-olon)) < llToler {return true}
            }
        }
        return false
    }
    
    //=====<oogie2D mainVC>====================================================
    func getFreshLatLon(sname : String , lat:Double , lon:Double)  -> (lat:Double , lon:Double )
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
                if !foundAMarker(sname : sname , lat: tlat, lon: tlon)
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
    func packupSceneAndSave(sname:String)
    {
        //DHS 11/24 test for later
        if let pov = skView.pointOfView
        {
            camXform = pov.transform
            print(" save back txfm \(camXform)")
        }
        //10/26 first we need to clean target...
        OVScene.voices.removeAll()
        OVScene.shapes.removeAll()
        //update scene with any changed voice paras...
        for (name, nextVoice) in sceneVoices //10/26 wups
        {
            OVScene.voices[name] = nextVoice.OVS  //1/21 cleanup
        }
        for (name,nextShape) in sceneShapes
        {
            OVScene.shapes[name] = nextShape.OOS  //1/21 pack the codable part
        }
        //DHS 12/5 pipes may have been renamed!
        OVScene.pipes.removeAll()
        for (_,nextPipe) in scenePipes  //11/24 add pipes to output!
        {
            OVScene.pipes[nextPipe.PS.name] = nextPipe.PS
        }
        OVScene.packParams() //11/22 need to pack some stuff up first!
        DataManager.saveScene(self.OVScene, with: sname)
        
        
    } //end packupSceneAndSave

    
    //=====<oogie2D mainVC>====================================================
    func findMarker(uid:String) -> Int
    {
        var index = 0
        for marker in allMarkers
        {
            if uid == marker.uid { return index }
            index = index + 1
        }
        return -1
    } //end findMarker
    
    //=====<oogie2D mainVC>====================================================
    func findMarkerByName(name : String) -> Marker
    {
        for marker in allMarkers
        {
            if marker.name == name { return marker  }
        }
        return Marker()
    } //end findMarkerByName
    
 
       //=====<oogie2D mainVC>====================================================
       // 10/21 shapes become dictionary
       func findShape(uid:String) -> String
       {
           for (name,shape) in shapes
           {  if uid == shape.uid { return name } }
           return ""
       } //end findShape

    //=====<oogie2D mainVC>====================================================
    //WTF? when this is called all pipes have different uid's
    //  than what we're matching against! are new UIDs getting made over and over?
    func findPipe(uid:String) -> String
    {
     
        for (name,pipe) in pipes
        { if uid == pipe.uid
        {
            return name }
        }
        return ""
    } //end findPipe

    
 
    
    //=====<oogie2D mainVC>====================================================
    // 11/25 add pipes!! ONLY handles marker read / play, NO UI!
    @objc func playAllPipesMarkersBkgdHandler()
    {
        //First thing we get all the data from pipes...
        for (n,p) in scenePipes //handle pipes, update pipe....
        {
            //print("n \(n) spm \(selectedPipeName)")
            var pwork = p //get editable copy?
            //12/1 use selected pipe if editing!
            if n == selectedPipeName  { pwork = selectedPipe }
            if pwork.gotData // Got data? Send to shape/voice parameter
            {                
                //1/14 NO conversion needed, already happens in pipe!
                let pipeVal = pwork.getFromOBuffer(clearFlags:true)
                if pwork.destination == "shape" //send out shape param
                {
                    if let shape = sceneShapes[pwork.PS.toObject]
                    {
                        switch(pwork.PS.toParam.lowercased())  //WTF WHY NEED LOWERCASE!
                        {
                        case "texxoffset": shape.OOS.uCoord = Double(pipeVal)
                        case "texyoffset": shape.OOS.vCoord = Double(pipeVal)
                        case "texxscale" : shape.OOS.uScale = Double(pipeVal)
                        case "texyscale" : shape.OOS.vScale = Double(pipeVal)
                        //YUP, name of param doesnt jibe with param it changes!
                        case "rotation"      : shape.OOS.rotSpeed = Double(pipeVal)
                        case "rotationtype"  : shape.OOS.rotation = Double(pipeVal)
                        if let shape3D = shapes[pwork.PS.toObject] //12/1 rot speed
                        {  shape3D.setTimerSpeed(rs: Double(pipeVal)) }
                        default: print("illegal pipe shape param \(p.PS.toParam)")
                        }
                        sceneShapes[pwork.PS.toObject] = shape //save it back!
                        update3DShapeByName (n:pwork.PS.toObject)
                        //changed texture?
                        if let pipe3D = pipes[n]
                        {
                            //print("texture bptr \(pwork.bptr)")
                            let vals = pwork.ibuffer //11/28 want raw unscaled here!
                            pipe3D.texturePipe(phase:0.0 , chan: pwork.PS.fromChannel.lowercased(),
                                               vals: vals, vsize: vals.count , bptr : pwork.bptr)
                        } //end pipe3D
                    }   //end shape
                } //end pwork.destination
                else if pwork.destination == "voice" //1/27 send out voice param
                {
                    let tname = pwork.PS.toObject
                    if let voice = sceneVoices[tname]
                    {
                        var needPipeUpdate = false
                        var needNewPatch   = false
                        switch(pwork.PS.toParam.lowercased())  //WTF WHY NEED LOWERCASE!
                        {
                        case "latitude"   : voice.OVS.yCoord      = Double(pipeVal)
                            needPipeUpdate = true
                        case "longitude"  : voice.OVS.xCoord      = Double(pipeVal)
                            needPipeUpdate = true
                        case "scale"      : voice.OVS.keySig      = Int(pipeVal)
                        case "level"      : voice.OVS.level       = Double(pipeVal)
                        case "nchan"      : voice.OVS.noteMode    = Int(pipeVal)
                        case "vchan"      : voice.OVS.volMode     = Int(pipeVal)
                        case "pchan"      : voice.OVS.panMode     = Int(pipeVal)
                        case "nfixed"     : voice.OVS.noteFixed   = Int(pipeVal)
                        case "vfixed"     : voice.OVS.volFixed    = Int(pipeVal)
                        case "pfixed"     : voice.OVS.panFixed    = Int(pipeVal)
                        case "topmidi"    : voice.OVS.topMidi     = Int(pipeVal)
                        case "bottommidi" : voice.OVS.bottomMidi  = Int(pipeVal)
                        case "midichannel": voice.OVS.midiChannel = Int(pipeVal)
                        default: print("illegal pipe voice param \(p.PS.toParam)")
                        }
                        sceneVoices[tname] = voice //save it back!
                        var index = 0
                        if needPipeUpdate
                        {
                            for marker in self.allMarkers   //look for our marker by name
                            {
                                if marker.name == tname
                                {   //move marker as needed, save data
                                    marker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
                                    self.allMarkers[index] = marker
                                    break //get outta here!
                                }
                                index+=1;
                            } //end for marker
                            let fname = pwork.PS.fromObject
                            if let invoice = sceneVoices[fname]
                            {
                                if !updatingPipe
                                {
                                    updatePipeByVoice(v:invoice)
                                }
                            }

                        }
                    }
                }
            } //end pwork.gotData
        } //end for n,p

        //iterate thru dictionary of voices, play each one as needed...
        if !shouldNOTUpdateMarkers && allMarkers.count>0 //11/18 added error checks
        {
            for counter in 0...allMarkers.count-1
            {
                var workVoice  = OogieVoice()
                let nextMarker = allMarkers[counter]
                if whatWeBeEditing == "voice" && knobMode != KnobStates.SELECT_PARAM &&
                    counter == selectedObjectIndex //selected and editing? load edited voice
                {
                    workVoice = selectedVoice
                }
                else if let vname = nextMarker.name  //otherwise load OVS from scene
                {
                    workVoice = sceneVoices[vname]!
                }
                else
                {
                    print("PAM error: no voice found")
                }
                var playit = true //10/17 add solo support
                if soloVoiceID != "" && workVoice.uid != soloVoiceID {playit = false}
                if  playit && !workVoice.muted  //10/17 add mute
                {
                    if let sphereNode = shapes[workVoice.OVS.shapeName] //10/21
                    {
                        let rgbaTuple = getShapeColor(shape:sphereNode , xCoord:workVoice.OVS.xCoord, yCoord:workVoice.OVS.yCoord, angle: sphereNode.angle) //10/25 new angle
                        //Update marker output to 3D
                        nextMarker.updateRGBData(rrr: rgbaTuple.R, ggg: rgbaTuple.G, bbb: rgbaTuple.B)
                        setupSynthOrSample(oov: workVoice) //load synth ADSR, send note out
                        // 11/18 move playcolors to voice
                        nextMarker.gotPlayed = workVoice.playColors(rr: rgbaTuple.R, gg: rgbaTuple.G, bb: rgbaTuple.B)
                    }
                }
            } //end for counter...
        } //end !shouldNot

        //1/25 this is a cluge for now: updating any pipe? skip this part to avoid krash
        if !updatingPipe
        {
            //11/25 Cleanup time! Feed any pipes that need data...
            for (n,p) in scenePipes
            {
                var pwork = p //get editable copy
                if n == selectedPipeName  { pwork = selectedPipe } //1/14 editing?
                if let vvv = sceneVoices[p.PS.fromObject] //find pipe source voice
                {
                    //get latest desired channel from the marker / voice
                    let floatVal = Float(vvv.getChanValueByName(n:p.PS.fromChannel.lowercased()))
                    pwork.addToBuffer(f: floatVal) //...and send to pipe
                    scenePipes[n] = pwork //Save pipe back into scene
                    if n == selectedPipeName  { selectedPipe = pwork } //1/14 editing?
                }
            } //end for n,p
        } //end !updatingpipe

        ///Ahhnd retrigger this in 30 ms, bkgd
        //2/1 try slower rate for cleaner results...
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {  //was 0.03
            self.playAllPipesMarkersBkgdHandler()
        }
    } //end playAllPipesMarkersBkgdHandler

    //=====<oogie2D mainVC>====================================================
    //Foreground, handles marker appearance...
    @objc func updateAllMarkers()
    {
        //=================================================================
        //STOOPID place for this. how about a .30 second timer
        // that starts on any segue, but then if  starts
        // the music, then the timer gets invalidated
        //=================================================================
        //WTF? this is different from any advice online!
        let vc = self.presentedViewController
        if vc == nil   //MainVC is on top...
        {
            if !isPlaying {startPlayingMusic()}
        }
        shouldNOTUpdateMarkers = (allMarkers.count == 0 || vc != nil)
        if  shouldNOTUpdateMarkers  {return;}
        //iterate thru dictionary of voices...
        for counter in 0...allMarkers.count-1
        {
            let nextMarker = allMarkers[counter]
            nextMarker.updateMarkerPetalsAndColor()
            if nextMarker.gotPlayed
            {
                nextMarker.updateActivity()
            }
        } //end for name...
    } //end updateAllMarkers
    
    
    //=====<oogie2D mainVC>====================================================
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //=====<oogie2D mainVC>====================================================
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    //=====<oogie2D mainVC>====================================================
    // Lat (Y) change
    @IBAction func sliderChanged(_ sender: Any) {
        //9/7 redpo let sl = sender as! UISlider
        //9/7 redpo OV.OVS.yCoord = Double(sl.value)
        //9/7 redpo updatePointer()
    }
    
    //=====<oogie2D mainVC>====================================================
    // Lon (X) change....
    @IBAction func rSliderChanged(_ sender: Any) {
        //9/7 redpo let sl = sender as! UISlider
        //9/7 redpo OV.OVS.xCoord = Double(sl.value)
        //9/7 redpo updatePointer()
    }
    
    //=====<oogie2D mainVC>====================================================
    // Menu / etc button bottom left
    @IBAction func buttonSelect(_ sender: Any) {
        if (knobMode == KnobStates.SELECT_PARAM) //User not editing a parameter? this is a menu button
        {
            //GM BASS 44.1khz  WtF? won't play
            (sfx() as! soundFX).makeTicSound(withPitchandLevelandPan: 8,16,80,128)
            //Bubbles
            (sfx() as! soundFX).makeTicSound(withPitchandLevelandPan: 11,64,80,128)
            //VW Horn
            (sfx() as! soundFX).makeTicSound(withPitchandLevelandPan: 14,30,80,128)
            menu()
        }
        else //editing? cancel! restore old value to field!
        {
            cancelEdit()
        }
    } //end buttonSelect
    

    //=====<oogie2D mainVC>====================================================
    func cancelEdit()
    {
        pLabel.updateLabelOnly(lStr:"Cancel Edit")
        restoreLastParamValue(oldD: lastFieldDouble,oldS: lastFieldString) //DHS 10/10
        if selectedFieldType == "double"  //update marker as needed...
        {
            if whatWeBeEditing == "voice"      {
                selectedMarker.updateLatLon(llat: selectedVoice.OVS.yCoord, llon: selectedVoice.OVS.xCoord)
            }
            else if whatWeBeEditing == "shape" {
                update3DShapeByName (n:selectedShapeName)
                if let sshape = shapes[selectedShapeName] //1/26 also set 3d node spin rate to last value
                { sshape.setTimerSpeed(rs: selectedShape.OOS.rotSpeed) //1/14 invalidate/reset timer
                }
            } //end else
            //1/26 missing pipe?
        }
        knobMode = KnobStates.SELECT_PARAM //back to select mode
        updateWheelAndParamButtons()
    } //end cancelEdit
    
    //=====<oogie2D mainVC>====================================================
    // take unit xy coords from voice, apply to our sphere..
    func updatePointer()
    {
    }

    
    // look at current xy, get color based on bmp
    //=====<oogie2D mainVC>====================================================
    // 8/23 assumes only one shape and only one pointer!
    //  XYCoord are in radian units, Y is -pi/2 to pi/2
    //   most math is done in 0..1 XY coords, then bmp size applied
    func getShapeColor(shape: SphereShape, xCoord : Double , yCoord : Double , angle : Double) -> (R:Int , G:Int , B:Int , A:Int)
    {
        let aoff = Double.pi / 2.0  //10/25 why are we a 1/4 turn off?
        // 11/3 fix math error in xpercent!
        var xpercent = (angle + aoff - xCoord) / twoPi  //11/3 apply xcoord B4 dividing!
        xpercent = -1.0 * xpercent                     //  and flip X direction
        //Keep us in range 0..1
        while xpercent > 1.0 {xpercent = xpercent - 1.0}
        while xpercent < 0.0 {xpercent = xpercent + 1.0}
        let ypercent = 1.0 - ((yCoord + .pi/2) / .pi)
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
        // print("xycoord \(xCoord),\(yCoord) : bmpxy \(bmpX),\(bmpY)")
        // print("...rgb \(pr),\(pg),\(pb)")
        return (Int(pr * 255.0),Int(pg * 255.0),Int(pb * 255.0),Int(pa * 255.0))
    } //end getShapeColor
    
    
    //=====<oogie2D mainVC>====================================================
    func getSelectedFieldStringForKnobValue (kv : Float) -> String
    {
        let ik = min( max(Int(kv),0),selectedFieldStringVals.count-1)
        return selectedFieldStringVals[ik]
    }

    //=====<oogie2D mainVC>====================================================
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
    
    //=====<oogie2D mainVC>====================================================
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
    
    //=====<oogie2D mainVC>====================================================
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
    
   
    //=====<oogie2D mainVC>====================================================
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
            //print("build wave/env ADSR \(oov.OOP.attack) :  \(oov.OOP.decay) :  \(oov.OOP.sustain) :  \(oov.OOP.release)")
            (sfx() as! soundFX).buildaWaveTable(0,Int32(oov.OOP.wave));  //args whichvoice,whichsynth
            (sfx() as! soundFX).buildEnvelope(0,false); //arg whichvoice?
        }
        else if (oov.OOP.type == PERCUSSION_VOICE)
        {
            //DHS 10/14 set up pointer to percussion sample...
            oov.bufferPointer = Int((sfx() as! soundFX).getPercussionBuffer(oov.OOP.name))
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
    

    
    //------<UITextFieldDelegate>-------------------------
    // 10/9  UITExtFieldDelegate...
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.text = "" //Clear shit out
        return true
    }
    //------<UITextFieldDelegate>-------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        lastFieldString = textField.text!
         //11/25
        setNewParamValue(fname: selectedFieldName.lowercased(),newval: knobValue )
        pLabel.isHidden = false //10/10 show param label again

        editSelect( editButton)  //Simulate button hit...
        textField.resignFirstResponder() //dismiss kb if up
        return true
    }
    //------<UITextFieldDelegate>-------------------------
    @IBAction func textChanged(_ sender: Any) {
        lastFieldString = textField.text!
         //11/25
        setNewParamValue(fname: selectedFieldName.lowercased(),newval: knobValue )
    }

    //--------<TextureVCDelegate.-------------------------------------
    func cancelled()
    {
        editSelect(editButton) // back to param select...
    }
    
    //--------<TextureVCDelegate.-------------------------------------
    func gotTexture(name: String, tex: UIImage)
    {
        if let sshape = shapes[selectedShapeName]
        {
            sshape.setBitmapImage(i: tex) //set 3d shape texture
            sshape.name           = name // save texture name
            selectedShape.OOS.texture = name
            //11/24 Store immediately back into scene!
            sceneShapes[selectedShapeName] = selectedShape
            editSelect(editButton)              // leave edit mode
        }
    }

    //Delegate callback from Chooser...
    func choseFile(name: String)
    {
        if chooserMode == "loadAllPatches"
        {
            let ppp = allP.getPatchByName(name: name)
            print("ppp \(ppp)")
        }
        else //handle scene?
        {
            OVSceneName  = name
            self.OVScene = DataManager.loadScene(OVSceneName, with: OogieScene.self)
            self.OVScene.unpackParams()       //DHS 11/22 unpack scene params
            setCamXYZ() //11/24 get any 3D scene cam position...
            self.clearAllNodes(scene:scene)  // Clear any SCNNodes
            self.create3DScene(scene:scene) //  then create new scene from file
            pLabel.updateLabelOnly(lStr:"Loaded " + OVSceneName)
        }

    } //end choseFile
    
    
    //---<chooserDelegate>--------------------------------------
    // 11/17 new delegate return w/ filenames from chooser
    func newFolderContents(c: [String])
    {
       // patchNamez = c
       // patchNum = 0

    }


    //Delegate callback from Chooser...
    func needToSaveFile(name: String) {
        OVSceneName = name
        self.packupSceneAndSave(sname:OVSceneName)
        pLabel.updateLabelOnly(lStr:"Saved " + OVSceneName)
    }

    
    //--------<patchEditVCDelegate.-------------------------------------
    func patchEditVCSavePatchNow(name : String)
    {
        print("save NOW")

    }

    //--------<patchEditVCDelegate.-------------------------------------
    func patchEditVCDone(namez : [String] , userPatch : Bool, allNew : Bool)
    {
        print("done")
        //save recently edited patches
        recentlyEditedPatches = namez //copy in array of namez
        if !allNew  //Did user replace a patch?
        {
            reloadAllPatchesInScene(namez : namez)
        }
        
    }

} //end vc class, line 1413 as of 10/10

