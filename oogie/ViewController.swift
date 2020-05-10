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
//  2/4    redo name , comment fields for voice and ahape
//  2/5    move name into pipeStruct, add comment there too
//  2/6    redo deleteShape to delete all voices, and voice/shape pipes
//          make all menus w/ black text, get newname in addPipeToScene
//  2/28   add 3d Keyboard, 2/29 hook up with touch so it plays current voice!
//  3/30   add kb update after voice edit
//  4/19   add setMasterPitchShiftForAllVoices
//  4/26   pull restoreLastParamValue, use setNewParamValue instead,add int params
//  4/27   finish debugging parameters, add setParam to playAllPipesMarkers pipe handler
//  4/28   replacer allMarkers array with markers3D dict,pipes->pipes3D,shapes->shapes3D
//          peel off 3d part of voice/shape to separate methods
//  4/29   add OSCStruct to OogieScene, migrate scene related vars/methods from here
//  5/2    add updatePipeByUID,updatePipeByShape
//  5/3    move playColors to oogieVoice, move bmp from 3dShape to oogieShape,
//          change knobMode to string move playAllPipesMarkers to oogieScene,
//          add handlePipesMarkersAnd3D
//  5/4    change deleteVoice and deleteShape to work with keys,
//          also halt Shape timers b4 delete
//         add notification between playAllPipes in OogieScene and handle3DUpdates
//  5/8    update chooser protocol, add chooserCancelled, add haltLoop and startLoop
//           around file loads
import UIKit
import SceneKit
import Photos

let pi    = 3.141592627
let twoPi = 6.2831852

//Scene unpacked params live here for now...
var OVtempo = 135 //Move to params ASAP
var camXform = SCNMatrix4()

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,chooserDelegate,UIGestureRecognizerDelegate,patchEditVCDelegate,SCNSceneRendererDelegate {

    @IBOutlet weak var skView: SCNView!
    @IBOutlet weak var spnl: synthPanel!
    @IBOutlet weak var editButtonView: UIView!
    @IBOutlet weak var paramKnob: Knob!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var editButton: UIButton!

    var colorTimer = Timer()
    var playColorsTimer = Timer()
    var pLabel = infoText()
    //10/29 version info (mostly for debugging)
    var version = ""
    var build   = ""
    //10/17 solo
    var soloVoiceID = ""
    var touchLocation = CGPoint()
    var latestTouch   = UITouch()
    var chooserMode = "loadAllPatches"
    var shouldNOTUpdateMarkers = false

    var updatingPipe = false   //1/25
    //12/2 haptics for wheel controls
    var fbgenerator = UISelectionFeedbackGenerator()
    

    //10/27 for finding new marker lat/lons
    let llToler = Double.pi / 10.0
    let llStep  = Double.pi / 8.0 //must be larger than toler
    
    var whatWeBeEditing = "" //voice, shape, pipe, etc...

    //Params knob
    var oldKnobValue    : Float = 0.0
    var oldKnobInt      : Int = 0    //1/14
    var knobValue       : Float = 0.0 //9/17 rename
    var knobMode        = "select"

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    
    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    var recentlyEditedPatches : [String] = []

    // 3D scene starting pos (used in AR version)
    var startPosition = SCNVector3(x: 0, y: 0, z:0)
    // 3D objects
    var cameraNode        = SCNNode()
    let scene             = SCNScene()
    var selectedMarker    = Marker()
    var selectedSphere    = SphereShape()  //10/18
    var selectedPipeShape = PipeShape()   //11/30
    // Dictionaries of 3D nodes
    var shapes3D      = Dictionary<String, SphereShape>()
    var markers3D     = Dictionary<String, Marker>()
    var pipes3D       = Dictionary<String, PipeShape>()
    var oogieOrigin = SCNNode() //3D origin, all objects added to this parent
    var pkeys = PianoKeys()    //3D keys for playing test samples


    // Overall scene, performs bulk of data workload
    var OVScene           = OogieScene()
    var OVSceneName       = "default"
    var isPlaying         = false
    var updating3D        = false

   //=====<oogie2D mainVC>====================================================
    override func viewDidLoad() {
        super.viewDidLoad()
        //Cleanup any margin problems w/ 3D view not perfectly fitting
        self.view.backgroundColor = .black

        //Our basic camera, out on the Z axis
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        selectedSphere.key = "empty" //this keeps keys clean when timer goes off

        //2/6 get bounding sphere, place camera according.y
        //let sss = oogieOrigin.boundingSphere
        //let radius = sss.radius //radius of scene bounding sphere,
        //cameraNode.position = SCNVector3(x:0, y: 0, z: 10*radius)

        cameraNode.position = SCNVector3(x:0, y: 0, z: 6)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 2)
        
        scene.rootNode.addChildNode(lightNode)
        let sceneView   = skView!
        sceneView.delegate = self //5/10 why no workie?
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
        camXform.m43 = 6.0   //5/1 back off camera on z axis
        //Get our default scene, move to appdelegate?
        if DataManager.sceneExists(fileName : "default")
        {
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            self.OVScene.OSC = DataManager.loadScene("default", with: OSCStruct.self)
            self.OVScene.OSC.unpackParams()       //DHS 11/22 unpack scene params
            self.OVScene.sceneLoaded = true
            self.OVScene.OSC.name = OVSceneName //DHS 5/10 wups
            #if VERSION_2D
            setCamXYZ() //11/24 get any 3D scene cam position...
            #endif
            print("...load default scene")
        }
        else
        {
            self.OVScene.createDefaultScene(named: "default")
            self.OVScene.OSC.setDefaultParams()
            print("...no default scene found, create!")
            self.OVScene.sceneLoaded = true  //5/7
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

        //5/4 add notification for 3D updates from color player...
        NotificationCenter.default.addObserver(self, selector: #selector(self.got3DUpdates(notification:)), name: Notification.Name("got3DUpdatesNotification"), object: nil)

        
        //11/18  Update markers UI in foreground on a timer
        colorTimer = Timer.scheduledTimer(timeInterval: 0.03, target: self, selector: #selector(self.updateAllMarkers), userInfo:  nil, repeats: true)
        _ = DataManager.getSceneVersion(fname:"default")

        //4/20 try foreground timer...
//        playColorsTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.handlePipesMarkersAnd3D), userInfo:  nil, repeats: true)

        //Try running color player in bkgd...
        OVScene.startLoop()

        
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
    // 5/4 Called from notification got3DUpdatesNotification
    @objc func got3DUpdates(notification: NSNotification)
    {
        if let uinfo = notification.userInfo
        {
            let updates3D = uinfo["updates3D"] as! [String] //array
            handle3DUpdates(updates3D:updates3D)
        }
    } //end got3DUpdates


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
        //4/26 Dig up defaults value and save
        let sceneChanges = OVScene.setNewParamValue(editing : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(OVScene.selectedFieldDefault),
                                toString : OVScene.selectedFieldDefaultString )
        update3DSceneForSceneChanges(sceneChanges)
        knobValue = Float(OVScene.selectedFieldDefault)  //9/17 make sure knob is set to param value
        selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
        resetKnobToNewValues(kval:knobValue , kmin : OVScene.selectedFieldMin , kmax : OVScene.selectedFieldMax)
    }
    
    //=====<oogie2D mainVC>====================================================
    func updateAllShapeRotations()
    {
        for (key,shape3D) in shapes3D
        {
            //get rotation from oogieshape
            if let shape = OVScene.sceneShapes[key]
            {
                shape3D.setAngle(a:shape.angle)  //update 3d Shape
            }
        }
    } //end updateAllShapeRotations
    
    
    //=====<oogie2D mainVC>====================================================
    // input is a list of strings, go through it and
    //   perform 3d scene updates as needed
    // called after voice/shape/pipe params get changed
    func update3DSceneForSceneChanges(_ sceneChanges:[String])
    {
        for r in sceneChanges //loop over array of update indicators
        {
            switch r
            {
            case "movemarker": // Marker moved?
                selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
            case "updatevoicetype": // New Voice type?
                selectedMarker.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))
            case "updatevoicename":  // Voice name changed?
                selectedMarker.updatePanels(nameStr: OVScene.selectedVoice.OVS.name)
            case "updatevoicepipe":  // Pipe moved?
                if !updatingPipe { updatePipeByVoice(v:OVScene.selectedVoice) }
            case "updateshape":  // Shape changed/moved?
                update3DShapeByKey (key:OVScene.selectedShapeKey)
            case "updateshapename":  // Shape name/comment changed?
                selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                               comm: OVScene.selectedShape.OOS.comment)
            case "updaterotationtype":  // Change rotation type?
                setRotationTypeForSelectedShape()
            case "updateshapepipe":  // Pipe moved?
                if !updatingPipe { updatePipeByShape(s:OVScene.selectedShape) }
            case "updatepipe":  // Pipe label / etc needs changing?
                if let pipe3D = pipes3D[OVScene.selectedPipeKey] //12/5 USE SCENE-LOADED NAME!
                {
                    //12/5 update pipe label and graphfff
                    pipe3D.updateInfo(nameStr: OVScene.selectedPipe.PS.name, vals: OVScene.selectedPipe.ibuffer)
                    pipe3D.pipeColor = pipe3D.getColorForChan(chan: OVScene.selectedPipe.PS.fromChannel)
                }
            default: break
            }
        }
    } //end update3DSceneForSceneChanges

    //=====<oogie2D mainVC>====================================================
    // 9/12 RH edit button, over rotary knob, toggles edit / param mode
    @IBAction func editSelect(_ sender: Any) {
        if (knobMode == "select")  //5/3 Change to Edit parameter??
        {
            knobMode = "edit"   //5/3
            //Load up old vals for cancel operation
            OVScene.getLastParamValue(editing :whatWeBeEditing,
                                        named : OVScene.selectedFieldName.lowercased())
            knobValue = Float(OVScene.lastFieldDouble)  //9/17 make sure knob is set to param value
            OVScene.lastFieldSelectionNumber = Int(knobValue) //remember knob value to restore old deault
            pLabel.updateLabelOnly(lStr:"Edit:" + OVScene.selectedFieldName)

            if OVScene.selectedFieldMax == OVScene.selectedFieldMin {print("ERROR: no param range")}
            //12/15 textfield and plabel occupy same screen space!
            //  maybe a ui update area is where this belongs!??
            textField.isHidden = OVScene.selectedFieldType != "text"
            pLabel.isHidden    = OVScene.selectedFieldType == "text" //12/15
            if OVScene.selectedFieldType == "text" //4/28 add text placeholder, set kb type
            {
                textField.placeholder = OVScene.selectedFieldName
                //4/28 NEED TO set keyboard type based on field name!!!
                // as such we need an array of "numeric" text fields, gathered
                // from voice/shape/pipe objects and see if our fieldName is in there
                // otherwise set kb type to default!!!
                //for now we use a KLUGE!!!
                textField.keyboardType = .default
                let needNumeric = (OVScene.selectedFieldName == "LoRange" || OVScene.selectedFieldName == "HiRange")
                if needNumeric {textField.keyboardType = UIKeyboardType.numbersAndPunctuation}
            }
            //Set up display for the param
            if OVScene.selectedFieldType == "double"
            {
                pLabel.setupForParam( pname : OVScene.selectedFieldName , ptype : TFLOAT_TTYPE , //9/28 new
                    pmin : OVScene.selectedFieldDMult * Double(OVScene.selectedFieldMin) , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : [])
                paramKnob.wraparound = false //10/5 wraparound
                pLabel.showWarnings  = true  // 10/5 warnings OK
            }
            else if OVScene.selectedFieldType == "int" //4/26 int ptype
            {
                pLabel.setupForParam( pname : OVScene.selectedFieldName , ptype : TINT_TTYPE ,
                    pmin : OVScene.selectedFieldDMult * Double(OVScene.selectedFieldMin) , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : [])
                paramKnob.wraparound = false //10/5 wraparound
                pLabel.showWarnings  = true  // 10/5 warnings OK
            }
            else if OVScene.selectedFieldType == "string"
            {
                //10/18 DHS for GM patches, here we need to substitute
                
                pLabel.setupForParam( pname : OVScene.selectedFieldName , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : OVScene.selectedFieldDisplayVals) //10/18 separate display vals from string vals
                paramKnob.wraparound = true   //10/5 wraparound
                pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
            }
            else if OVScene.selectedFieldType == "text" //10/9 new field type
            {
                textField.text = OVScene.lastFieldString //10/9 from OVS
                textField.becomeFirstResponder() //12/5 OK KB!
            }
            else if OVScene.selectedFieldType == "texture" //10/21 handle textures
            {
                self.performSegue(withIdentifier: "textureSegue", sender: self)
            }
        } //end knobmode KnobStates.SELECT_PARAM
        else{   //Done editing? back to param select?
            knobMode  = "select" //5/3 NOT editing now...
            if whatWeBeEditing == "voice" //10/18 voice vs shape edit
            {
                //print("done edit xycoord \(OVScene.selectedVoice.OVS.xCoord), \(OVScene.selectedVoice.OVS.yCoord)")
                //print("...vnotemode \(OVScene.selectedVoice.OVS.noteMode)")
                OVScene.sceneVoices[OVScene.selectedMarkerKey] = OVScene.selectedVoice    //save latest voice to sceneVoices
                markers3D[OVScene.selectedMarkerKey]   = selectedMarker //4/28 new dict
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : voiceParamNames)
                updatePkeys()
            }
            else if whatWeBeEditing == "shape"
            {
                OVScene.sceneShapes[OVScene.selectedShapeKey] = OVScene.selectedShape    //10/21 save latest voice to sceneVoices
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : shapeParamNames)
            }
            else if whatWeBeEditing == "pipe" //DHS 12/4
            {
                
                //Save our pipe info back to scene
                OVScene.scenePipes[OVScene.selectedPipeKey] = OVScene.selectedPipe
                pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
                    pmin : 0.0 , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
                    choiceStrings : pipeParamNames)
            }
            pLabel.updateLabelOnly(lStr:"Done:" + OVScene.selectedFieldName)
            knobValue = Float(OVScene.selectedField)  // 9/17  set knob value to old param index...
            var count = voiceParamNames.count
            if whatWeBeEditing == "shape" {count = shapeParamNames.count}
            paramKnob.wraparound = true //10/5 wraparound
            pLabel.showWarnings  = false  // 10/5 no warnings on wraparound controls
        }

        updateWheelAndParamButtons()
    } //end editSelect
    
    

    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if knobMode == "edit" {cancelEdit()}  //5/3 Editing? Not any more!
        stopPlayingMusic()
        if segue.identifier == "textureSegue" {
            if let nextViewController = segue.destination as? TextureVC {
                    nextViewController.delegate = self
            }
        }
        // 11/4 add scene chooser
        else if segue.identifier == "chooserLoadSegue" {
            OVScene.haltLoop() //5/8 halt playing music!
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
                //plass in OVScene.selected patch if popup appeared...
                if whatWeBeEditing == "voice"
                    {nextViewController.opatch = self.OVScene.selectedVoice.OOP //10/18
                     nextViewController.patchName = self.OVScene.selectedVoice.OVS.patchName
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
    // 3/30 updates 3d keyboard for OVScene.selected voice....
    func updatePkeys()
    {
        self.pkeys.resetForVoice( nMode : self.OVScene.selectedVoice.OVS.noteMode ,
                                  bMidi : self.OVScene.selectedVoice.OVS.bottomMidi ,
                                  tMidi : self.OVScene.selectedVoice.OVS.topMidi)
    } //end updatePkeys
    
    //=====<oogie2D mainVC>====================================================
    //  9/13 uses knobMode, updates buttons / wheels at bottom of screen
    func updateWheelAndParamButtons()
    {
        var knobName            = "fineGear" //assume edit
        paramKnob.isHidden      = false
        editButtonView.isHidden = false
        if (knobMode == "edit")  //5/3 Edit?
        {
            paramKnob.isHidden      = OVScene.selectedFieldType == "text"  //10/9
            resetButton.isHidden    = OVScene.selectedFieldType == "text"  //10/9
            editButtonView.isHidden = false
            editButton.setTitle("OK", for: .normal)
            menuButton.setTitle("X", for: .normal)
            if OVScene.selectedFieldType == "string"  //string array?
            {
                let maxxx = Float(OVScene.selectedFieldStringVals.count - 1)
                //print("set param minmax to 0.0 , \(maxxx)")
                OVScene.selectedFieldMin = 0.0
                OVScene.selectedFieldMax = maxxx
            }
            resetKnobToNewValues(kval: knobValue ,kmin: OVScene.selectedFieldMin ,kmax: OVScene.selectedFieldMax)
        } //end edit select
        else{   //back to param select?
            knobName = "wheel01"
            resetButton.isHidden = true
            textField.isHidden   = true //10/9
            editButton.setTitle("Edit", for: .normal)
            menuButton.setTitle("Menu", for: .normal)
            resetKnobToNewValues(kval: knobValue ,kmin:0 ,kmax: Float(OVScene.selectedVoice.getParamCount() - 1))
        } //end param select
        paramKnob.setKnobBitmap(bname: knobName)
    } //end updateWheelAndParamButtons


    //=======>ARKit MainVC===================================
    //Param knob change... to new knob value
    @IBAction func paramChanged(_ sender: Any) {
        //print("paramchanged...");
        knobValue = paramKnob.value //Assume value is pre-clamped to range
        if knobMode == "select" //5/3 select param  9/13 changes
        {
            let ikv = Int(knobValue)
            if ikv != oldKnobInt //1/14 only react to int steps!
            {
                fbgenerator.prepare() // 1/14 haptics
                fbgenerator.selectionChanged()
                OVScene.selectedField = ikv  //1/14
                if whatWeBeEditing == "voice"  {OVScene.loadCurrentVoiceParams()}
                if whatWeBeEditing == "shape"  {OVScene.loadCurrentShapeParams()}
                if whatWeBeEditing == "pipe"   {OVScene.loadCurrentPipeParams()}
                OVScene.getLastParamValue(editing : whatWeBeEditing ,
                                            named : OVScene.selectedFieldName.lowercased())
                updateSelectParamName()
            }
            oldKnobInt = ikv
        }
            
        else //edit param
        {
            let fname = OVScene.selectedFieldName.lowercased()
            if  (Int(knobValue) != OVScene.lastFieldInt)   //haptics feedback on value change
            {
                fbgenerator.prepare()
                fbgenerator.selectionChanged()
            }
           let sceneChanges =  OVScene.setNewParamValue(editing : whatWeBeEditing,
                                       named : fname,
                                    toDouble : Double(knobValue),
                                    toString : OVScene.lastFieldString)
            update3DSceneForSceneChanges(sceneChanges)
            updateParamLabel(toDouble:Double(knobValue))

            OVScene.lastFieldInt = Int(knobValue)  //for choice changes,like type or patch
        } //end else
        oldKnobValue = paramKnob.value //12/2 move to bottom

    } //end paramChanged
    
    //=======>ARKit MainVC===================================
    func updateParamLabel(toDouble:Double)
    {
        //  if needRefresh
        //  {
        //Update top label: is this the right place for this?
        // 4/26 pull pstring, unused
        if OVScene.selectedFieldType == "double" || OVScene.selectedFieldType == "int" //4/26 int type
        {
            let displayValue = OVScene.selectedFieldDMult * toDouble + //4/26 todouble was workdouble
                                OVScene.selectedFieldDOffset //9/17 display value differs from knob value
            pLabel.updateit(value: displayValue) //DHS 9/28 new display
        }
        else
        {
            pLabel.updateit(value: toDouble) //DHS 9/28 new display
        }
        //  } //end needRefresh
        
    }
    
    //=======>ARKit MainVC===================================
    // Called when a 3d shape params are changed.
    // Makes sure the 3D representation matches the data
    //  called by param set , restore, pipe data, and cancel
    func update3DShapeByKey (key : String)
    {
        if let sshape3d = shapes3D[key] //get named SphereShape
        {
            var shapeStruct = OVScene.selectedShape  //Get current shape object
            if key != OVScene.selectedShapeKey
            {
                shapeStruct = OVScene.sceneShapes[key]!
            }
            //1/21 new struct...
            sshape3d.position = SCNVector3(shapeStruct.OOS.xPos ,shapeStruct.OOS.yPos ,shapeStruct.OOS.zPos )
            sshape3d.setTextureScaleAndTranslation(xs: Float(shapeStruct.OOS.uScale),
                                                   ys: Float(shapeStruct.OOS.vScale),
                                                   xt: Float(shapeStruct.OOS.uCoord),
                                                   yt: Float(shapeStruct.OOS.vCoord)
            )
            //5/3 moved bmp to oogieShape
            shapeStruct.bmp.setScaleAndOffsets(
                sx: shapeStruct.OOS.uScale, sy: shapeStruct.OOS.vScale,
                ox: shapeStruct.OOS.uCoord, oy: shapeStruct.OOS.vCoord)
        }
    } //end update3DShapeByKey
    
    //=======>ARKit MainVC===================================
    // 10/29 types: manual, BPMX1..8
    func setRotationTypeForSelectedShape()
    {
        var rspeed = 8.0
        var irot = Int(OVScene.selectedShape.OOS.rotation)
        if irot > 0
        {
            if irot > 8 {irot = 8}
            rspeed = 60.0 / Double(OVtempo) //time for one beat
            //11/23 change rotation speed mapping
            rspeed = rspeed * 1.0 * Double(irot) //4/4 timing, apply rot type
        }
        
        //OK set up rotation
        //5/7 this needs to call OOGIESHAPE's METHOD, NOT SPHERESHAPE!
//        setRotationSpeedForSelectedShape(s : rspeed)
    } //end setRotationTypeForSelectedShape
    
    //=======>ARKit MainVC===================================
    func setRotationSpeedForSelectedShape(s : Double)
    {
        if let sshape = shapes3D[OVScene.selectedShapeKey]
        {
            OVScene.selectedShape.OOS.rotSpeed = s
            //5/7 moved to oogieShape sshape.setTimerSpeed(rs: OVScene.selectedShape.OOS.rotSpeed)
        }
    } //end setRotationSpeedForSelectedShape
    
    //=======>ARKit MainVC===================================
    //  4/19 cluge?  is this the right place?
    func setMasterPitchShiftForAllVoices()
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        for (_,voice) in OVScene.sceneVoices
        {
            voice.masterPitch = appDelegate.masterPitch
        }
    } //end setMasterPitchShiftForAllVoices
    

    //=======>ARKit MainVC===================================
    // 12/1 make generic for all types of params...
    func editParams(v:String)
    {
        whatWeBeEditing = v
        OVScene.selectedField = 0
        knobMode = "select"  //5/3
        updateWheelAndParamButtons()
        var choiceStrings : [String] = []
        switch(v)
        {
            case  "voice" : OVScene.loadCurrentVoiceParams()
                            choiceStrings = voiceParamNames
            case  "shape" : OVScene.loadCurrentShapeParams()
                            choiceStrings = shapeParamNames
            case  "pipe"  : OVScene.loadCurrentPipeParams()
                            choiceStrings = pipeParamNames
            default: return; //Bail on bad type
        }
        OVScene.getLastParamValue(editing : whatWeBeEditing ,
                    named : OVScene.selectedFieldName.lowercased())
        pLabel.setupForParam( pname : "Param" , ptype : TSTRING_TTYPE , //9/28 new
            pmin : 0.0 , pmax : OVScene.selectedFieldDMult * Double( OVScene.selectedFieldMax) ,
            choiceStrings : choiceStrings)
        pLabel.showWarnings  = false
        paramKnob.wraparound = true
    } //end editParams
    
    
    //=======>ARKit MainVC===================================
    //1/22 updates pipes going FROM a voice,
    //  bool updatingPipe prevents redundant calls
    func updatePipeByVoice(v:OogieVoice)
    {
        if updatingPipe {return}  // 5/3 fail on multiple calls
        updatingPipe = true
        //Get all outgoing pipes from voice, update positions
        for puid in v.outPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByVoice

    //=======>ARKit MainVC===================================
    // update both incoming pipes and outgoing pipes from markers 5/2
    func updatePipeByShape(s:OogieShape)
    {
        if updatingPipe {return} // 5/3 fail on multiple calls
        updatingPipe = true
        for (_,v) in OVScene.sceneVoices // loop over voices, match with shape
        {
            if v.OVS.shapeKey == s.OOS.key //match key? update!
               { updatePipeByVoice(v:v) }
        }
        //Get all incoming pipes to shape, update positions
        for puid in s.inPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByShape

    //=======>ARKit MainVC===================================
    // broke out from updatePipeByVoice 5/2
    func updatePipeByUID(_ puid:String)
    {
        if let n = OVScene.pipeUIDToName[puid]                // get pipes name
        {
            if let pipeObj = OVScene.scenePipes[n]           //   find pipe struct
                {
                    addPipe3DNode(oop: pipeObj, newNode : false) //1/30
                    let vals = pipeObj.ibuffer //11/28 want raw unscaled here!
                    if let pipe3D = pipes3D[n]    // get Pipe 3dobject itself to restore texture
                    {
                        pipe3D.texturePipe(phase:0.0 , chan: pipeObj.PS.fromChannel.lowercased(),
                                           vals: vals, vsize: vals.count , bptr : pipeObj.bptr)
                    }
                }
        }

    }
    
    
    
    //=======>ARKit MainVC===================================
    // called when knob chooses new param
    func updateSelectParamName()
    {
        //print("updateSelectParamName \(lastFieldDouble)")
        let dogStrings = ["nfixed","vfixed","pfixed","topmidi","bottommidi","midichannel"]
        var infoStr = OVScene.selectedFieldName
        var pstr    = ""
        if OVScene.selectedFieldType == "double"
        {
            var dval = OVScene.unitToParam(inval: OVScene.lastFieldDouble)
            //some fields don't need converting
            if  dogStrings.contains( OVScene.selectedFieldName.lowercased())
            {
                dval = OVScene.lastFieldDouble;
            }
            pstr = String(format: "%4.2f", dval) //10/24 wups was int!
        }
        else if OVScene.selectedFieldType == "int" //4/26 int ptype
        {
            var dval = OVScene.unitToParam(inval: OVScene.lastFieldDouble)
            //some fields don't need converting
            if  dogStrings.contains( OVScene.selectedFieldName.lowercased())
            {
                dval = OVScene.lastFieldDouble;
            }
            pstr = String(format: "%d", Int(dval)) //10/24 wups was int!
        }
        else if OVScene.selectedFieldType == "string"
        {
            let index = Int(OVScene.lastFieldDouble)
            if index >= 0 && index < OVScene.selectedFieldDisplayVals.count //4/26 redo limit check
            {
                //print("lfd \(lastFieldDouble) vals count \(selectedFieldDisplayVals.count)")
                //print("displayvals \(selectedFieldDisplayVals)")
                pstr = OVScene.selectedFieldDisplayVals[index]  //10/19 wups forgot
            }
        }
        else if OVScene.selectedFieldType == "text" //10/9 new field type
        {
            //12/5 DUH what kinda edit we be doin?
            if whatWeBeEditing == "voice"    //2/3 handle name/comment
            {
                switch(OVScene.selectedFieldName.lowercased())
                {
                    case "name"    : pstr = OVScene.selectedVoice.OVS.name //2/3 new
                    case "comment" : pstr = OVScene.selectedVoice.OVS.comment
                    default        : pstr = "empty"
                }
            }
            else if whatWeBeEditing == "shape"    //2/3 handle name/comment
            {
                switch(OVScene.selectedFieldName.lowercased())
                {
                    case "name"    : pstr = OVScene.selectedShape.OOS.name //2/3 new
                    case "comment" : pstr = OVScene.selectedShape.OOS.comment
                    default        : pstr = "empty"
                }
            }
            else if whatWeBeEditing == "pipe"
            {
                //12/9 which to handle? name, lo/hi ranges...
                switch(OVScene.selectedFieldName.lowercased())
                {
                    case "lorange" : pstr = OVScene.lastFieldString
                    case "hirange" : pstr = OVScene.lastFieldString
                    case "name"    : pstr = OVScene.selectedPipe.PS.name //2/3 new
                    case "comment" : pstr = OVScene.selectedPipe.PS.comment
                    default        : pstr = "empty"
                }
            }
        }
        else if OVScene.selectedFieldType == "texture" //10/9 new field type
        {
            pstr = OVScene.selectedShape.OOS.texture //10/22 is this the only texture?
        }
        infoStr = OVScene.selectedFieldName + ":" + pstr

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
    }
    
    //=======>ARKit MainVC===================================
    // Used to select items in the AR 3D world...
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        latestTouch = touch
        handleTouch(touch: touch)
    } //end touchesBegan
    
    //=====<oogie2D mainVC>====================================================
    //10/29 called by touchesDown
    func handleTouch(touch:UITouch)
    {
        //  user selects object they are long touching on!
        // Make all of this a subroutine called handleTouches!!!
        guard let sceneView   = skView else {return}
        //4/27 Is latestTouch redundant? Should We use touch here???
        touchLocation  = latestTouch.location(in: sceneView)
        guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
        let hitNode    = nodeHitTest.node
        var bailOnEdit = false
        var deselected = false
        if let name = hitNode.name
        {
            if name.contains("pianoKeys") ///2/28 keyboard hit test => output note
            {
                let localCoordinates = nodeHitTest.localCoordinates
                let tMidiNote = pkeys.getTouchedMidiNote( hitCoords  : localCoordinates )
                if whatWeBeEditing != "voice"
                {
                    self.pLabel.updateLabelOnly(lStr:"Select Voice First")
                }
                else //2/29  voice selected? play it!
                {
                    //print("hit key \(tMidiNote) play note now!")
                    OVScene.setupSynthOrSample(oov : OVScene.selectedVoice)
                    (sfx() as! soundFX).playNote(Int32(tMidiNote),
                                                 Int32(OVScene.selectedVoice.bufferPointer) ,
                                                 Int32(OVScene.selectedVoice.OOP.type))
                    //Indicate note to user
                    self.pLabel.updateLabelOnly(lStr:String(format: "Note:%@",pkeys.lastNoteName))

                    pkeys.placeAndColorHighlightCylinder(midiNote: tMidiNote)  //3/16/20 
                }
            }
            else if name.contains("shape") //Found a shape? get which one
            {
                let key = findShapeByUID(uid: name)
                if (key != "")
                {
                    unselectAnyOldStuff(key: key) //11/30
                    if let testShape = shapes3D[key] //1/26
                    {
                        OVScene.selectedShapeKey = key
                        selectedSphere    = testShape
                        selectedSphere.toggleHighlight()
                        //Wow is this redundant?
                        if selectedSphere.highlighted  //hilited? Set up edit
                        {
                            whatWeBeEditing = "shape"   //2/6 WTF?
                            self.pLabel.updateLabelOnly(lStr:"Selected " + self.selectedSphere.name!)
                            if let testShape = OVScene.sceneShapes[key] //got legit voice?
                            {
                                OVScene.selectedShape     = testShape
                                OVScene.selectedShapeKey  = key //10/21
                                //2/3 add name/comment to 3d shape info box
                                selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                                            comm: OVScene.selectedShape.OOS.comment)
                                editParams(v: "shape") //this also update screen
                            }
                        }
                        else //unhighlighted?
                        {
                            bailOnEdit = (knobMode == "edit") //5/3
                            deselected = true
                        }
                    }
                } //end selectedobjectindex...
            } //end name... shape
            else if name.contains("marker") //Found a marker? get which one
            {
                    let key = findMarkerByUID(uid: name) //4/30 redo find
                    if (key != "")
                    {
                        unselectAnyOldStuff(key:key)
                        if let testMarker = markers3D[key]
                        {
                            selectedMarker = testMarker
                            selectedMarker.toggleHighlight()
                            if selectedMarker.highlighted  //hilited? Set up edit
                            {
                                //DHS 1/16:this looks to get OLD values not edited values!
                                if let testVoice = OVScene.sceneVoices[key] //got legit voice?
                                {
                                    whatWeBeEditing = "voice"
                                    if let smname = selectedMarker.name  //update param label w/ name
                                    { self.pLabel.updateLabelOnly(lStr:"Selected " + smname) }
                                    OVScene.selectedVoice     = testVoice //Get associated voice for this marker
                                    OVScene.selectedMarkerKey = key      //points to OVS struct in scene
                                    selectedMarker.updatePanels(nameStr: OVScene.selectedMarkerKey) //10/11 add name panels
                                    //1/14 was redundantly pulling OVS struct from OVScene.voices!
                                    editParams(v: "voice") //1/14 switch to edit mode
                                    updatePkeys() //3/30 update kb if needed
                                }
                            }
                            else
                            {
                                bailOnEdit = (knobMode == "edit") //5/3
                                deselected = true
                            }
                        } //end let testMarker...
                } //end if key
               // 4/28 } //end if selected...
            } //end name == marker
            else if name.contains("pipe") //Found a pipe? get which one
            {
                let key = findPipe(uid: name)
                if let pipe3D = pipes3D[key]
                {
                    selectedPipeShape = pipe3D
                    unselectAnyOldStuff(key:key) //11/30
                    OVScene.selectedPipeKey = key
                    selectedPipeShape.toggleHighlight()
                    if let spo = OVScene.scenePipes[key] //now get pipe record...
                    {
                        whatWeBeEditing = "pipe"  //2/6 WTF?
                        OVScene.selectedPipe = spo // get 3d scene object...
                        //Beam pipe name and output buffer to a texture in the pipe...
                        // ideally this should be updaged on a timer!
                        selectedPipeShape.updateInfo(nameStr: key, vals: spo.ibuffer)
                        if selectedPipeShape.highlighted  //hilited? Set up edit
                        {
                            self.pLabel.updateLabelOnly(lStr:"Selected " + spo.PS.name)
                            editParams(v:"pipe") //this also update screen
                        }
                        else
                        {
                            bailOnEdit = (knobMode == "edit") //5/3
                            deselected = true
                        }
                    } //end let spo
                }    //end let pipe3D
            }        // end if name
        }           //end let name
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
    func unselectAnyOldStuff(key:String)
    {
        if whatWeBeEditing == "voice"
        {
            //selectedMarker.unHighlight()
            // is a different marker selected? deselect!
            if  selectedMarker.highlighted &&
                 OVScene.selectedMarkerKey != key
                { selectedMarker.unHighlight() }
            OVScene.selectedMarkerKey = ""
        }
        else if whatWeBeEditing == "shape"
        {
            //selectedSphere.unHighlight()
            if selectedSphere.highlighted &&
                OVScene.selectedShapeKey != key
                { selectedSphere.unHighlight() }
            OVScene.selectedShapeKey = ""
        }
        else if whatWeBeEditing == "pipe"
        {
            //selectedPipeShape.unHighlight()
            if selectedPipeShape.highlighted &&
                OVScene.selectedPipeKey != key
                { selectedPipeShape.unHighlight() }
            OVScene.selectedPipeKey = ""
        }

       // if selectedSphere.highlighted && selectedShapeKey != testName

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
            self.OVScene.packupSceneAndSave(sname:self.OVSceneName)
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
        alert.addAction(UIAlertAction(title: "Toggle Piano KB", style: .default, handler: { action in
            self.updatePkeys() //3/30 update kb if needed
            self.pkeys.isHidden = !self.pkeys.isHidden
        }))

        alert.addAction(UIAlertAction(title: "Dump Scene", style: .default, handler: { action in
            self.OVScene.OSC.dump()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end menu
    
    
    //=====<oogie2D mainVC>====================================================
    // voice popup... various functions
    func voiceMenu()
    {
        let alert = UIAlertController(title: self.OVScene.selectedVoice.OVS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)

            alert.addAction(UIAlertAction(title: "Edit this Patch...", style: .default, handler: { action in
                self.performSegue(withIdentifier: "EditPatchSegue", sender: self)
        }))
        alert.view.tintColor = UIColor.black //2/6 black text

        var tstr = "Solo"
        if soloVoiceID != "" {tstr = "UnSolo"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            if self.soloVoiceID == ""
            {
                self.soloVoiceID = self.OVScene.selectedVoice.uid
            }
            else
            {
                self.soloVoiceID = ""
            }
            self.selectedMarker.toggleHighlight()
            self.updateUIForDeselectVoiceOrShape()
        }))

        tstr = "Mute"
        if OVScene.selectedVoice.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            self.OVScene.selectedVoice.muted = !self.OVScene.selectedVoice.muted
            self.selectedMarker.toggleHighlight()
            self.updateUIForDeselectVoiceOrShape()
        }))
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS, key: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete...", style: .default, handler: { action in
           self.deleteVoicePrompt(voice: self.OVScene.selectedVoice)
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            let key = self.OVScene.selectedVoice.OVS.key
            self.OVScene.resetVoiceByKey(key: key)  //1/14 Reset shape object from scene
            if let marker = self.markers3D[key] //4/28 new dict
            {
                marker.updateLatLon(llat: self.OVScene.selectedVoice.OVS.yCoord, llon: self.OVScene.selectedVoice.OVS.xCoord)
            }
        }))
        alert.addAction(UIAlertAction(title: "Add Pipe...", style: .default, handler: { action in
           self.addPipeStepOne(voice: self.OVScene.selectedVoice)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end voiceMenu
    
    //=====<oogie2D mainVC>====================================================
    // operations available to selected shape...
    func shapeMenu()
    {
        let alert = UIAlertController(title: self.OVScene.selectedShape.OOS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addShapeToScene(shapeOSS: self.OVScene.selectedShape.OOS, key: "", op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShapePrompt(shape: self.OVScene.selectedShape.OOS)
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS, key: "", op: "new")
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            self.OVScene.resetShapeByKey(key: self.OVScene.selectedShape.OOS.key)  //Reset shape object from scene
            self.update3DShapeByKey(key:self.OVScene.selectedShape.OOS.name)  //Ripple change thru to 3D
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end shapeMenu

    //=====<oogie2D mainVC>====================================================
    // 11/30 pipe menu options
    func pipeMenu()
    {
        let alert = UIAlertController(title: self.OVScene.selectedPipe.PS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Pipe...", style: .default, handler: { action in
            self.deletePipePrompt(pipe: self.OVScene.selectedPipe)
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
            self.deleteShapeByKey(key: shape.key)  //5/4 use key
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteShapePrompt
    
    //=====<oogie2D mainVC>====================================================
    // 2/6 redo: removes shape from scene / SCNNode 5/4 use key
    func deleteShapeByKey(key:String)
    {
        if let shape3D = shapes3D[key] // got something to delete?
        {
            if let shapeNode = OVScene.sceneShapes[key] //2/6 first,Get rid of any pipes!
            {
                if shapeNode.inPipes.count > 0
                {
                    for puid in shapeNode.inPipes
                    {
                        deletePipeByUID(puid: puid, nodeOnly : false)
                    }
                }
                for (vkey,v) in OVScene.sceneVoices   //2/6 delete any voices too!
                {
                    for puid in v.inPipes //get rid of any incoming pipes
                    {
                        deletePipeByUID(puid: puid, nodeOnly : false)
                    }
                    
                    //Voice parented to this shape? delete it!
                    if v.OVS.shapeKey == vkey { deleteVoiceByKey(key:vkey)}
                }
                shape3D.removeFromParentNode()          //Blow away 3d Shape
                shapes3D.removeValue(forKey: key)       //  delete dict 3d entry
                if let shape = OVScene.sceneShapes[key] //5/7 get shape datasource
                {
                    shape.haltSpinTimer()   //5/4 timer seems to linger after delete!!!
                }
                OVScene.sceneShapes.removeValue(forKey: key) //  delete dict data entry
            } //end let shapeNode
        } // end let shape3D
    } //end deleteShapeByKey
    
    //=====<oogie2D mainVC>====================================================
    // 1/21 when a pipe source or destination is deleted, the pipe must go too...
    //   uid is best because pipe name may have changed
    func deletePipeByUID( puid : String , nodeOnly : Bool)
    {
        if let name = OVScene.pipeUIDToName[puid]
        {
            //print ("scnpc \(OVScene.scenePipes.count)")
            // 1/22 delete pipes data?
            if !nodeOnly {
                OVScene.cleanupPipeInsAndOuts(name:name)         // 1/22 cleanup ins and outs...
                //print("delete scenepipe \(name)")
                OVScene.scenePipes.removeValue(forKey: name)
            }       // Get rid of pipeObject
            // Always get rid of pipe 3D node
            print("deletePipeByUID \(name)")
            if let pipe3D = pipes3D[name]
            {
                //print(".....delete3d pipe");
                pipe3D.removeFromParentNode()
                
            }       // Clean up SCNNode
            pipes3D.removeValue(forKey: name)        // Delete 3d Object
        }
    } //end deletePipeByUID
    
    //=====<oogie2D mainVC>====================================================
    // spawns a series of other stoopid submenus, until there is a smart way
    //    to do it in AR.  like point at something and select?????
    //  Step 1: get output channel, Step 2: pick target , Step 3: choose parameter
    func addPipeStepOne(voice:OogieVoice)
    {
        let alert = UIAlertController(title: "Choose Output Channel", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
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
        for (n,_) in OVScene.sceneShapes {troutput.append(n)}
        return troutput
    }
    //=====<oogie2D mainVC>====================================================
    //12/30 for pipe addition
    func getListOfSceneVoices() -> [String]
    {
        var troutput : [String] = []
        for (n,_) in OVScene.sceneVoices {troutput.append(n)}
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
        alert.view.tintColor = UIColor.black //2/6 black text
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
        alert.view.tintColor = UIColor.black //2/6 black text
        var menuNames = shapeParamNamesOKForPipe
        if !isShape {menuNames = voiceParamNamesOKForPipe}
        for pname in menuNames
            {
                alert.addAction(UIAlertAction(title: pname, style: .default, handler: { action in
                    //Add our pipe to scene... (BREAK OUT TO METHOD WHEN WORKING!)
                    let ps = PipeStruct(fromObject: voice.OVS.name, fromChannel: channel.lowercased(), toObject: destination, toParam: pname.lowercased())
                    let pcount = 1 + self.OVScene.scenePipes.count //use count to get name
                    self.addPipeToScene(ps: ps, key: "", op: "new")
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
            self.deletePipe(name: self.OVScene.selectedPipe.PS.name)
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
        if let pipe3D = pipes3D[name]
        {
            pipe3D.removeFromParentNode()                //Blow away 3d Shape
            OVScene.cleanupPipeInsAndOuts(name:name)            // 1/22 cleanup ins and outs...
            OVScene.scenePipes.removeValue(forKey: name)       //  and clear entry from
            pipes3D.removeValue(forKey: name)           //   and data / shape dicts
            OVScene.selectedPipeKey = ""
        }
    } //end deletePipe
    

    //=====<oogie2D mainVC>====================================================
    // 10/27
    func deleteVoicePrompt(voice:OogieVoice)
    {
        print("Delete Voice... \(voice.OVS.name)")
        let alert = UIAlertController(title: "Delete Selected Voice?", message: "Voice will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.deleteVoiceByKey(key: voice.OVS.key)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteVoicePrompt

    //=====<oogie2D mainVC>====================================================
    // 10/27 removes voice from scene / SCNNode
    func deleteVoiceByKey(key:String)  //5/4 use key
    {
        if let marker = markers3D[key]   //4/28 new dict
        {
            marker.removeFromParentNode()
            markers3D.removeValue(forKey: key) //4/28 new dict
            OVScene.sceneVoices.removeValue(forKey: key)       //  and remove data structure
        }
        // 2/6 what about input pipes?
    } //end deleteVoiceByKey

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
    // 4/30 NOTE: this has a bug resetting the camera position!
    func clearScene()
    {
        self.OVScene.OSC.clearScene()       // Clear everything...
        self.OVScene.clearOogieStructs()    // Clear data structures
        self.clearAll3DNodes(scene:scene)    // Clear any SCNNodes
        self.OVScene.createDefaultScene(named: "default")  //2/1/20 add an object
        self.create3DScene(scene:scene) //  then create new scene from file
        cameraNode.transform = SCNMatrix4Identity
        cameraNode.position  = SCNVector3(x:0, y: 0, z: 6) //put camera back away from origin
    } //end clearScene
    
    //=====<oogie2D mainVC>====================================================
    func clearAll3DNodes(scene:SCNScene)
    {
        oogieOrigin.enumerateChildNodes { (node, _) in //1/20 new origin
            //print("remove node \(node.name)")
            if (node.name != nil) {node.removeFromParentNode()}
        }
        markers3D.removeAll() //4/28 new dict
        // 5/7 iterate over all shapes and halt timers first
        for (_,shape) in OVScene.sceneShapes { shape.haltSpinTimer() }
        shapes3D.removeAll()
        pipes3D.removeAll()          //1/21 wups?
        OVScene.pipeUIDToName.removeAll()  //1/22
    } //end clearAll3DNodes
    
    
    //=====<oogie2D mainVC>====================================================
    // Assumes shapes already loaded..
    func create3DScene(scene:SCNScene)
    {
        //iterate thru dictionary of shapes...
        for (key, nextShape) in OVScene.OSC.shapes
            { addShapeToScene(shapeOSS: nextShape, key: key, op: "load") }
        //iterate thru dictionary of shapes...
        for (key, nextOVS) in OVScene.OSC.voices
            { addVoiceToScene(nextOVS: nextOVS, key: key, op: "load") }
        //OK add pipes too
        for (key, nextPipe) in OVScene.OSC.pipes
            { addPipeToScene(ps: nextPipe, key: key, op: "load") }

        pkeys          = PianoKeys() //make new 3d shape, texture it
        pkeys.isHidden = true //Hide for now
        oogieOrigin.addChildNode(pkeys)
        
        //let axes = createAxes() //1/11/20 test azesa
        //oogieOrigin.addChildNode(axes)
        //scene.rootNode.addChildNode(axes)
        
    } //end create3DScene
    
    
    //=====<oogie2D mainVC>====================================================
    @IBAction func testSelect(_ sender: Any) {
        //dumpDebugShit()
        testTiffie()
    } //end testSelect
    
    var screenCaptureFlag = false
    var needTiffie = false
    //=====<oogie2D mainVC>====================================================
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if screenCaptureFlag {
            screenCaptureFlag = false  // unflag
            
             DispatchQueue.main.async {
                let screenshot = self.skView.snapshot()
                // Then save the screenshot, or do whatever you want
                if self.needTiffie   //for tiffie, use center square from ss
                {
                    let wid  = screenshot.size.width
                    let area = CGRect(x: 0, y: screenshot.size.height/2 - wid/2, width: wid, height: wid)
                    let crop = screenshot.cgImage!.cropping(to: area)!
                    let subImage = UIImage(cgImage: crop, scale: 1, orientation:.up)
                    let json = self.OVScene.OSC.getDumpString()
                    let ot = OogieTiffie()
                    let title = "OOgie scene: " + self.OVScene.OSC.name
                    ot.write(toPhotos: title , json , subImage)
                    self.needTiffie = false
                }
            }
        }
    }
    func testTiffie()
    {
        //Enable screen capture
        screenCaptureFlag = true
        needTiffie        = true   //after capture, save tiffie!
        
    }
    
    
    //=====<oogie2D mainVC>====================================================
    //Hopefully dumps enuf for debugging anything?
    func dumpDebugShit()
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        var elDumpo     = appDelegate.versionStr
        var title       = "Dump of scene / folder"
        //Get scene start pos
        let sPOz        =  String(format: "StartPos XYZ %4.2f,%4.2f,%4.2f",
                                  startPosition.x, startPosition.y, startPosition.z)
        elDumpo         = elDumpo + "\n--------SceneDump--------\n" + OVScene.OSC.getDumpString() + "\n" + sPOz
        let sceneFilez  = DataManager.getDirectoryContents(whichDir: "scenes")
        let sf          = sceneFilez.joined(separator: ",")
        elDumpo         = elDumpo + "\n--------SceneFiles--------\n" + sf
        print("\(elDumpo)")
        
        //        var a = selectedVoice.getParamList()
        //        print("voiceparamvals \(a)")
        //          title = "Shape Params"
        //          elDumpo = selectedShape.dumpParams()
        if whatWeBeEditing == "voice"
        {
           title = "Voice Params"
            elDumpo = OVScene.selectedVoice.dumpParams()
        }
        else if whatWeBeEditing == "shape"
        {
           title = "Shape Params"
           elDumpo = OVScene.selectedShape.dumpParams()
        }
        else if whatWeBeEditing == "pipe"
        {
           title = "Pipe Dreams"
           elDumpo = OVScene.selectedPipe.dumpParams()
        }
        
        let alert = UIAlertController(title: title, message: elDumpo, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    
    //=====<oogie2D mainVC>====================================================
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
     } //end createAxes
    
    //=====<oogie2D mainVC>====================================================
    // 4/20 cleanup, peel off 3d part to separate method, data to OVScene
    func addVoiceToScene(nextOVS : OVStruct , key : String, op : String)
    {
        //First, set up scene structures, get fresh voice back...
        let newVoice = OVScene.addVoiceSceneData(nextOVS : nextOVS , key:key , op:op)
        // use this voice and create the 3D marker
        addVoice3DNode(voice:newVoice, op:op)
    } //end addVoiceToScene
    
    //=====<oogie2D mainVC>====================================================
    // always adds sphere for now...
    func addVoice3DNode(voice:OogieVoice, op:String)
    {
        if op != "new"
        {
            if OVScene.sceneShapes[voice.OVS.shapeKey] == nil {return} //1/27 bail on no shape
        }
        if let shape3D = shapes3D[voice.OVS.shapeKey] //10/21 find shape 3d object
        {
            //Lat / Lon Marker to select color
            let nextMarker = Marker()
            nextMarker.name = voice.OVS.name //9/16 point to voice
            //10/29 here we have int type, not string...
            nextMarker.updateTypeInt(newTypeInt: Int32(voice.OOP.type))
            markers3D[voice.OVS.key] = nextMarker //4/28 new dict
            shape3D.addChildNode(nextMarker)
            nextMarker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
        }
        else
        {
            print("error finding shape for voice \(voice.OVS.name)")
        }
    } //end addVoice3DNode


    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addShapeToScene (shapeOSS:OSStruct , key : String, op : String)
    {
        let psTuple = OVScene.addShapeSceneData (shapeOSS:shapeOSS, key:key , op:op , startPosition:startPosition)
        addShape3DNode (pst:psTuple)
    } //end addShapeToScene
    

    
    //=====<oogie2D mainVC>====================================================
    // 4/28 peel off from addShapeToScene
    func addShape3DNode (pst : (shape:OogieShape,pos3D:SCNVector3))
    {
        let sphereNode = SphereShape() //make new 3d shape, texture it
        let shapeOOS = pst.shape.OOS
        sphereNode.setBitmap(s: shapeOOS.texture)
        sphereNode.position = pst.pos3D //Place 3D object as needed..
        sphereNode.setTextureScaleAndTranslation(xs: Float(shapeOOS.uScale), ys: Float(shapeOOS.vScale), xt: Float(shapeOOS.uCoord), yt: Float(shapeOOS.vCoord))
        sphereNode.name      = shapeOOS.key
        sphereNode.key       = shapeOOS.key  //5/3 add key
        oogieOrigin.addChildNode(sphereNode)  // Add shape node to scene
        shapes3D[shapeOOS.key] = sphereNode     // Add shape to 3d dict
    } //end addShape3DNode

    
    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addPipeToScene(ps : PipeStruct , key : String, op : String)
    {
        if let oop = OVScene.addPipeSceneData(ps : ps , key : key, op : op)
        {
            // 1/22 split off 3d portion
             addPipe3DNode(oop : oop , newNode : true) //1/30
        }
    } //end addPipeToScene
    
   
    //=====<oogie2D mainVC>====================================================
    // 1/22 new,  1/30 add newNode arg
    func addPipe3DNode (oop:OogiePipe , newNode : Bool)
    {
        let n      = oop.PS.name
        var pipe3D = PipeShape()
        if (!newNode) //update? pull pipe shape
        {
            if pipes3D[n] == nil {return} //bail on nil
            pipe3D = pipes3D[n]!   //else get pipe shape
        }
        else //2/1 new pipe? set up uid/name
        {
            pipe3D.uid  = oop.uid  //1/22 force UID to be same as data object
            pipe3D.name = n
        }

        //1/26 Need to get lats / lons the hard way for now...
        let from    = oop.PS.fromObject
        if let fmarker = markers3D[from] //4/28
        {
             let flat    = fmarker.lat
             let flon    = fmarker.lon
             let sPos00  = getMarkerParentPositionByName(name:from)
             let toObj   = oop.PS.toObject
             var sPos01  = fmarker.position
             var tlat    = Double.pi/2.0
             var tlon    = 0.0
             var isShape = false   //1/28
             
             if let sphereNode = shapes3D[toObj]  //Found a shape as target?
             {
                 sPos01 = sphereNode.position
                 isShape = true
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
             //print("apn flatlon \(flat),\(flon)  tlatlon \(tlat),\(tlon) nn \(newNode)")
             //  11/29 match pipe color in corners
             pipe3D.pipeColor = pipe3D.getColorForChan(chan: oop.PS.fromChannel)
             let pipeNode = pipe3D.create3DPipe(flat : flat , flon : flon , sPos00  : sPos00 ,
                                                      tlat : tlat , tlon : tlon , sPos01  : sPos01 ,
                                                      isShape: isShape, newNode : newNode)
             if (newNode) //1/30
             {
                 pipeNode.name = n
                 pipe3D.addChildNode(pipeNode)     // add pipe to 3d object
                 oogieOrigin.addChildNode(pipe3D)  //1/20 new origin
                 pipes3D[n] = pipe3D  // dictionary of 3d objects
             }
        }
     } //end addPipe3DNode

 
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
    // 12/30 for adding pipes...
    func getMarkerParentPositionByName (name : String) -> SCNVector3
    {
        var result  = SCNVector3Zero
        if let tvoice  = OVScene.sceneVoices[name] //find our voice...
        {
            let psName  = tvoice.OVS.shapeKey //get name of shape to retrieve position...
            if let tShape  = shapes3D[psName]    //ok look up shape
            {
                result = tShape.position       //and get result!
            }
        }
        return result
    } //end getMarkerParentPositionByName
    
   
    //=====<oogie2D mainVC>====================================================
    // 4/28 redo for dict
    func findMarkerByUID(uid:String) -> String
    {
        for (key,m) in markers3D
        { if uid == m.uid {return key} }
        return ""
    } //end findMarkerByUID
    
    
    //=====<oogie2D mainVC>====================================================
    // 10/21 shapes become dictionary
    func findShapeByUID(uid:String) -> String
    {
        for (key,shape) in shapes3D
        { if uid == shape.uid { return key } }
        return ""
    } //end findShapeByUID
    
    //=====<oogie2D mainVC>====================================================
    //WTF? when this is called all pipes have different uid's
    //  than what we're matching against! are new UIDs getting made over and over?
    func findPipe(uid:String) -> String
    {
     
        for (name,pipe) in pipes3D
        { if uid == pipe.uid
        {
            return name }
        }
        return ""
    } //end findPipe
    
    //=====<oogie2D mainVC>====================================================
    func handle3DUpdates(updates3D:[String])
    {
        if updating3D {return}
        updating3D = true
        for nextString in updates3D //get next array element, a set of substrings with colon separators
        {
            let ops3D = nextString.split(separator: ":")
            if ops3D.count > 1  //got valid sequence?
            {
                let op  = String(ops3D[0])
                let key = String(ops3D[1])
                switch op
                {
                case "setTimerSpeed":   // update 3D shape timer speed?
                    if ops3D.count > 2  // got a 3rd data value?
                    {
                        guard let pipeVal = Double(ops3D[2]) else {break}  // get data from pipe
                        guard let shape3D = shapes3D[key]    else {break}  // 3D shape to apply data to
                        //5/7 pulled                                shape3D.setTimerSpeed(rs: Double(pipeVal))
                    }
                case "update3DShapeByKey": update3DShapeByKey (key:key) //handle shape param change
                case "updatePipeTexture":  // update pipe texture motion
                    if let pipe3D = pipes3D[key] //get 3D pipe handle
                    {
                        guard let pipe = OVScene.scenePipes[key] else {break} //also need pipe data handle
                        let vals = pipe.ibuffer // get raw pipe input data...pass to 3D object
                        pipe3D.texturePipe(phase:0.0 , chan: pipe.PS.fromChannel.lowercased(),
                                           vals: vals, vsize: vals.count , bptr : pipe.bptr)
                } //end pipe3D
                case "updateMarkerPosition":  // change a marker 3D position
                    if let marker = markers3D[key]
                    {
                        guard let voice = OVScene.sceneVoices[key] else {break}
                        marker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
                } //end if let
                case "updatePipePosition":  //change a pipe 3D position
                    if let invoice = OVScene.sceneVoices[key]
                    {
                        if !updatingPipe { updatePipeByVoice(v:invoice) }
                    }
                case "updateMarkerRGB": // change marker color (3 xtra args)
                    if ops3D.count > 4  //got valid sequence? (op:key:r:g:b)
                    {
                        guard let rr = Int(ops3D[2]) else {break}  //get rgb ints
                        guard let gg = Int(ops3D[3]) else {break}
                        guard let bb = Int(ops3D[4]) else {break}
                        guard let marker3D = markers3D[key] else {break}
                        marker3D.updateRGBData(rrr: rr, ggg: gg, bbb: bb)
                    }
                case "updateMarkerPlayed":   // update marker played status?
                    if ops3D.count > 2      // got a 3rd data value?
                    {
                        let gotPlayed      = String(ops3D[2])   // get data from pipe
                        guard let marker3D = markers3D[key] else {break}
                        marker3D.gotPlayed = gotPlayed == "1"
                    }
                default:break
                }  //end switch
            }     //end count > 1
        } //end for nextString
        updating3D = false
    } //end handle3DUpdates
    
    //=====<oogie2D mainVC>====================================================
    // 5/3 calls a huuuuge routine in the scene object
    //   gets data from pipes into params
    //   loops over all voices and produces sounds
    //   propagates output channels into pipes
    // next the updates3D result is iterated over and any 3D scene updates made
    @objc func handlePipesMarkersAnd3D()
    {
        // pass in edit type if any and knobmode, sends back notification of 3D changes
        OVScene.playAllPipesMarkers(editing: whatWeBeEditing, knobMode: knobMode)
    } //end handlePipesMarkersAnd3D
    
    
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
        shouldNOTUpdateMarkers = (markers3D.count == 0 || vc != nil) //4/28
        if  shouldNOTUpdateMarkers  {return;}
        //iterate thru dictionary of voices...
        for (_,nextMarker) in markers3D //4/28 new dict
        {
            nextMarker.updateMarkerPetalsAndColor()
            if nextMarker.gotPlayed
            {
                nextMarker.updateActivity()
            }
        } //end for name...
        
        //5/7 update shape rotations too
        updateAllShapeRotations()

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
        if (knobMode == "select") //5/3 User not editing a parameter? this is a menu button
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
        //4/26 Dig up last param value and save
        let sceneChanges = OVScene.setNewParamValue(editing : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : OVScene.lastFieldDouble,
                                toString : OVScene.lastFieldString )
        update3DSceneForSceneChanges(sceneChanges)

        if OVScene.selectedFieldType == "double"  //update marker as needed...
        {
            if whatWeBeEditing == "voice"      {
                selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
            }
            else if whatWeBeEditing == "shape" {
                update3DShapeByKey (key:OVScene.selectedShapeKey)
                if let sshape = shapes3D[OVScene.selectedShapeKey] //1/26 also set 3d node spin rate to last value
                {
                    //5/7 NEED to set timer speed in OogieShape!!
                    //5/7 pulledsshape.setTimerSpeed(rs: OVScene.selectedShape.OOS.rotSpeed) //1/14 invalidate/reset timer
                }
            } //end else
            //1/26 missing pipe?
        }
        knobMode = "select" //back to select mode
        updateWheelAndParamButtons()
    } //end cancelEdit
    
    //=====<oogie2D mainVC>====================================================
    // take unit xy coords from voice, apply to our sphere..
    func updatePointer()
    {
    }

      
    //------<UITextFieldDelegate>-------------------------
    // 10/9  UITExtFieldDelegate...
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.text = "" //Clear shit out
        return true
    }
    //------<UITextFieldDelegate>-------------------------
    // 4/26 pull lastFieldString ref
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let sceneChanges = OVScene.setNewParamValue(editing : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(knobValue),
                                toString : textField.text! )
        update3DSceneForSceneChanges(sceneChanges) //4/29

        pLabel.isHidden = false //10/10 show param label again
        editSelect( editButton)  //Simulate button hit...
        textField.resignFirstResponder() //dismiss kb if up
        return true
    }

    //------<UITextFieldDelegate>-------------------------
    // 4/26 pull lastFieldString ref
    @IBAction func textChanged(_ sender: Any) {
        let sceneChanges = OVScene.setNewParamValue(editing : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(knobValue),
                                toString : textField.text! )
        update3DSceneForSceneChanges(sceneChanges) //4/29
    }

    //--------<TextureVCDelegate.-------------------------------------
    func cancelled()
    {
        editSelect(editButton) // back to param select...
    }
    
    //--------<TextureVCDelegate.-------------------------------------
    func gotTexture(name: String, tex: UIImage)
    {
        if let shape3D = shapes3D[OVScene.selectedShapeKey]
        {
            shape3D.setBitmapImage(i: tex) //set 3d shape texture
            shape3D.name           = name // save texture name
            OVScene.selectedShape.setBitmap(s: name)   //5/8 forgot!
            OVScene.selectedShape.OOS.texture = name
            //11/24 Store immediately back into scene!
            OVScene.sceneShapes[OVScene.selectedShapeKey] = OVScene.selectedShape
            editSelect(editButton)              // leave edit mode
        }
    }
    
    
    func chooserCancelled()
    {
        print("...cancel")
        OVScene.startLoop() // Start music up again...
    }

    //---<chooserDelegate>--------------------------------------
    //Delegate callback from Chooser...
    func chooserChoseFile(name: String)
    {
        if chooserMode == "loadAllPatches"
        {
            let ppp = allP.getPatchByName(name: name)
            print("ppp \(ppp)")
        }
        else //handle scene?
        {
            OVSceneName  = name
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            self.OVScene.OSC = DataManager.loadScene(OVSceneName, with: OSCStruct.self)
            self.OVScene.OSC.unpackParams()       //DHS 11/22 unpack scene params
            self.OVScene.OSC.name = OVSceneName //DHS 5/10 wups
            #if VERSION_2D
            setCamXYZ() //11/24 get any 3D scene cam position...
            #endif
            self.clearAll3DNodes(scene:scene)   // Clear any SCNNodes
//            self.clearScene()                //get rid of old scene data
            self.create3DScene(scene:scene) //  then create new scene from file
            pLabel.updateLabelOnly(lStr:"Loaded " + OVSceneName)
            self.OVScene.sceneLoaded = true
            OVScene.startLoop() // Start music up again...

        }
    } //end choseFile
    
    
    //---<chooserDelegate>--------------------------------------
    // 11/17 new delegate return w/ filenames from chooser
    func newFolderContents(c: [String])
    {
       // patchNamez = c
       // patchNum = 0

    }

    //---<chooserDelegate>--------------------------------------
    //Delegate callback from Chooser...
    func needToSaveFile(name: String) {
        OVSceneName = name
        OVScene.packupSceneAndSave(sname:OVSceneName)
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
            OVScene.reloadAllPatchesInScene(namez : namez)
        }
        
    }

} //end vc class, line 1413 as of 10/10

