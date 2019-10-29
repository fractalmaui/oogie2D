//  __     ___                ____            _             _ _
//  \ \   / (_) _____      __/ ___|___  _ __ | |_ _ __ ___ | | | ___ _ __
//   \ \ / /| |/ _ \ \ /\ / / |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
//    \ V / | |  __/\ V  V /| |__| (_) | | | | |_| | | (_) | | |  __/ |
//     \_/  |_|\___| \_/\_/  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|
//
//  ViewController.swift
//  oogie2D
//
//  Aug 23  Added lat/lon handle to position pointer over shape, looks clean
//            but the bitmap X coord seems to be a bit off (lat coord)
//  Sep  2  OK scene gets created from file now
//  Sep  7  add support for multiple shapes/voices
//  Sep 11  add wheel for editing params / values
//  Sep 13  reset button
//  Sep 16  pull allvoices use scene instead
//  Sep 17  cross integrate -> oogieAR,
//            remember param # between edits
//  Sep 22  add percussion voice
//  Sep 27  add type to getPatchByName , causes new bugs ouch
//  Sep 28  add pLabel , infoText new custom UIView
//  Sep 30  add wheelTap
//  Oct 04  move performance params from patchObject to OVStruct, remake synth patches
//             pull key offset param for now, add following OVStruct params:
//                level,
//  Oct 09  add voice name param
//  Oct 10  redo restoreLastParamValue
//  Oct 11  add nameplates for markers/shapes
//  Oct 15  debug voice type change, change getPatchByName
//  Oct 16  add notificaton for sample load completion before scene creation
//  Oct 17  add sample envelopes, add mute/solo
//  Oct 18  add shape params, pull bunchofInts et al
//           added DisplayVals to show GM patch names properly
//  Oct 21  add save shapes, latHandles,shapes became dictionary
//           parent lon handles to shapes, texture param
//  Oct 22/23 added shape texture xyoffset scale, works OK now
//  Oct 25  redo shape rotation speed
//  Oct 26  break out addVoice , addShape, implement clone shape
//  Oct 27  add clone voice, longpress for shape/voice popups
import UIKit
import SceneKit
import Photos

let pi = 3.141592627
let twoPi = 6.2831852

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,UIGestureRecognizerDelegate {

    

    @IBOutlet weak var skView: SCNView!
    @IBOutlet weak var spnl: synthPanel!
    

    @IBOutlet weak var editButtonView: UIView!
    @IBOutlet weak var paramKnob: Knob!
    
    @IBOutlet weak var textField: UITextField!
    var fadeTimer = Timer()
    var pLabel = infoText()
    //10/17 solo
    var soloVoiceID = ""
    var touchLocation = CGPoint()
    var touchDown     = false //10/26
    var latestTouch   = UITouch()
    var testSample = 8
    @IBAction func testSelect(_ sender: Any) {
//        print("test : \(testSample)")
//        (sfx() as! soundFX).playNote(32, Int32(testSample), PERCUSSION_VOICE)
//        testSample = testSample + 1
//        if testSample > 29 {testSample = 8}
        //asdf
//        DataManager.gotDMError(msg: "duh")
    }
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    //Constructed shapes / handles
    var allMarkers    : [Marker]     = []
    var latHandles    = Dictionary<String, SCNNode>()
    var lonHandles    = Dictionary<String, SCNNode>() //parent of latHandle and marker!
    var selectedUids  : [String]     = []
    var sceneVoices   = Dictionary<String, OogieVoice>()
    var shapes        = Dictionary<String, SphereShape>()  //10/21
    var sceneShapes   = Dictionary<String, OogieShape>()

    //10/27 for finding new marker lat/lons
    let llToler = M_PI / 10.0
    let llStep  = M_PI / 8.0 //must be larger than toler

    
    //10/25 test pattern support
    #if USE_TESTPATTERN
    let ifname = "tp"
    #else
    let ifname = "oog2-stripey00t"
    #endif

    var whatWeBeEditing = ""

    //Params knob
    var oldKnobValue : Float = 0.0
    var knobValue    : Float = 0.0 //9/17 rename
    var lastBackToValue : Bool = false
    var selectedObjectIndex = 0 //Points to marker/shape/latlon handles, etc
    var selectedField = -1  //Which param we chose 0 = lat, 1 = lon, etc
    var selectedMarkerName   = ""
    var selectedShapeName    = ""
    var selectedFieldName    = ""
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
    var knobMode = 0   //0 = select param, 1 = edit param
    
    var startPosition = SCNVector3(x: 0, y: 0, z:0)

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    
    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    
    var tc = texCache.sharedInstance //9/3 texture cache

    let scene           = SCNScene()
    var OVScene         = OogieScene()
    var selectedVoice   = OogieVoice()
    var selectedMarker  = Marker()
    var selectedSphere  = SphereShape()  //10/18
    var selectedShape   = OogieShape()  //10/18

    //For creating new shapes
    var shapeClockPos  : Int = 0   //0 = noon 1 = 3pm etc



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
        let cameraNode = SCNNode()
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
        
        // 10/27 add longpress...
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        lpgr.minimumPressDuration = 0.5
        lpgr.delaysTouchesBegan = true
        lpgr.delegate = self
        self.view.addGestureRecognizer(lpgr)
        
        _ = Timer.scheduledTimer(timeInterval: 0.03, target: self, selector: #selector(self.playAllMarkers), userInfo:  nil, repeats: true)
        
        //Get our default scene, move to appdelegate?
        if DataManager.sceneExists(fileName : "default")
        {
            self.OVScene = DataManager.loadScene("default", with: OogieScene.self)
            print("...load default scene")
        }
        else
        {
            self.OVScene.createDefaultScene(sname: "default")
            print("...no default scene found, create!")
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
        
        //10/16 add notification to see when samples are loaded...
        NotificationCenter.default.addObserver(self, selector: #selector(self.samplesLoaded(notification:)), name: Notification.Name("samplesLoadedNotification"), object: nil)
    } //end viewDidLoad
    
    
    //=====<oogie2D mainVC>====================================================
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask(rawValue: UIInterfaceOrientationMask.portrait.rawValue | UIInterfaceOrientationMask.portraitUpsideDown.rawValue)
    }

    
    //=====<oogie2D mainVC>====================================================
    // 10/16 we can only create voices AFTER samples load!
    @objc func samplesLoaded(notification: NSNotification)
    {
        print("samples loaded...")
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
            //10/29 make sure we are on an object!
            let sceneView = skView!
            touchLocation = latestTouch.location(in: sceneView)
            guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
            if whatWeBeEditing == "voice" { voiceMenu() }
            if whatWeBeEditing == "shape" { shapeMenu() }
        }
        else {
        }
    }

    //=====<oogie2D mainVC>====================================================
    // 9/13 reset parameter to default
    @IBAction func resetSelect(_ sender: Any) {
        //print("reset to default \(selectedFieldDefault)")
        restoreLastParamValue(oldD: Double(selectedFieldDefault),oldS: selectedFieldDefaultString) //DHS 10/10
        knobValue = Float(selectedFieldDefault)  //9/17 make sure knob is set to param value
        updateSelected3DMarker ()
        resetKnobToNewValues(kv:knobValue , mn : selectedFieldMin , mx : selectedFieldMax)
    }

    //=====<oogie2D mainVC>====================================================
    // 9/12 RH edit button, over rotary knob, toggles edit / param mode
    @IBAction func editSelect(_ sender: Any) {
        if (knobMode == 0)  //Change to Edit parameter??
        {
            knobMode = 1
            getLastParamValue(fname : selectedFieldName.lowercased()) //Load up old vals for cancel operation
            knobValue = Float(lastFieldDouble)  //9/17 make sure knob is set to param value
            lastFieldSelectionNumber = Int(knobValue) //remember knob value to restore old deault
            pLabel.updateLabelOnly(lStr:"Edit:" + selectedFieldName)

            //DEBUG!
            if selectedFieldMax == selectedFieldMin {print("ERROR: no param range")}
            
            pLabel.isHidden = selectedFieldType    == "text"
            textField.isHidden = selectedFieldType != "text"

            
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
                textField.text = lastFieldString //10/9 from OVS
            }
            else if selectedFieldType == "texture" //10/21 handle textures
            {
                self.performSegue(withIdentifier: "textureSegue", sender: self)
            }
        } //end knobmode 0
        else{   //Done editing? back to param select?
            knobMode  = 0 //NOT editing now...
            
            //10/24 save voice/scene as needed
            if whatWeBeEditing == "voice"
            {
                sceneVoices[selectedMarkerName] = selectedVoice    //save latest voice to sceneVoices
                allMarkers[selectedObjectIndex] = selectedMarker //save any marker changes...
            }
            else if whatWeBeEditing == "shape"
            {
                sceneShapes[selectedShapeName] = selectedShape    //10/21 save latest voice to sceneVoices
            }

            //Restore label for param editing
            if whatWeBeEditing == "voice" //10/18 voice vs shape edit
            {
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : voiceParamNames)
            }
            else if whatWeBeEditing == "shape"
            {
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
                    choiceStrings : shapeParamNames)
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

        // For param diagnostics
        //paramKnob.verbose = (knobMode == 1) //10/4 add knob verbpose
        updateWheelAndParamButtons()
        //print("editmode \(knobMode)")
    } //end editSelect
    
    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "textureSegue" {
            if let nextViewController = segue.destination as? TextureVC {
                    nextViewController.delegate = self
            }
        }
    }

    
    //=====<oogie2D mainVC>====================================================
    func resetKnobToNewValues(kv:Float , mn : Float , mx : Float)
    {
        paramKnob.minimumValue = mn
        paramKnob.maximumValue = mx
        paramKnob.setValue(kv) //and set knob control

    }

    
    //=====<oogie2D mainVC>====================================================
    //  9/13 uses knobMode, updates buttons / wheels at bottom of screen
    func updateWheelAndParamButtons()
    {
        var knobName            = "fineGear" //assume edit
        paramKnob.isHidden      = false
        editButtonView.isHidden = false
        if (knobMode == 1)  //Edit?
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
            resetKnobToNewValues(kv: knobValue ,mn: selectedFieldMin ,mx: selectedFieldMax)
        } //end edit select
        else{   //back to param select?
            knobName = "wheel01"
            resetButton.isHidden = true
            textField.isHidden   = true //10/9
            editButton.setTitle("Edit", for: .normal)
            menuButton.setTitle("Menu", for: .normal)
            paramWheelMin = 0
            paramWheelMax = Float(Float(selectedVoice.getParamCount() - 1))
            resetKnobToNewValues(kv: knobValue ,mn:paramWheelMin ,mx: paramWheelMax)

        } //end param select
        paramKnob.setKnobBitmap(bname: knobName)
    } //end updateWheelAndParamButtons


    //=======>ARKit MainVC===================================
    //Param knob change...
    @IBAction func paramChanged(_ sender: Any) {
        pLabel.fadeIn()
        knobValue = paramKnob.value //Assume value is pre-clamped to range
        //Whata mess? Double or flost, pick simetohing!
        oldKnobValue = paramKnob.value
        if knobMode == 0 //select param  9/13 changes
        {
            selectedField = Int(knobValue)  //9/17 remember field...
            if whatWeBeEditing == "voice"  {loadCurrentVoiceParams()} //10/18
            if whatWeBeEditing == "shape"  {loadCurrentShapeParams()} //10/18
            updateSelectParamName()
        }
        else //edit param
        {
            let fname = selectedFieldName.lowercased()
            setNewParamValue(fname: fname,newval: knobValue)
        } //end else
        fadeTimer.invalidate() //Get rid of any older timer
        //If knob is inactive for 4 seconds fadeout info
        fadeTimer = Timer.scheduledTimer(timeInterval: 4.03, target: self, selector: #selector(self.fadeOutParamLabel), userInfo:  nil, repeats: false)
    }
    
    //=======>ARKit MainVC===================================
    @objc func fadeOutParamLabel()
    {
        pLabel.fadeOut()
    }
    
    
    //=======>ARKit MainVC===================================
    // called when user starts param edit
    func getLastParamValue(fname : String)
    {
        if whatWeBeEditing == "voice" //10/18
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
            case "name":      lastFieldString = selectedVoice.OVS.name
            selectedMarker.updatePanels(nameStr: selectedVoice.OVS.name)  //10/11
            default:print("Error:Bad voice param")
            }
        } //end whatWeBeEditing
       else if whatWeBeEditing == "shape" //10/19
        {
            switch (fname)
            {
            case "texture" : lastFieldString = selectedShape.texture
            case "rotation": lastFieldDouble = selectedShape.rotSpeed
            case "rotationtype": lastFieldDouble = selectedShape.rotation
            case "xpos": lastFieldDouble = selectedShape.xPos
            case "ypos": lastFieldDouble = selectedShape.yPos
            case "zpos": lastFieldDouble = selectedShape.zPos
            case "texxoffset": lastFieldDouble = selectedShape.uCoord
            case "texyoffset": lastFieldDouble = selectedShape.vCoord
            case "texxscale": lastFieldDouble = selectedShape.uScale
            case "texyscale": lastFieldDouble = selectedShape.vScale
            default:print("Error:Bad shape param")
            }
        }
    } //end getLastParamValue
    
    //=======>ARKit MainVC===================================
    // 10/21 switch to dict for latHandles,etc
    func updateSelected3DMarker ()
    {
        if let llatHandle = latHandles[selectedMarkerName]
        {
            if let llonHandle = lonHandles[selectedMarkerName]
            {
                llatHandle.eulerAngles = SCNVector3Make(0, 0, Float(selectedVoice.OVS.yCoord))
                llonHandle.eulerAngles = SCNVector3Make(0, Float(selectedVoice.OVS.xCoord), 0)
            }
        }
    }
    
    
    //=======>ARKit MainVC===================================
    func updateSelected3DShape ()
    {
        if let sshape = shapes[selectedShapeName]
        {
            sshape.position = SCNVector3(selectedShape.xPos ,selectedShape.yPos ,selectedShape.zPos )
            sshape.setTextureScaleAndTranslation(xs: Float(selectedShape.uScale),
                                                 ys: Float(selectedShape.vScale),
                                                 xt: Float(selectedShape.uCoord),
                                                 yt: Float(selectedShape.vCoord)
            )
            //10/23 pass texture scaling/offsets to bitmap object too
            sshape.bmp.setScaleAndOffsets(
                sx: selectedShape.uScale, sy: selectedShape.vScale,
                ox: selectedShape.uCoord, oy: selectedShape.vCoord)
        }
    } //end updateSelected3DShape

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
    func setNewParamValue(fname : String,newval : Float)
    {
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
        if whatWeBeEditing == "voice" //10/18
        {
            switch (fname)  //10/9 cleanup
            {
            case "latitude":
                selectedVoice.OVS.yCoord = dknobval
                updateSelected3DMarker ()
            case "longitude":
                selectedVoice.OVS.xCoord = dknobval
                updateSelected3DMarker ()
            case "patch":
                if intChoiceChanged{ changeVoicePatch(name:getSelectedFieldStringForKnobValue (kv : knobValue))}
            case "type":
                if intChoiceChanged
                {
                    workString = getSelectedFieldStringForKnobValue (kv : knobValue)
                    changeVoiceType(typeString:workString , needToRefreshOriginalValue: needToRefreshOriginalValue)
                    selectedMarker.updateType(newType : workString)
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
            default: needRefresh = false
            } //end switch
        } //end voice edit
        else if whatWeBeEditing == "shape" //10/19
        {
            var needUpdate = true
            var newSpeed   = false
            switch (fname)
            {
            case "texture" : selectedShape.texture = lastFieldString //WTF?? TBD
                needUpdate = false
            case "rotation": selectedShape.rotSpeed = dknobval
                needUpdate = false
                newSpeed   = true
            case "rotationtype": selectedShape.rotation = dknobval
                setRotationTypeForSelectedShape()
                newSpeed   = true
            case "xpos": selectedShape.xPos         = dknobval
            case "ypos": selectedShape.yPos         = dknobval
            case "zpos": selectedShape.zPos         = dknobval
            case "texxoffset": selectedShape.uCoord = dknobval
            case "texyoffset": selectedShape.vCoord = dknobval
            case "texxscale": selectedShape.uScale  = dknobval
            case "texyscale": selectedShape.vScale  = dknobval
            default: needRefresh = false
            }
            if needUpdate { updateSelected3DShape () }
            if newSpeed   { setRotationSpeedForSelectedShape(s : selectedShape.rotSpeed)}
 
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
        var irot = Int(selectedShape.rotation)
        if irot > 0
        {
            if irot > 8 {irot = 8}
            rspeed = 60.0 / Double(OVtempo) //time for one beat
            rspeed = rspeed * 4.0 * Double(irot) //4/4 timing, apply rot type
        }
        //OK set up rotation
        setRotationSpeedForSelectedShape(s : rspeed)
    } //end setRotationTypeForSelectedShape
    
    //=======>ARKit MainVC===================================
    func setRotationSpeedForSelectedShape(s : Double)
    {
        if let sshape = shapes[selectedShapeName]
        {
            selectedShape.rotSpeed = s
            sshape.setTimerSpeed(rs: selectedShape.rotSpeed)
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
    func editVoiceParams()
    {
        whatWeBeEditing = "voice"
        selectedField = 0
        knobMode = 0
        updateWheelAndParamButtons()
        loadCurrentVoiceParams()
        pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
            pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
            choiceStrings : voiceParamNames)
        pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
        paramKnob.wraparound = true   //10/5 wraparound
    }
    
    //=======>ARKit MainVC===================================
    func editShapeParams()
    {
        whatWeBeEditing = "shape"
        selectedField = 0
        knobMode = 0
        updateWheelAndParamButtons()
        loadCurrentShapeParams()
        pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
            pmin : 0.0 , pmax : selectedFieldDMult * Double( selectedFieldMax) ,
            choiceStrings : shapeParamNames)
        pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
        paramKnob.wraparound = true   //10/5 wraparound
    }
    
    //=======>ARKit MainVC===================================
    // 10/10 redo
    func restoreLastParamValue(oldD : Double , oldS : String)
    {
        if whatWeBeEditing == "voice" //10/18
        {
            switch (selectedFieldName.lowercased())  //which param?
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
            case "name":        selectedVoice.OVS.name        = oldS
            default: print("restoreLastParam: bad voice ptype")
            }
        } //end voice
        else if whatWeBeEditing == "shape"
        {
            switch (selectedFieldName.lowercased())
            {
            case "texture" : selectedShape.texture  = oldS
            case "rotation": selectedShape.rotSpeed =  oldD
            case "rotationtype": selectedShape.rotation = oldD
            case "xpos":       selectedShape.xPos = oldD
            case "ypos":       selectedShape.yPos = oldD
            case "zpos":       selectedShape.zPos = oldD
            case "texxoffset": selectedShape.uCoord = oldD
            case "texyoffset": selectedShape.vCoord = oldD
            case "texxscale":  selectedShape.uScale = oldD
            case "texyscale":  selectedShape.vScale = oldD
            default: print("restoreLastParam: bad shape ptype")
            }
        } //end shape

    } //end restoreLastParamValue
    
    
    
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
                let fname = vArray[i] as! String
                selectedFieldStringVals.append(fname)
                //10/26 handle GM SAMPLE patches specially..
                if selectedFieldName.lowercased() == "patch" &&
                    selectedVoice.OOP.type == SAMPLE_VOICE
                {
                    selectedFieldDisplayVals.append( //try to get instrument name...
                        allP.getInstrumentNameFromGMFilename(fname: fname))
                }
                else // non-patches, just display the field strings
                { selectedFieldDisplayVals.append(fname) }
            }
            if selectedFieldName == "patch"
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
        vArray = selectedShape.getNthParams(n: selectedField)
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
                selectedFieldStringVals.append(vArray[i] as! String)
                selectedFieldDisplayVals.append(vArray[i] as! String)
            }
            selectedFieldMin = 0.0 //DHS 9/22 wups need range for strings
            selectedFieldMax = Float(selectedFieldStringVals.count - 1)
        }
        getLastParamValue(fname : selectedFieldName.lowercased()) //10/12 Load up current param
        //print("loadshape sfsv \(selectedFieldStringVals)   sfdv \(selectedFieldDisplayVals)")
    } //end loadCurrentShapeParams
    
    //=======>ARKit MainVC===================================
    // updates param display w/ current param and value
    func updateSelectParamName()
    {
        let dogStrings = ["nfixed","vfixed","pfixed","topmidi","bottommidi","midichannel"]
        
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
            pstr = selectedVoice.OVS.name
        }
        else if selectedFieldType == "texture" //10/9 new field type
        {
            pstr = selectedShape.texture //10/22 is this the only texture?
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
        let sceneView = skView!
        touchLocation = latestTouch.location(in: sceneView)
        //print("tb \(touchLocation)")
        guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
        let hitNode = nodeHitTest.node
        if let name = hitNode.name
        {
            if name.contains("shape") //Found a shape? get which one
            {
                let testName = findShape(uid: name)
                if (testName != "")
                {
                    // is a voice selected? deselect!
                    if whatWeBeEditing == "voice" { selectedMarker.unHighlight() }
                    // is another shape selected? deselect!
                    if selectedSphere.highlighted && selectedShapeName != testName
                        { selectedSphere.unHighlight() }
                    selectedShapeName = testName
                    if let testShape = shapes[selectedShapeName] //10/21
                    {
                        selectedSphere = testShape
                        selectedSphere.toggleHighlight()
                        whatWeBeEditing = ""
                        //Wow is this redundant?
                        selectedSphere.updatePanels(nameStr: selectedSphere.name!)
                        if selectedSphere.highlighted  //hilited? Set up edit
                        {
                            if let smname = selectedSphere.name
                            {
                                if let testShape = sceneShapes[smname] //got legit voice?
                                {
                                    selectedShape     = testShape
                                    selectedShapeName = smname //10/21
                                    editShapeParams()
                                }
                            }
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
                    // is a shape selected? deselect!
                    if whatWeBeEditing == "shape" { selectedSphere.unHighlight() }
                    // is a different marker selected? deselect!
                    if selectedMarker.highlighted &&
                        selectedMarkerName != newMarker.name
                        { selectedMarker.unHighlight() }
                    selectedMarker = newMarker           // get our marker...
                    selectedMarker.toggleHighlight()
                    whatWeBeEditing = ""
                    if selectedMarker.highlighted  //hilited? Set up edit
                    {
                        if let smname = selectedMarker.name
                        {
                            if let testVoice = sceneVoices[smname] //got legit voice?
                            {
                                selectedVoice = testVoice //Get associated voice for this marker
                                selectedMarkerName = smname //points to OVS struct in scene
                                selectedMarker.updatePanels(nameStr: selectedMarkerName) //10/11 add name panels
                                if let ovs = OVScene.voices[smname]
                                {
                                    selectedVoice.OVS = ovs       //get associated voice info
                                    editVoiceParams() //this also update screen
                                }
                            }
                        } //end if let
                    }
                    else //not highlighted? close edit
                    {
                        deselectVoice()
                    }
                } //end if selected...
            } //end if name
        }    // end if let name
    } //end touchesBegan
    
    func deselectVoice()
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
        let alert = UIAlertController(title: "Menu", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Load New Scene", style: .default, handler: { action in
            print("Load New Scene...")
            self.OVScene = DataManager.loadScene("default", with: OogieScene.self)
        }))
        alert.addAction(UIAlertAction(title: "Clear Scene", style: .default, handler: { action in
            print("Clear Scene...")
            self.clearScene()
        }))
        alert.addAction(UIAlertAction(title: "Save Scene", style: .default, handler: { action in
            print("Save Scene...")
            self.packupSceneAndSave()
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
        var tstr = "Solo"
        if soloVoiceID != "" {tstr = "UnSolo"}
        let alert = UIAlertController(title: "Voice Menu", message: nil, preferredStyle: UIAlertControllerStyle.alert)
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
            self.deselectVoice()
        }))

        tstr = "Mute"
        if selectedVoice.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            self.selectedVoice.muted = !self.selectedVoice.muted
            self.selectedMarker.toggleHighlight()
            self.deselectVoice()
        }))
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.selectedVoice.OVS, name: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
           self.deleteVoicePrompt(voice: self.selectedVoice)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end voiceMenu
    
    //=====<oogie2D mainVC>====================================================
    // 10/26 shape popup... various functions
    func shapeMenu()
    {
        let alert = UIAlertController(title: "Shape Menu", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addShapeToScene(shape: self.selectedShape, name: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShapePrompt(shape: self.selectedShape)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end shapeMenu
    
    
    //=====<oogie2D mainVC>====================================================
    func deleteShapePrompt(shape:OogieShape)
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
    func deleteShape(shape:OogieShape)
    {
        let name = shape.name
        if let shape3D = shapes[name]
        {
            shape3D.removeFromParentNode()    //Blow away 3d Shape
            shapes.removeValue(forKey: name) // delete of dict entries
            sceneShapes.removeValue(forKey: name)
        }
    } //end deleteShape
    
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
        if let lonHandle = lonHandles[name] //3D marker is child of this...
        {
            lonHandle.removeFromParentNode()    //Blow away 3d Shape/children
            allMarkers.remove(at: selectedObjectIndex)
            sceneVoices.removeValue(forKey: name)
        }
    } //end deleteVoice


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
    func clearScene()
    {
        let alert = UIAlertController(title: "Clear Current Scene?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.OVScene.clearScene()
            self.clearAllNodes(scene: self.scene)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    //=====<oogie2D mainVC>====================================================
    func clearAllNodes(scene:SCNScene)
    {
        scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
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
    } //end create3DScene

    //=====<oogie2D mainVC>====================================================
    // 10/26 break out for cloning / creating / etc
    func addShapeToScene (shape:OogieShape , name : String, op : String)
    {
        if shape.primitive == "sphere"
        {
            var newName       = name
            let sphereNode    = SphereShape() //make new 3d shape, texture it
            var newOogieShape = OogieShape() // make new data model for shape too
            sphereNode.setBitmap(s: shape.texture)
            sphereNode.bmp.setScaleAndOffsets(
                sx: shape.uScale, sy: shape.vScale,
                ox: shape.uCoord, oy: shape.vCoord)
            //finally, place 3D object as needed..
            newOogieShape     = shape //Copy in our shape to be cloned...
            if op != "load" // 10/26 clone / new object? need to get new XYZ
            {
                sphereNode.position = getFreshXYZ()
                newOogieShape.xPos = Double(sphereNode.position.x)
                newOogieShape.yPos = Double(sphereNode.position.y)
                newOogieShape.zPos = Double(sphereNode.position.z)
                newName = "shape" + String(format: "%03d", 1 + sceneShapes.count)
                newOogieShape.name = newName
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
            scene.rootNode.addChildNode(sphereNode)
            sceneShapes[newName] = newOogieShape  //save latest shap to working dictionary
            shapes[newName]      = sphereNode //10/21
        } //end if primitive...
    } //end addShapeToScene
    
    
    //======(OogieScene)=============================================
    // 10/26 look at shape Dict, get unused XYZ area for new shape
    //   get centroid first, then go " around the clock"
    func getFreshXYZ() -> SCNVector3
    {
        var X : Double = 0.0
        var Y : Double = 0.0
        var Z : Double = 0.0
        var Xmin : Double =  9999.0
        var Xmax : Double = -9999.0
        var Ymin : Double =  9999.0
        var Ymax : Double = -9999.0
        var Zmin : Double =  9999.0
        var Zmax : Double = -9999.0
        var c : Double = 0.0
        for (_,nextShape) in sceneShapes
        {
            X = X + nextShape.xPos
            Y = Y + nextShape.yPos
            Z = Z + nextShape.zPos
            Xmin = min(Xmin,nextShape.xPos)
            Xmax = max(Xmax,nextShape.xPos)
            Ymin = min(Ymin,nextShape.yPos)
            Ymax = max(Ymax,nextShape.yPos)
            Zmin = min(Zmin,nextShape.zPos)
            Zmax = max(Zmax,nextShape.zPos)
            c = c + 1.0
        }
        if c == 0 {return SCNVector3Zero}
        var newPos3D = SCNVector3Make(Float(X/c), Float(Y/c), Float(Z/c))
        var outerRad = Float(sqrt((Xmax-Xmin) + (Zmax-Zmin))/2.0)
        outerRad += 3.0
//        print("centroid \(newPos3D) , outerRad \(outerRad)")
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

    //=====<oogie2D mainVC>====================================================
    // 10/26 break out for cloning / creating / etc
    func addVoiceToScene(nextOVS : OVStruct , name : String, op : String)
    {
//        if let voiceShape = OVScene.shapes[nextOVS.shapeName] //Get corresponding shape for this voice
        if let voiceShape = sceneShapes[nextOVS.shapeName] //10/27 redu Get corresponding
        {
            var newOVS    = nextOVS
            var newName   = newOVS.name
            let nextVoice = OogieVoice()
            if op == "load" //Loading? Remember name!
            {
                nextVoice.OVS = newOVS
            }
            //Finish filling out voice structures
            nextVoice.OOP = allP.getPatchByName(name:newOVS.patchName)
            //10/27 support cloning.. just finds unused lat/lon space on same shape
            if op == "clone"
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
            if voiceShape.primitive == "sphere" || voiceShape.primitive == "default" //Sphere has 2 handles...
            {
                let lonHandle = SCNNode()
                let latHandle = SCNNode()
                if let shape3D = shapes[nextVoice.OVS.shapeName] //10/21 find shape 3d object
                {
                    shape3D.addChildNode(lonHandle) //10/21 add handle to shape parent
                    lonHandle.addChildNode(latHandle)
                    //Lat / Lon Marker to select color
                    let nextMarker = Marker()
                    nextMarker.name = newName //9/16 point to voice
                    let theta = -pi/2.0 //Point bottom of cone marker at earth
                    nextMarker.rotation = SCNVector4Make(0, 0, 1, Float(theta))
                    //10/24 position varies by platform
                    #if VERSION_2D
                    nextMarker.position = SCNVector3Make(1.0, 0, 0);
                    #elseif VERSION_AR
                    nextMarker.position = SCNVector3Make(0.5, 0, 0);
                    #endif

                    allMarkers.append(nextMarker)
                    latHandle.addChildNode(nextMarker)
                    // DHS 9/26 set angles from voice XY coords...
                    latHandle.eulerAngles = SCNVector3Make(0, 0, Float(nextVoice.OVS.yCoord))
                    lonHandle.eulerAngles = SCNVector3Make(0, Float(nextVoice.OVS.xCoord), 0)
                    latHandles[newName] = latHandle
                    lonHandles[newName] = lonHandle
                }
                else
                {
                    print("error find shape for voice \(nextVoice.OVS.name)")
                }
            }
        } //end if let
    } //end addVoiceToScene

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
    func packupSceneAndSave()
    {
        //10/26 first we need to clean target...
        OVScene.voices.removeAll()
        OVScene.shapes.removeAll()
        //update scene with any changed voice paras...
        for (name, _) in sceneVoices //10/26 wups
        {
            OVScene.voices[name] = sceneVoices[name]?.OVS
        }
        for (name,nextShape) in sceneShapes
        {
            OVScene.shapes[name] = nextShape
        }
        DataManager.saveScene(self.OVScene, with: "default")
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
    // 10/21 shapes become dictionary
    func findShape(uid:String) -> String
    {
        for (name,shape) in shapes
        {
            if uid == shape.uid { return name }
        }
        return ""
    } //end findShape

    //=====<oogie2D mainVC>====================================================
    // Get color samples, output music!
    // called by timer repeatedly...
    @objc func playAllMarkers()
    {
        if (allMarkers.count == 0) {return;}

        //iterate thru dictionary of voices...
        for counter in 0...allMarkers.count-1
        {
            var workVoice  = OogieVoice()
            let nextMarker = allMarkers[counter]
            // 10/14 wups, wrong counter compare!
            // 10/22 only while editing voices here!
            if whatWeBeEditing == "voice" && knobMode != 0 && counter == selectedObjectIndex //selected and editing? load edited voice
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
                    nextMarker.setColorRGB(rr: rgbaTuple.R, gg: rgbaTuple.G, bb: rgbaTuple.B)
                    setupSynthOrSample(oov: workVoice) //load synth ADSR, send note out
                    if playColors(oov: workVoice , rr: rgbaTuple.R, gg: rgbaTuple.G, bb: rgbaTuple.B)
                    { nextMarker.updateActivity() } //DHS 10/22 animate marker each note played..
                }
            }
        } //end for name...
    } //end playAllMarkers

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
       // updateMarkerPosition(lat: 0,lon: 0)
        
        if (knobMode == 0) //User not editing a parameter? this is a menu button
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
            restoreLastParamValue(oldD: lastFieldDouble,oldS: lastFieldString) //DHS 10/10
            if selectedFieldType == "double"  //update marker as needed...
            {
                if whatWeBeEditing == "voice"
                {
                    updateSelected3DMarker ()
                }
                else if whatWeBeEditing == "shape"
                {
                    updateSelected3DShape ()
                }
            }
            knobMode = 0 //back to select mode
            updateWheelAndParamButtons()
        }
    }
    

    
    //=====<oogie2D mainVC>====================================================
    // take unit xy coords from voice, apply to our sphere..
    func updatePointer()
    {
        //print("XYCoord \(OV.OVS.xCoord),\(OV.OVS.yCoord)")
 //9/7 redpo        let lonAngle = twoPi * OV.OVS.xCoord
 //9/7 redpo        let latAngle = -pi   * OV.OVS.yCoord + pi/2
 //9/7 redpo        updateMarkerPosition(lat:Double(latAngle) , lon: Double(lonAngle))
    }

    
    // look at current xy, get color based on bmp
    //=====<oogie2D mainVC>====================================================
    // 8/23 assumes only one shape and only one pointer!
    //  XYCoord are in radian units, Y is -pi/2 to pi/2
    //   most math is done in 0..1 XY coords, then bmp size applied
    func getShapeColor(shape: SphereShape, xCoord : Double , yCoord : Double , angle : Double) -> (R:Int , G:Int , B:Int , A:Int)
    {
        let aoff = Double.pi / 2.0  //10/25 why are we a 1/4 turn off?
        var xpercent = (angle + aoff) / twoPi
        xpercent = xpercent + xCoord
        //xpercent = xpercent - 0.125 //why rotate 1/8??
        xpercent = -1.0 * xpercent //      and flip X direction
        //Keep us in range 0..1
        while xpercent > 1.0 {xpercent = xpercent - 1}
        while xpercent < 0.0 {xpercent = xpercent + 1}
        let ypercent = 1.0 - ((yCoord + .pi/2) / .pi)
        let bmpX = Int(Double(shape.bmp.wid) * xpercent)
        let bmpY = Int(Double(shape.bmp.hit) * ypercent) //9/15 redo!
        let cp = CGPoint(x: bmpX, y: bmpY)
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
    // update marker position, brute force
    func updateMarkerPosition (lat : Double,lon : Double)
    {
        //8/23 Rotate our marker handles to position marker at lat/lon
        if let llonHandle = lonHandles[selectedMarkerName]
        {
            if let llatHandle = latHandles[selectedMarkerName]
            {
                llonHandle.eulerAngles = SCNVector3Make(0, Float(lon), 0)
                llatHandle.eulerAngles = SCNVector3Make(0, 0, Float(lat))
            }
        }
    } //end updateMarkerPosition
    
    
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
            oop.saveItem() //Write it out!
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
                oop.saveItem() //Write it out!
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
                oop.saveItem() //Write it out!
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
            (sfx() as! soundFX).buildEnvelope(0); //arg whichvoice?
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

            //DHS 10/14 set up pointer to percussion sample...
            oov.bufferPointer = Int((sfx() as! soundFX).getGMBuffer(oov.OOP.name))
            (sfx() as! soundFX).buildEnvelope(Int32(oov.bufferPointer)); //arg whichvoice?
        }
    } //end setupSynthOrSample
    
    //=====<oogie2D mainVC>====================================================
    // uses color and voice params to produce music
    func playColors(oov : OogieVoice , rr : Int ,gg : Int ,bb : Int) -> Bool
    {
        var inkeyNote = 0
        var inkeyOldNote = 0
        var midiNote = 64
        oov.setInputColor(chr: rr, chg: gg, chb: bb)
        midiNote  = oov.midiNote
        let nchan = oov.nchan
        let pchan = oov.pchan
        let vchan = oov.vchan
        //DHS TEST ONLY!!! this should be modulated by vchan ? depending on voice mode
        (sfx() as! soundFX).setSynthGain(128)
        
        var noteWasPlayed = false
        
        //NSLog("....npvchan %d %d %d",nchan,pchan,vchan)
        let vt    = oov.OOP.type
        if midiNote > 0 //Play something?
        {
            //NSLog("Midinote %d",midiNote)
            (sfx() as! soundFX).setSynthMIDI(Int32(oov.OVS.midiDevice), Int32(oov.OVS.midiChannel)) //chan: 0-16
            let nc = (sfx() as! soundFX).getSynthNoteCount()
            inkeyOldNote = oov.oldNote
            inkeyNote    = Int((sfx() as! soundFX).makeSureNoteis(inKey: Int32(oov.OVS.keySig),Int32(midiNote)))
            // Mono: Handle releasing old note...
            if oov.OVS.poly == 1 {(sfx() as! soundFX).releaseNote(Int32(inkeyOldNote),0)} //2nd arg, WTF??
            //TBD....[synth setTimetrax:OVgettimetrax(vloop)];
            //New note outside tolerance?
            //print(" toler check: nchan \(nchan) lnchan \(oov.lnchan) nc \(nc) thresh \(oov.OVS.thresh)",nchan,oov.lnchan,nc )

            var mono = 1
            if oov.OVS.poly != 0 { mono = 0 }
            
            if (abs (nchan - oov.lnchan) > 1) && nc < 20  //TEST LOW TOLER
//            if (abs (nchan - oov.lnchan) > 2*oov.OVS.thresh) && nc < 20  //dhs was 12
            {
                (sfx() as! soundFX).setSynthMono(Int32(mono))
                (sfx() as! soundFX).setSynthMonoUN(Int32(oov.uniqueCount))
                var noteToPlay = -1
                var bptr = 0
                //-------SYNTH: built-in canned wave samples--------------------------
                if vt == SYNTH_VOICE
                {
                    (sfx() as! soundFX).setSynthGain(Int32(Double(vchan) * 0.7 * oov.OVS.level))
                    if oov.OVS.panMode != 11  //No fixed pan? Use pchan
                    {
                        (sfx() as! soundFX).setSynthPan(Int32(pchan))
                    }
                    else //Forced pan?
                    {
                        (sfx() as! soundFX).setSynthPan(Int32(oov.OVS.panFixed))
                    }
                    //portamento?
                    (sfx() as! soundFX).setSynthSampOffset(Int32(oov.OVS.sampleOffset))
                    inkeyNote = inkeyNote + masterPitch
                    noteToPlay = inkeyNote
                } //End synth block
                else if vt == HARMONY_VOICE
                {
                } //end harmony block
                else if vt == SAMPLE_VOICE //10/16 add GM samples
                {
                    (sfx() as! soundFX).setSynthGain(Int32(Double(vchan) * 0.7 * oov.OVS.level))
                    (sfx() as! soundFX).setSynthDetune(1);
                    (sfx() as! soundFX).setSynthPan(Int32(pchan))
                    bptr = oov.bufferPointer
                    inkeyNote = inkeyNote + masterPitch
                    noteToPlay = inkeyNote
                    //ok playit
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(inkeyNote), Int32(bptr) ,Int32(vt)) //Play Middle C for now...
                    }
                    else
                    {
                        (sfx() as! soundFX).queueNote(Int32(inkeyNote), Int32(bptr) ,Int32(vt))
                    }
                    noteWasPlayed = true
                } //end sample block 9/22
                else if vt == PERCUSSION_VOICE
                {
                    (sfx() as! soundFX).setSynthGain(Int32(Double(vchan) * 0.7 * oov.OVS.level))
                    (sfx() as! soundFX).setSynthDetune(0);
                    // 9/27 no trigger key,just trigger of tolerance..
                        (sfx() as! soundFX).setSynthPan(Int32(pchan))
                        bptr = oov.bufferPointer
                        noteToPlay = 32
                        //ok playit
                        if quantTime == 0 //No Quant, play now
                        {
                            (sfx() as! soundFX).playNote(32, Int32(bptr) ,Int32(vt)) //Play Middle C for now...
                        }
                        else
                        {
                            (sfx() as! soundFX).queueNote(32, Int32(bptr) ,Int32(vt))
                        }
                        noteWasPlayed = true
                } //end percussion block
                else if vt == PERCKIT_VOICE
                {
                    var topMidi = oov.OVS.topMidi
                    var botMidi = oov.OVS.bottomMidi
                    if (topMidi - botMidi < 10) //Handle illegal crap, thuis should be ELSEWHERE!!!
                    {
                        botMidi = 16
                        topMidi = 100
                    }
                    var octave = (nchan - botMidi) / 20 // 12 //get octave
                    octave = max(min(octave,7),0)
                    //10/15  CRASH HERE!!!
                    bptr = oov.bufferPointerSet[octave]
                    //print("note \(nchan) oct \(octave) bptr \(bptr)")
                    noteToPlay = 32

                } //end perckit block
                
                if noteToPlay != -1
                {
                    if quantTime == 0 //No Quant, play now
                    {
                        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(vt))
                    }
                    else
                    {
                        (sfx() as! soundFX).queueNote(32, Int32(bptr) ,Int32(vt))
                    }
                    noteWasPlayed = true
                    oov.lastnoteplayed = inkeyNote

                }
                oov.uniqueCount = Int((sfx() as! soundFX).getSynthUniqueCount())
                oov.hiLiteFrame = MAX_CBOX_FRAMES
                oov.oldNote = nchan
                oov.saveColors()
            } //end abs toler check
        } //end midinote...
        return noteWasPlayed
    } //end playColors
    
    
    
    //------<UITextFieldDelegate>-------------------------
    // 10/9  UITExtFieldDelegate...
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.text = "" //Clear shit out
        return true
    }
    //------<UITextFieldDelegate>-------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        lastFieldString = textField.text!
        setNewParamValue(fname: selectedFieldName.lowercased(),newval: knobValue)
        pLabel.isHidden = false //10/10 show param label again

        editSelect( editButton)  //Simulate button hit...
        textField.resignFirstResponder() //dismiss kb if up
        return true
    }
    //------<UITextFieldDelegate>-------------------------
    @IBAction func textChanged(_ sender: Any) {
        lastFieldString = textField.text!
        setNewParamValue(fname: selectedFieldName.lowercased(),newval: knobValue)
    }

    //--------<TextureVCDelegate.-------------------------------------
    func cancelled()
    {
        print("cancelled...")
        editSelect(editButton) // back to param select...
    }
    
    //--------<TextureVCDelegate.-------------------------------------
    func gotTexture(name: String, tex: UIImage)
    {
        if let sshape = shapes[selectedShapeName]
        {
            sshape.setBitmapImage(i: tex) //set 3d shape texture
            sshape.name           = name // save texture name
            selectedShape.texture = name
            editSelect(editButton)              // leave edit mode
            print("selected...\(sceneVoices)")
        }
    }

} //end vc class, line 1413 as of 10/10

