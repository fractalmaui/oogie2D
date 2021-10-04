//  __     ___                ____            _             _ _
//  \ \   / (_) _____      __/ ___|___  _ __ | |_ _ __ ___ | | | ___ _ __
//   \ \ / /| |/ _ \ \ /\ / / |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
//    \ V / | |  __/\ V  V /| |__| (_) | | | | |_| | | (_) | | |  __/ |
//     \_/  |_|\___| \_/\_/  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|
//
//  ViewController.swift
//  oogie2D
//
// HOME shape:
//  /Users/davescruton/Library/Developer/CoreSimulator/Devices/
//     B3D9CFC0-E3F7-4EDC-B93A-6E53FBA6E3FD/data/Containers/Data/Application/
//     8E8E75B6-7D09-4216-A5E1-37730D2A207B/Documents/scenes//default
// ... see older impounds for earlier change comments
//  5/2    add updatePipeByUID,updatePipeByShape
//  5/3    move playColors to oogieVoice, move bmp from 3dShape to oogieShape,
//          change knobMode to string move playAllPipesMarkers to oogieScene,
//          add handlePipesMarkersAnd3D
//  5/4    change deleteVoice and deleteShape to work with keys,
//          also halt Shape timers b4 delete
//         add notification between playAllPipes in OogieScene and handle3DUpdates
//  5/8    update chooser protocol, add chooserCancelled, add haltLoop and startLoop
//           around file loads
//  5/11   integrate TIFFIE load/save
//  5/12   add resetCamera
//  5/14   improve clearScene, fix missing calls to it, add colorTimerPeriod
//  8/11/21 pull rotary editor, add same editor as in oogieCam
//  9/1    add patch select, change editing handling in setParamValue calls
//  9/11   add L/R/U/D animations for panels, add shapeEditPanel, pull patchEditVC
//  9/14   add pipeEdit
//  9/15   didSetControlValue uses setNewParamValue OK now
//  9/22   fix bug in updatePipeByShape
//  9/23   pull editSelect
//  9/24   add dismiss for panels, pull updateUIForDeselectVoiceOrShape
//  9/25   pull selects / deselects from handleToucch, shapes uid indexed now
//  9/27   convert markers to uid-indexed, pull removeVoice
//  9/28   finish voice/pipe/shape conversion to UID keyibg, make chooser class member
import UIKit
import SceneKit
import Photos

let pi    = 3.141592627
let twoPi = 6.2831852

//Scene unpacked params live here for now...
var OVtempo = 135 //Move to params ASAP
var camXform = SCNMatrix4()

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,chooserDelegate,UIGestureRecognizerDelegate,SCNSceneRendererDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,
                      controlPanelDelegate,patchPanelDelegate,shapePanelDelegate,pipePanelDelegate{

    @IBOutlet weak var skView: SCNView!
    @IBOutlet weak var spnl: synthPanel!
    @IBOutlet weak var editButtonView: UIView!
    @IBOutlet weak var paramKnob: Knob!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var editButton: UIButton!

    @IBOutlet weak var voiceEditPanels: UIView!    
    @IBOutlet weak var shapeEditPanels: UIView!
    @IBOutlet weak var pipeEditPanels: UIView!
    
    var colorTimer = Timer()
    //var playColorsTimer = Timer()
    var pLabel = infoText()
    //10/29 version info (mostly for debugging)
    var version = ""
    var build   = ""
    //10/17 solo
    var soloVoiceID = ""
    var touchLocation = CGPoint()
    var latestTouch   = UITouch()
    var chooserMode = ""
    var shouldNOTUpdateMarkers = false
    var oldvpname = ""; //for control value changes
    var updatingPipe = false   //1/25
    //12/2 haptics for wheel controls
    var fbgenerator = UISelectionFeedbackGenerator()
    var cPanel  = controlPanel()

    var paPanel = patchPanel()
    var sPanel  = shapePanel()
    var piPanel = pipePanel()
    
    var chooser = chooserVC()

    var viewWid :CGFloat = 0
    var viewHit :CGFloat = 0

    // 9/13 texture cache...
    let tc = texCache.sharedInstance
    // 9/18 oogieVoiceParams....
    var OVP  =  OogieVoiceParams.sharedInstance //9/19/21 oogie voice params
    var OSP  =  OogieShapeParams.sharedInstance //9/19/21 oogie shape params
    var OPP  =  OogiePipeParams.sharedInstance //9/19/21 oogie shape params
    var OPaP =  OogiePatchParams.sharedInstance //9/28

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
    var paramEdits = edits.sharedInstance
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
    var OVSoundPack       = "Synth/Perc" //9/16 keep track of selected soundpack
    var isPlaying         = false
    var updating3D        = false
    var screenCaptureFlag = false // Used by TIFFIE
    var needTiffie        = false // Used by TIFFIE

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
        // 9/13/21 wups, we need to add to skview?
        skView.addGestureRecognizer(lpgr)
        //self.view.addGestureRecognizer(lpgr)
        
        
        camXform = SCNMatrix4Identity //11/24 add camera matrix from scene file
        camXform.m43 = 6.0   //5/1 back off camera on z axis
        //Get our default scene, move to appdelegate?
        // OK we are getting path name, but WHY not loaded??
        // PROBLEM: a lot of patches may get loaded into voices, but
        //  NONE of the buffer pointers are OK.  THIS NEEDS TO BE RECTIFIED!
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
        viewWid = csz.width   //10/27 enforce portrait aspect ratio!
        viewHit = csz.height
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
        menuButton.backgroundColor = .gray
        menuButton.layer.cornerRadius = 40

        //9/13 reset button
        pRect = CGRect(x: 100 , y: viewHit - inset2, width: pwh, height: pwh)
        resetButton.frame = pRect
        resetButton.layer.cornerRadius = 40
        resetButton.isHidden = true
        
        //8/11/21 voiceEditPanels view... double wide
        let allphit = 320
        // 9/11 voiceEditPanels start off bottom of screen
        voiceEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(2*viewWid), height: allphit)
//        voiceEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) - allphit, width: Int(2*viewWid), height: allphit)
        //Live controls / patch or colorpack select
        //10/1 REDO: just set view rect here, then add to view hierarchy
        cPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        voiceEditPanels.backgroundColor = .clear
        voiceEditPanels.addSubview(cPanel)
        cPanel.delegate = self
        
        //10/1 REDO: just set view rect here, then add to view hierarchy
        paPanel.setupView(CGRect(x: Int(viewWid) , y: 0, width: Int(viewWid), height: allphit))
        voiceEditPanels.addSubview(paPanel)
        paPanel.delegate = self
        
        voiceEditPanels.isHidden = false //true
        //9/28 make chooser class member
        chooser.delegate = self

        // 9/11 shape editing panel(s)
        shapeEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(viewWid), height: allphit)
        // 9/1/21 pro panel, add to RIGHT of control panel in allpanhels
        //10/1 REDO: just set view rect here, then add to view hierarchy
        sPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        shapeEditPanels.backgroundColor = .clear
        shapeEditPanels.addSubview(sPanel)
        sPanel.delegate = self
        shapeEditPanels.isHidden = false
        
        // 9/14 pipe editing panel(s)
        pipeEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(viewWid), height: allphit)
        //10/1 REDO: just set view rect here, then add to view hierarchy
        piPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        pipeEditPanels.backgroundColor = .clear
        pipeEditPanels.addSubview(piPanel)
        piPanel.delegate = self
        pipeEditPanels.isHidden = false

        
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
        var colorTimerPeriod = 0.1 //5/14 default on settings bundle fail
        if let ctp = appSettings["colorTimerPeriod"] as? Double //5/14 get time from settings bundle
        {
            colorTimerPeriod = ctp
        }
        print("...start colorTimer, period \(colorTimerPeriod)")
        colorTimer = Timer.scheduledTimer(timeInterval: colorTimerPeriod, target: self, selector: #selector(self.updateAllMarkers), userInfo:  nil, repeats: true)
        _ = DataManager.getSceneVersion(fname:"default")
        //Try running color player in bkgd...
        print("STARTLOOP Should ONLY HAPPEN ONCE!")
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
       //6/29/21 FIX! allP.getAllPatchInfo() //11/22 Get sample rates, key offsets, etc.
        //6/29/21 FIX! allP.loadGMOffsets()  //11/22
        //DHS 10/16 create our scene?
        create3DScene(scene: scene)
        //CAN this be done earlier???
        print("...samples loaded, hopefully we can set up soundpack/patch stuff...")
        cPanel.spNames = allP.allSoundPackNames
        paPanel.sampleNames = allP.getGMPercussionNames()

        //9/1 get patch names...
        var pnames = [String]()
        pnames.append("Random")
       // [allp getSoundPackByNameWithName:spName];
            // 9/1 make this the last soundpack used
        allP.getSoundPackByName(name: OVSoundPack)
        let psize = allP.getSoundPackSize()
        if psize > 0
        {
            for i in 0...psize-1
            {
                let pname = allP.getSoundPackPatchNameByIndex(index: i)
                pnames.append(pname)
            }
        }
        cPanel.paNames = pnames
    }
    

    //=====<oogie2D mainVC>====================================================
    // assumes scene loaded into structs, finish setup...
    func finishSettingUpScene()
    {
        //9/28 this is getting reset to bogus value??
//        self.OVSceneName = self.OVScene.OSC.name //5/11 wups!
        self.OVScene.OSC.unpackParams()       //DHS 11/22 unpack scene params
        #if VERSION_2D
        setCamXYZ() //11/24 get any 3D scene cam position...
        #endif
        self.create3DScene(scene:scene) //  then create new scene from file
        pLabel.updateLabelOnly(lStr:"Loaded " + OVSceneName)
        self.OVScene.sceneLoaded = true
        OVScene.startLoop() // Start music up again...

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
        print("Longperss")
        if gestureReconizer.state != UIGestureRecognizer.State.ended {
            let pp = gestureReconizer.location(ofTouch: 0, in: self.view)
            // 11/3 make sure longpress is near original touch spot!
            if ((abs(pp.x - touchLocation.x) < 40) &&
                (abs(pp.y - touchLocation.y) < 40))
            {
                if whatWeBeEditing == "voice"      { voiceMenu() }
                else if whatWeBeEditing == "shape" { shapeMenu() }
                else if whatWeBeEditing == "pipe"  { pipeMenu() }
                else //9/13 halt voices ?
                {
                    print("release all...")
                    (sfx() as! soundFX).releaseAllNotes()
                }
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
        let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(OVScene.selectedFieldDefault),
                                toString : OVScene.selectedFieldDefaultString )
        update3DSceneForSceneChanges(sceneChanges)
        knobValue = Float(OVScene.selectedFieldDefault)  //9/17 make sure knob is set to param value
        selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
        //8/11/21 resetKnobToNewValues(kval:knobValue , kmin : OVScene.selectedFieldMin , kmax : OVScene.selectedFieldMax)
    }
    
    //=====<oogie2D mainVC>====================================================
    func updateAllShapeRotations()
    {
        for (uid,shape3D) in shapes3D
        {
            //get rotation from oogieshape
            if let shape = OVScene.sceneShapes[uid]
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
                update3DShapeBy(uid:OVScene.selectedShapeKey)
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
        else if segue.identifier == "chooserLoadSegue"  || segue.identifier == "chooserSaveSegue"{
            OVScene.setLoopQuiet(flag: true) //9/13/21 quiet loop!
            // 9/28 note if we dont get fresh copy of chooser, the mode doesnt stick!!
            chooser = segue.destination as! chooserVC  //9/28 declare chooser at init
            chooser.delegate = self
            chooser.mode     = chooserMode
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
    // 5/12 new
    func resetCamera()
    {
        let crTuple = OVScene.getSceneCentroidAndRadius()
        camXform = SCNMatrix4Identity //11/24 add camera matrix from scene file
        let centroid = crTuple.c
        let radius   = max(3,crTuple.r)
        camXform.m41 = centroid.x  //set X coord
        camXform.m42 = centroid.y  //set X coord
        camXform.m43 = centroid.z + 2 * radius   //5/1 back off camera on z axis
        setCamXYZ()
    } //end resetCamera

    //=====<oogie2D mainVC>====================================================
    // 3/30 updates 3d keyboard for OVScene.selected voice....
    func updatePkeys()
    {
        self.pkeys.resetForVoice( nMode : self.OVScene.selectedVoice.OVS.noteMode ,
                                  bMidi : self.OVScene.selectedVoice.OVS.bottomMidi ,
                                  tMidi : self.OVScene.selectedVoice.OVS.topMidi)
    } //end updatePkeys
    


    
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
    func update3DShapeBy(uid : String)
    {
        if let sshape3d = shapes3D[uid] //get named SphereShape
        {
            var shapeStruct = OVScene.selectedShape  //Get current shape object
            //print("update3DShapeBy:\(uid)  xyscale \(shapeStruct.OOS.uScale),\(shapeStruct.OOS.vScale)")
            if uid != OVScene.selectedShapeKey
            {
                shapeStruct = OVScene.sceneShapes[uid]!
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
    } //end update3DShapeBy
    
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
    
    //=====<oogie2D mainVC>====================================================
    //  4/19 cluge?  is this the right place?
    func setMasterPitchShiftForAllVoices()
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        for (_,voice) in OVScene.sceneVoices
        {
            voice.masterPitch = appDelegate.masterPitch
        }
    } //end setMasterPitchShiftForAllVoices
    
    //=====<oogie2D mainVC>====================================================
     // 9/19 generic param edit, workx on shapes,voices, etc
     func editParam(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         var dval = Double(newVal) //10/2 need to convert in some cases..
         var ptype = ""
         if      whatWeBeEditing == "voice" {ptype = OVP.getParamType(pname: pname)}
         else if whatWeBeEditing == "shape" {ptype = OSP.getParamType(pname: pname)}
         else if whatWeBeEditing == "pipe"  {ptype = OPP.getParamType(pname: pname)}
         else if whatWeBeEditing == "patch" {ptype = OPaP.getParamType(pname: pname)} // 9/30

         //let ptype = OVP.getParamType(pname: pname)
         if pname != oldvpname //user changed parameter? load up info to UI
         {
             var choiceStrings : [String] = []
             var pt = TFLOAT_TTYPE
             if ptype == "int"
             {
                 pt = TINT_TTYPE
                 choiceStrings = OVP.getParamChoices(pname: pname)
             }
             else if ptype == "string"
             {
                pt = TSTRING_TTYPE
                choiceStrings = OVP.getParamChoices(pname: pname)
             }
             else if ptype == "text"
             {
                pt = TSTRING_TTYPE
             }
            //9/22 WOW the pmax may be totally wrong here!
            var pmax : Double = 100.0
            if whatWeBeEditing == "pipe" {pmax = 255.0} //9/22 more range for pipe params?
             pLabel.setupForParam( pname : pname , ptype : pt ,
                                   pmin : 0 , pmax : pmax , choiceStrings: choiceStrings)
             oldvpname = pname; //remember for next time
             OVScene.selectedFieldName = pname
             if      whatWeBeEditing == "voice" {OVScene.loadCurrentVoiceParams()}
             else if whatWeBeEditing == "shape" {OVScene.loadCurrentShapeParams()}
             else if whatWeBeEditing == "pipe"  {OVScene.loadCurrentPipeParams()}
             else if whatWeBeEditing == "patch" {OVScene.loadCurrentPatchParams()} //9/30 new
         }
         //convert from slider unit to proper units...
         // 9/30 there is a problem here for some param types???
        if OVScene.selectedFieldType == "double" //10/2 check for double type param
        {
           dval = OVScene.unitToParam (inval : dval)  //oknconvertit
        }
         pLabel.updateit(value : Double(dval))
         //4/26 Dig up last param value and save
         let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
                                                     named : pname,
                                                     toDouble : Double(newVal),
                                                     toString : pvalue )
        // 9/27 wups, save back to scene!!!asdf
        OVScene.saveEditBackToSceneWith(objType:whatWeBeEditing)

        update3DSceneForSceneChanges(sceneChanges)
     } // end editParam
     
  
  
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
               {
                updatingPipe = false //9/22 clear flag for 2nd update
                updatePipeByVoice(v:v)
               }
        }
        //Get all incoming pipes to shape, update positions
        for puid in s.inPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByShape

    //=======>ARKit MainVC===================================
    // broke out from updatePipeByVoice 5/2
    func updatePipeByUID(_ puid:String)
    {
// 9/25       if let n = OVScene.pipeUIDToName[puid]                // get pipes name
//        {
            if let pipeObj = OVScene.scenePipes[puid]           //   find pipe struct
                {
                    addPipe3DNode(oop: pipeObj, newNode : false) //1/30
                    let vals = pipeObj.ibuffer //11/28 want raw unscaled here!
                    if let pipe3D = pipes3D[puid]    // get Pipe 3dobject itself to restore texture
                    {
                        pipe3D.texturePipe(phase:0.0 , chan: pipeObj.PS.fromChannel.lowercased(),
                                           vals: vals, vsize: vals.count , bptr : pipeObj.bptr)
                    }
                }
// 9/25       }

    }
    
    
     
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
        guard let sceneView   = skView else {return}
        touchLocation         = latestTouch.location(in: sceneView)
        guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
        let hitNode  = nodeHitTest.node
        var selected = false //9/25
        if let uid = hitNode.name //9/25 use uid not name now...
        {
            if uid.contains("pianoKeys") ///2/28 keyboard hit test => output note
            {
                let localCoordinates = nodeHitTest.localCoordinates
                handleKeyboardPressWith(coords:localCoordinates)
            }
            else if uid.contains("shape") //Found a shape? get which one
            {
                selected = selectOrDeselectShapeBy(uid:uid)
            }
            else if uid.contains("voice") // 9/27 Found a marker? get which one
            {
                selected = selectOrDeselectMarkerBy(uid:uid)
             }
            else if uid.contains("pipe") //Found a pipe? get which one
            {
                selected = selectOrDeselectPipeBy(uid:uid)
            }
        }     //end let name
        if !selected
        {
            cancelEdit() //DHS 11/3 if editing, cancel
            whatWeBeEditing = ""
        }
    } //end handleTouch
    
    //=====<oogie2D mainVC>====================================================
    // 9/25 use 3d coords to find a key and sound it if needed
    func handleKeyboardPressWith(coords : SCNVector3)
    {
        let tMidiNote = pkeys.getTouchedMidiNote( hitCoords  : coords )
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
    } //end handleKeyboardPressWith

    //=====<oogie2D mainVC>====================================================
    // 9/25 Toggle select for desired marker, returns selected status asdf
    func selectOrDeselectMarkerBy(uid:String) -> Bool
    {
        var selected = false
//  9/27      let key = findMarkerByUID(uid: name) //4/30 redo find
//        if (key != "")
//        {
            unselectAnyOldStuffBy(uid:uid)
            shiftPanelDown(panel: shapeEditPanels)  //put away shape editor
            shiftPanelDown(panel: pipeEditPanels)   //put away pipe editor
            if let testMarker = markers3D[uid]
            {
                selectedMarker = testMarker
                selectedMarker.toggleHighlight()
                if selectedMarker.highlighted  //hilited? Set up edit
                {
                    //DHS 1/16:this looks to get OLD values not edited values!
                    if let testVoice = OVScene.sceneVoices[uid] //got legit voice?
                    {
                        whatWeBeEditing = "voice"
                        //9/1/21 TEST CLUGE???
                        //If OVSCene needs to know this then whatWeBeEditing is moot!
                        OVScene.editing = whatWeBeEditing;
                        if let smname = selectedMarker.name  //update param label w/ name
                        { self.pLabel.updateLabelOnly(lStr:"Selected " + smname) }
                        OVScene.selectedVoice     = testVoice //Get associated voice for this marker
                        OVScene.selectedMarkerKey = uid      //points to OVS struct in scene
                        selectedMarker.updatePanels(nameStr: OVScene.selectedMarkerKey) //10/11 add name panels
                        updatePkeys() //3/30 update kb if needed
                        //Pack params, send to VC
                        cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
                        cPanel.configureView()
                        //Need to hand a lot of stuff to patch panel...
                        paPanel.paramDict = OVScene.selectedVoice.getPatchParamDict()
                        paPanel.whichSamp = Int32(OVScene.selectedVoice.OVS.whichSamp)
                        paPanel.patchName = OVScene.selectedVoice.OVS.patchName  //9/30
                        paPanel.configureView()
                        shiftPanelUp(panel: voiceEditPanels) //9/11 shift controls so they are visible
                        shiftPanelRight(panel:voiceEditPanels) //10/1 make sure we start on control panel
                    }
                    selected = true
                }
                else
                {
                    selected = false
                    shiftPanelDown(panel: voiceEditPanels) //9/11 shift controls offscreen
                }
            } //end let testMarker...
// 9/27        } //end if key
        return selected
    } //end selectOrDeselectMarkerBy
    
    //=====<oogie2D mainVC>====================================================
    // 9/25 Toggle select for desired shape, returns selected status
    func selectOrDeselectShapeBy(uid:String) -> Bool
    {
        var selected = false
        unselectAnyOldStuffBy(uid: uid) //9/26
        shiftPanelDown(panel: voiceEditPanels)  //put away voice editor
        shiftPanelDown(panel: pipeEditPanels)   //put away pipe editor
        if let testShape = shapes3D[uid] //1/26
        {
            OVScene.selectedShapeKey = uid
            selectedSphere    = testShape
            selectedSphere.toggleHighlight()
            //Wow is this redundant?
            if selectedSphere.highlighted  //hilited? Set up edit
            {
                whatWeBeEditing = "shape"   //2/6 WTF?
                self.pLabel.updateLabelOnly(lStr:"Selected " + self.selectedSphere.name!)
                if let testShape = OVScene.sceneShapes[uid] //got legit voice?
                {
                    OVScene.selectedShape     = testShape
                    OVScene.selectedShapeKey  = uid //10/21
                    //2/3 add name/comment to 3d shape info box
                    selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                                comm: OVScene.selectedShape.OOS.comment)
                    sPanel.texNames = tc.loadNamesToArray() //populates texture chooser
                    shiftPanelUp(panel: shapeEditPanels) //9/11 shift controls so they are visible
                    sPanel.paramDict = OVScene.selectedShape.getParamDict()
                    sPanel.configureView() //9/12 loadup stuff
                }
                selected = true
            }
            else //unhighlighted?
            {
                shiftPanelDown(panel: shapeEditPanels) //9/11 shift controls so they are visible
                selected = false
            }
        }
        return selected
    } //end selectOrDeselectShapeBy

    //=====<oogie2D mainVC>====================================================
    //  NOTE: right now we are finding pipes by name. it should be by UID!
    //    however this requires changing the way pipes3D is used, and
    //    that has lots of repercussions
    // 9/25 Toggle select for desired pipe, returns selected status
    func selectOrDeselectPipeBy(uid:String) -> Bool
    {
        var selected = false
//9/25        let key = findPipe(uid: name)
        if let pipe3D = pipes3D[uid]
        {
            selectedPipeShape = pipe3D
            unselectAnyOldStuffBy(uid:uid) //11/30
            shiftPanelDown(panel: voiceEditPanels)  //put away shape editor
            shiftPanelDown(panel: shapeEditPanels)   //put away pipe editor
            OVScene.selectedPipeKey = uid
            selectedPipeShape.toggleHighlight()
            //9/25 WOW. this is looking at the LOADED pipe data.
            //  however data freshly loaded into the scene memory has NEW UIDs.
            //  should I keep the old uids from scenes when creating objects?
            if let spo = OVScene.scenePipes[uid] //now get pipe record...
            {
                whatWeBeEditing      = "pipe"  //2/6 WTF?
                OVScene.selectedPipe = spo // get 3d scene object...
                //Beam pipe name and output buffer to a texture in the pipe...
                // ideally this should be updaged on a timer!
                let name = OVScene.selectedPipe.PS.name //9/25
                selectedPipeShape.updateInfo(nameStr: name, vals: spo.ibuffer)
                selected = true
                if selectedPipeShape.highlighted  //hilited? Set up edit
                {
                    self.pLabel.updateLabelOnly(lStr:"Selected " + spo.PS.name)
                    shiftPanelUp(panel: pipeEditPanels) //9/11 shift controls so they are visible
                    piPanel.paramDict = OVScene.selectedPipe.getParamDict()
                    //WOW THIS IS HOKEY!
                    // get correct output parameter names for this pipe
                    OVScene.selectedFieldName = "outputparam" //Force selection to get possible output pipe values...
                    OVScene.loadCurrentPipeParams()
                    piPanel.outputNames = OVScene.selectedFieldDisplayVals //now we should have our outputs
                    piPanel.configureView() //9/12 loadup stuff
                    selected = true
                }
                else //deselect?
                {
                    shiftPanelDown(panel: pipeEditPanels)
                    selected = false
                }
            } //end let spo
        }    //end let pipe3D
        return selected
    } //end selectOrDeselectPipeBy
    

    //=====<oogie2D mainVC>====================================================
    // called when user selects something, unhighlights old crap
    // 9/25 redo for uid not name
    func unselectAnyOldStuffBy(uid:String)
    {
        if whatWeBeEditing == "voice"
        {
            //selectedMarker.unHighlight()
            // is a different marker selected? deselect!
            if  selectedMarker.highlighted &&
                 OVScene.selectedMarkerKey != uid
                { selectedMarker.unHighlight() }
            OVScene.selectedMarkerKey = ""
        }
        else if whatWeBeEditing == "shape"
        {
            //selectedSphere.unHighlight()
            if selectedSphere.highlighted &&
                OVScene.selectedShapeKey != uid
                { selectedSphere.unHighlight() }
            OVScene.selectedShapeKey = ""
        }
        else if whatWeBeEditing == "pipe"
        {
            //selectedPipeShape.unHighlight()
            if selectedPipeShape.highlighted &&
                OVScene.selectedPipeKey != uid
                { selectedPipeShape.unHighlight() }
            OVScene.selectedPipeKey = ""
        }

       // if selectedSphere.highlighted && selectedShapeKey != testName

    } //end unselectAnyOldStuff
    

    
    //=====<oogie2D mainVC>====================================================
    @objc func synthXClicked(sender : UIButton){
        spnl.isHidden = true
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
        alert.addAction(UIAlertAction(title: "Load Scene...", style: .default, handler: { action in
            self.chooserMode = "loadScene"
            self.performSegue(withIdentifier: "chooserLoadSegue", sender: self)
        }))
//9/28 no tiffie for now
//        alert.addAction(UIAlertAction(title: "Load TIFFIE...", style: .default, handler: { action in
//            self.chooseImageForSceneLoad() ///5/11 new kind of scene storage!
//        }))
        alert.addAction(UIAlertAction(title: "Save Scene", style: .default, handler: { action in
            self.OVScene.packupSceneAndSave(sname:self.OVSceneName)
            self.pLabel.updateLabelOnly(lStr:"Saved " + self.OVSceneName)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene As...", style: .default, handler: { action in
            self.chooserMode = "saveSceneAs" //9/28
            self.performSegue(withIdentifier: "chooserSaveSegue", sender: self)
        }))
//9/28 no tiffie for now
//        alert.addAction(UIAlertAction(title: "Save TIFFIE...", style: .default, handler: { action in
//            self.packupAndSaveTiffie() ///5/11 new kind of scene storage!
//        }))
        alert.addAction(UIAlertAction(title: "Patch Editor", style: .default, handler: { action in
            self.performSegue(withIdentifier: "EditPatchSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Clear Scene", style: .default, handler: { action in
            self.clearScenePrompt()
        }))
        alert.addAction(UIAlertAction(title: "Dump Buffers", style: .default, handler: { action in
            self.dumpBuffers()
        }))
        alert.addAction(UIAlertAction(title: "Textures...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "textureSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Toggle Piano KB", style: .default, handler: { action in
            self.updatePkeys() //3/30 update kb if needed
            self.pkeys.isHidden = !self.pkeys.isHidden
        }))
        alert.addAction(UIAlertAction(title: "Reset Camera", style: .default, handler: { action in
            self.resetCamera()
        }))

        alert.addAction(UIAlertAction(title: "Dump Scene", style: .default, handler: { action in
            let d = self.allP.getBufferReport()
            print ("scene dump: \(d)")
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
        }))

        tstr = "Mute"
        if OVScene.selectedVoice.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            self.OVScene.selectedVoice.muted = !self.OVScene.selectedVoice.muted
            self.selectedMarker.toggleHighlight()
        }))
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS, op: "clone")
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
            self.addShapeToScene(shapeOSS: self.OVScene.selectedShape.OOS, op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShapePrompt(shape: self.OVScene.selectedShape.OOS)
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS,  op: "new")
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            self.OVScene.resetShapeByKey(key: self.OVScene.selectedShape.OOS.key)  //Reset shape object from scene
            self.update3DShapeBy(uid:self.OVScene.selectedShape.OOS.uid)  //9/27 Ripple change thru to 3D
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
            self.deleteShapeBy(uid: shape.key)  //5/4 use key
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteShapePrompt
    
    //=====<oogie2D mainVC>====================================================
    // 2/6 redo: removes shape from scene / SCNNode 5/4 use key
    func deleteShapeBy(uid:String)
    {
        if let shape3D = shapes3D[uid] // got something to delete?
        {
            if let shapeNode = OVScene.sceneShapes[uid] //2/6 first,Get rid of any pipes!
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
                    if v.OVS.shapeKey == vkey { deleteVoiceBy(uid:vkey)}
                }
                shape3D.removeFromParentNode()          //Blow away 3d Shape
                shapes3D.removeValue(forKey: uid)       //  delete dict 3d entry
                if let shape = OVScene.sceneShapes[uid] //5/7 get shape datasource
                {
                    shape.haltSpinTimer()   //5/4 timer seems to linger after delete!!!
                }
                OVScene.sceneShapes.removeValue(forKey: uid) //  delete dict data entry
            } //end let shapeNode
        } // end let shape3D
    } //end deleteShapeBy
    
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
                OVScene.cleanupPipeInsAndOuts(uid:name)         // 1/22 cleanup ins and outs...
                //print("delete scenepipe \(name)")
                OVScene.scenePipes.removeValue(forKey: name)
            }       // Get rid of pipeObject
            // Always get rid of pipe 3D node
            print("deletePipeByUID \(puid)") //9/25 use uid now NOT name
            if let pipe3D = pipes3D[puid]
            {
                //print(".....delete3d pipe");
                pipe3D.removeFromParentNode()
                
            }       // Clean up SCNNode
            pipes3D.removeValue(forKey: puid)        // 9/25 Delete 3d Object
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
    func addPipeStepTwo(voice:OogieVoice , channel : String)
    {
        //print("step 2 chan \(channel)")
        //12/30 we should look in sceneShapes/sceneVoices for our list...
        let shapeList = OVScene.getListOfSceneShapeNames() //9/28
        let voiceList = OVScene.getListOfSceneVoiceNames()
        let alert = UIAlertController(title: "Choose Destination", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
        for l11 in shapeList
        {
            let uid = OVScene.findSceneShapeUIDByName ( name: l11)
            alert.addAction(UIAlertAction(title: l11, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : uid ,isShape: true)
            }))
        }
        for l12 in voiceList
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
        var menuNames = OSP.shapeParamNamesOKForPipe
        if !isShape {menuNames = OVP.voiceParamNamesOKForPipe}
        for pname in menuNames
            {
                alert.addAction(UIAlertAction(title: pname, style: .default, handler: { action in
                    //Add our pipe to scene... (BREAK OUT TO METHOD WHEN WORKING!)
                    let ps = PipeStruct(fromObject: voice.OVS.uid, fromChannel: channel.lowercased(), toObject: destination, toParam: pname.lowercased())
                    // 9/28 WTF?  let pcount = 1 + self.OVScene.scenePipes.count //use count to get name
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
            self.deletePipeBy(uid: self.OVScene.selectedPipe.PS.uid) //9/25
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deletePipePrompt

    //=====<oogie2D mainVC>====================================================
    // 11/30 removes pipe from scene / SCNNode
    // 9/25 change to uid access
    func deletePipeBy(uid:String)
    {
        if let pipe3D = pipes3D[uid]
        {
            pipe3D.removeFromParentNode()                //Blow away 3d Shape
            OVScene.cleanupPipeInsAndOuts(uid:uid)            // 1/22 cleanup ins and outs...
            OVScene.scenePipes.removeValue(forKey: uid)       //  and clear entry from
            pipes3D.removeValue(forKey: uid)           //   and data / shape dicts
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
            self.deleteVoiceBy(uid: voice.OVS.key)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteVoicePrompt

    //=====<oogie2D mainVC>====================================================
    // 10/27 removes voice from scene / SCNNode
    func deleteVoiceBy(uid:String)  //9/27 uid
    {
        if let marker = markers3D[uid]   //4/28 new dict
        {
            marker.removeFromParentNode()
            markers3D.removeValue(forKey: uid) //4/28 new dict
            OVScene.sceneVoices.removeValue(forKey: uid)       //  and remove data structure
        }
        // 2/6 what about input pipes?
    } //end deleteVoiceBy

    
    //=====<oogie2D mainVC>====================================================
    func dumpBuffers()
    {
        let d = allP.getBufferReport();
        print("dump \(d)")
        var dstr = ""
        for i in 0..<MAX_SAMPLES
        {
            let nn = NSNumber(value:i)
            let bn = d[nn];
            let bsize = (sfx() as! soundFX).getBufferSize(Int32(i))
            if bsize > 0
            {
                dstr = dstr + "[\(i)]:\(bsize): \(bn) \n"
            }
        }
       print(dstr)

    } //end dumpBuffers
    
    //=====<oogie2D mainVC>====================================================
    func clearScenePrompt()
    {
    let alert = UIAlertController(title: "Clear Current Scene?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.pLabel.updateLabelOnly(lStr:"Clear Scene...")
            self.clearScene(withDefaultScene: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end clearScenePrompt
    
    
    //=====<oogie2D mainVC>====================================================
    // 4/30 NOTE: this has a bug resetting the camera position!
    func clearScene(withDefaultScene addDefaultScene:Bool)
    {
        //9/28 NO panesl up please!
        shiftPanelDown(panel: voiceEditPanels)   //put away pipe editor
        shiftPanelDown(panel: shapeEditPanels)  //put away shape editor
        shiftPanelDown(panel: pipeEditPanels)   //put away pipe editor

        // 5/7 iterate over all shapes and halt timers first
        for (_,shape) in OVScene.sceneShapes
        {
            shape.haltSpinTimer()
            shape.cleanup() // 5/14 free bmp data too!            
        }
        self.OVScene.OSC.clearScene()       // Clear everything...
        self.OVScene.clearOogieStructs()    // Clear data structures
        self.clearAll3DNodes(scene:scene)    // Clear any SCNNodes
        if addDefaultScene //5/14
        {
            self.OVScene.createDefaultScene(named: "default")  //2/1/20 add an object
            self.create3DScene(scene:scene) //  then create new scene from file
            #if VERSION_2D
            cameraNode.transform = SCNMatrix4Identity
            cameraNode.position  = SCNVector3(x:0, y: 0, z: 6) //put camera back away from origin
            #endif
        }
    } //end clearScene
    
    //=====<oogie2D mainVC>====================================================
    func clearAll3DNodes(scene:SCNScene)
    {
        oogieOrigin.enumerateChildNodes { (node, _) in //1/20 new origin
            //print("remove node \(node.name)")
            if (node.name != nil) {node.removeFromParentNode()}
        }
        markers3D.removeAll() //4/28 new dict
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
            { addShapeToScene(shapeOSS: nextShape, op: "load") }
        //iterate thru dictionary of shapes...
        for (key, nextOVS) in OVScene.OSC.voices
            { addVoiceToScene(nextOVS: nextOVS,   op: "load") }
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
    
    
    var note : Int32 = 50
    var buf  : Int32 = 0
    //=====<oogie2D mainVC>====================================================
    @IBAction func testSelect(_ sender: Any) {
        
//        let dumpo = getBufferDump()
//        print("annd dump is \(dumpo)")
        shiftPanelDown(panel: voiceEditPanels) //9/11 shift controls offscreen

        
//        buf = buf + 1
//        if buf > 50 { buf = 0 }
//
//        let bsize = (sfx() as! soundFX).getBufferSize(buf)
//
//        print("incr buf : \(buf) size \(bsize)")
        
        //dumpDebugShit()
        //packupAndSaveTiffie()
       // createMTImage(name:"duhhhhhh")
        //
       // var dumpo = (sfx() as! soundFX).dumpBuffer(<#T##which: Int32##Int32#>, <#T##dsize: Int32##Int32#>)]
        
        //setSynthMasterLevel(128)
        
    } //end testSelect
    
    //====(OOGIECAM MainVC)============================================
    // 9/1/21 dump bufers, names, sizes
    func getBufferDump() -> String
    {
        print("dump buffers...");
        let D = allP.getBufferReport();
        var report = ""
        for i in 0...MAX_SAMPLES-1
        {
            let nn = NSNumber(value: i)
            let bn = D[nn]
            let bsize = (sfx() as! soundFX).getBufferSize(Int32(i))
            
//            NSNumber* nn = [NSNumber numberWithInt:i];
//            NSString *bn = D[nn]; //buffer name from allsamples
//            int bsize = [_sfx getBufferSize:i];
            // 6/20 ignore empties
            if bsize > 0
            {
                report = report + "[\(i)]: \(bsize) , \(bn)\n"
                    
                    //[report stringByAppendingString:[NSString stringWithFormat:@"[%d]:%6.6d: %@\n",i,bsize,bn]];
            }
        }
        return report;
    } //end getBufferDump
    
    
    //=====<oogie2D mainVC>====================================================
    @IBAction func test2Select(_ sender: Any) {

//OK this works with samples and ONE synth, cant get other synth patches loaded yet.
        (sfx() as! soundFX).setSynthMasterLevel(128)
        (sfx() as! soundFX).setSynthPLevel(50)
        (sfx() as! soundFX).setSynthPKeyOffset(50)
        (sfx() as! soundFX).setSynthPKeyDetune(50)
        (sfx() as! soundFX).setSynthVibAmpl(0)
        (sfx() as! soundFX).setSynthVibeAmpl(0)
        (sfx() as! soundFX).setSynthDetune(1)  //this was the mystery causing the nasty synth blart sound.
        var stype  = SYNTH_VOICE
        if buf > 7
        {
            stype = SAMPLE_VOICE
            (sfx() as! soundFX).setSynthAttack(0);
            (sfx() as! soundFX).setSynthDecay(0);
            (sfx() as! soundFX).setSynthSustain(0);
            (sfx() as! soundFX).setSynthRelease(0);
            (sfx() as! soundFX).setSynthSustainL(0);
        }
        else
        {
            (sfx() as! soundFX).setSynthAttack(50);
            (sfx() as! soundFX).setSynthDecay(5);
            (sfx() as! soundFX).setSynthSustain(10);
            (sfx() as! soundFX).setSynthSustainL(80);
            (sfx() as! soundFX).setSynthRelease(80);
            (sfx() as! soundFX).buildEnvelope(Int32(buf),true); //arg whichvoice?
            (sfx() as! soundFX).dumpEnvelope(Int32(buf));  
        }
        print("play note : \(note) type \(stype)")
        (sfx() as! soundFX).playNote(note,
                                     buf ,
                                     stype)
        note = note + 1
        if note > 80 { note = 50 }

    }
    
//    func getBufferDump()
//    {
//        for i in 0...255
//        {
//            let bsize = (sfx() as! soundFX).getBufferSize(Int32(i))
//            print("buffer[\(i)] : \(bsize)")
//        }
//    } //end getBufferDump


    
    
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
                    self.pLabel.updateLabelOnly(lStr:"Saved " + self.OVScene.OSC.name + " as TIFFIE")
                }
            }
        }
    } //end didRenderScene

    //=====<oogie2D mainVC>====================================================
    //  this just sets up some flags, the scene Renderer triggers actual save
    func packupAndSaveTiffie()
    {
        //Enable screen capture
        screenCaptureFlag = true
        needTiffie        = true   //after capture, save tiffie!
    } //end packupAndSaveTiffie
    
    
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
    func infoAlert(title:String , message : String)
    {
        let alert = UIAlertController(title: title, message: message,
                                      preferredStyle: UIAlertController.Style.alert)
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
    //  10/2 NOTE patch edits are applied in addVoiceSceneData
    func addVoiceToScene(nextOVS : OVStruct ,  op : String)
    {
        print("ADDVOICE: \(nextOVS)  op: \(op)")
        //First, set up scene structures, get fresh voice back...
        let newVoice = OVScene.addVoiceSceneData(nextOVS : nextOVS , op:op)
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
            let nextMarker  = Marker()
            nextMarker.name = voice.OVS.name //9/16 point to voice
            let uid = voice.OVS.uid
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


    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addShapeToScene (shapeOSS:OSStruct , op : String)
    {
        //9/26 remove key arg
        let psTuple = OVScene.addShapeSceneData (shapeOSS:shapeOSS, op:op , startPosition:startPosition)
        addShape3DNode (pst:psTuple)
    } //end addShapeToScene
    
    //=====<oogie2D mainVC>====================================================
    // 4/28 peel off from addShapeToScene
    // 9/27 redo uid handling
    func addShape3DNode (pst : (shape:OogieShape,pos3D:SCNVector3))
    {
        let sphereNode = SphereShape() //make new 3d shape, texture it
        let shapeOOS   = pst.shape.OOS
        let uid        = shapeOOS.uid //9/27
        sphereNode.setBitmap(s: shapeOOS.texture)
        sphereNode.uid      = uid //9/27 pass incoming shape UID to 3D objectd
        sphereNode.key      = uid    //9/26
        sphereNode.shapeNode.name = uid  //9/27 pass uid to shape node too!
        sphereNode.position = pst.pos3D //Place 3D object as needed..
        sphereNode.setTextureScaleAndTranslation(xs: Float(shapeOOS.uScale), ys: Float(shapeOOS.vScale), xt: Float(shapeOOS.uCoord), yt: Float(shapeOOS.vCoord))
        sphereNode.name      = shapeOOS.name
        oogieOrigin.addChildNode(sphereNode)  // Add shape node to scene
        shapes3D[uid] = sphereNode     // 9/26 Add shape to 3d dict
    } //end addShape3DNode

    
    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addPipeToScene(ps : PipeStruct , key : String, op : String)
    {
        if let oop = OVScene.addPipeSceneData(ps : ps , name : key, op : op)
        {
            // 1/22 split off 3d portion
             addPipe3DNode(oop : oop , newNode : true) //1/30
        }
    } //end addPipeToScene
    
   
    //=====<oogie2D mainVC>====================================================
    // 9/25 redo for uid NOT name as index to pipe
    func addPipe3DNode (oop:OogiePipe , newNode : Bool)
    {
        let name   = oop.PS.name
        var pipe3D = PipeShape()
        let uid    = oop.uid //9/25 our master key for pipe creation/access
        if (!newNode) //update? pull pipe shape
        {
            if pipes3D[uid] == nil {return} //bail on nil
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
             print("apn [\(uid)] flatlon \(flat),\(flon)  tlatlon \(tlat),\(tlon) nn \(newNode)")
             //  11/29 match pipe color in corners
             pipe3D.pipeColor = pipe3D.getColorForChan(chan: oop.PS.fromChannel)
            let pipeNode = pipe3D.create3DPipe(uid: uid ,  //9/25
                                               flat : flat , flon : flon , sPos00  : sPos00 ,
                                               tlat : tlat , tlon : tlon , sPos01  : sPos01 ,
                                               isShape: isShape, newNode : newNode)
             if (newNode) //1/30
             {
                 pipeNode.name = name
                 pipe3D.addChildNode(pipeNode)     // add pipe to 3d object
                 oogieOrigin.addChildNode(pipe3D)  //1/20 new origin
                 pipes3D[uid] = pipe3D             //9/25  dictionary of 3d objects
             }
        }
     } //end addPipe3DNode

    
    //=====<oogie2D mainVC>====================================================
    func chooseImageForSceneLoad()
    {
        OVScene.setLoopQuiet(flag: true) //9/13/21 quiet loop!
//        OVScene.haltLoop() //5/8 halt playing music!
        let imag = UIImagePickerController()
        imag.delegate = self // as UIImagePickerControllerDelegate & UINavigationControllerDelegate
        imag.sourceType = UIImagePickerController.SourceType.photoLibrary;
        imag.allowsEditing = false
        self.present(imag, animated: true, completion: nil)
    }
    
    //-----<imagePickerDelegate>-------------------------------------
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: false) { }
        OVScene.setLoopQuiet(flag: false) //9/13/21 ok make sounds again...
//        OVScene.startLoop() // 5/11 restart music
    }

    //-----<imagePickerDelegate>-------------------------------------
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated:true, completion: nil)
        if let i = info["UIImagePickerControllerOriginalImage"]
        {
            let tiffie = OogieTiffie()
            if let s = tiffie.read(fromPhotos: i as! UIImage)
            {
                if s.contains("error") //Error?
                {
                    infoAlert(title:"TIFFIE load failed" , message : s)
                    OVScene.setLoopQuiet(flag: false) //9/13/21 ok make sounds again...
//                    OVScene.startLoop() // 5/11 restart music
                }
                else
                {
                    //print("tiffie string [\(s)]")
                    clearScene(withDefaultScene: false) //5/14 clear before load!
                    self.OVScene.OSC = DataManager.load(fromString: s, with: OSCStruct.self)
                    finishSettingUpScene()
                }
            }
        }
    }
    
    
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
                case "update3DShapeByKey": update3DShapeBy(uid:key) //handle shape param change
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
                        if gotPlayed == "1" {marker3D.gotPlayed = true}  //5/15
                    }
                default:break
                }  //end switch
            }     //end count > 1
        } //end for nextString
        updating3D = false
    } //end handle3DUpdates
    
    //=====<oogie2D mainVC>====================================================
    // OBSOLETE? never called???
    @objc func handlePipesMarkersAnd3D()
    {
        
        print("handlePipesMarkersAnd3D STUBBED...")
        // pass in edit type if any and knobmode, sends back notification of 3D changes
       // 8/14/21 TEST  OVScene.playAllPipesMarkers(editing: whatWeBeEditing, knobMode: knobMode)
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
            menu()
        }
        else //editing? cancel! restore old value to field!
        {
            cancelEdit()
        }
    } //end buttonSelect
    

    //=====<oogie2D mainVC>====================================================
    // 10/3 comment out for now, maybe add later??
    func cancelEdit()
    {
        print("cancel edit stubbed out!")
//        pLabel.updateLabelOnly(lStr:"Cancel Edit")
//        //4/26 Dig up last param value and save
//        let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
//                                   named : OVScene.selectedFieldName.lowercased(),
//                                toDouble : OVScene.lastFieldDouble,
//                                toString : OVScene.lastFieldString )
//        update3DSceneForSceneChanges(sceneChanges)
//
//        if OVScene.selectedFieldType == "double"  //update marker as needed...
//        {
//            if whatWeBeEditing == "voice"      {
//                selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
//            }
//            else if whatWeBeEditing == "shape" {
//                update3DShapeBy (uid:OVScene.selectedShapeKey)
//                if let sshape = shapes3D[OVScene.selectedShapeKey] //1/26 also set 3d node spin rate to last value
//                {
//                    //5/7 NEED to set timer speed in OogieShape!!
//                    //5/7 pulledsshape.setTimerSpeed(rs: OVScene.selectedShape.OOS.rotSpeed) //1/14 invalidate/reset timer
//                }
//            } //end else
//            //1/26 missing pipe?
//        }
//        knobMode = "select" //back to select mode
//        //8/11/21 updateWheelAndParamButtons()
//        whatWeBeEditing = "" //9/24 clear edit indicator
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
        let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(knobValue),
                                toString : textField.text! )
        update3DSceneForSceneChanges(sceneChanges) //4/29

        pLabel.isHidden = false //10/10 show param label again
        textField.resignFirstResponder() //dismiss kb if up
        return true
    }

    //------<UITextFieldDelegate>-------------------------
    // 4/26 pull lastFieldString ref
    @IBAction func textChanged(_ sender: Any) {
        let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
                                   named : OVScene.selectedFieldName.lowercased(),
                                toDouble : Double(knobValue),
                                toString : textField.text! )
        update3DSceneForSceneChanges(sceneChanges) //4/29
    }

    //--------<TextureVCDelegate.-------------------------------------
    func cancelled()
    {
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
        }
    }
    
    //---<chooserVCDelegate>--------------------------------------
    func chooserCancelled()
    {
        print("...chooser cancel")
        OVScene.setLoopQuiet(flag:false) //9/13/21 ok make sounds again...
//        OVScene.startLoop() // Start music up again...
    }

    //---<chooserVCDelegate>--------------------------------------
    //Delegate callback from Chooser...
    func chooserChoseFile(name: String)
    {

        if chooserMode == "loadAllPatches"
        {
            //6/29/21 FIX! let ppp = allP.getPatchByName(name: name)
            //6/29/21 FIX! print("ppp \(ppp)")
        }
        else //handle scene?
        {
            OVSceneName  = name
            clearScene(withDefaultScene: false) //5/14 clear before load!
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            self.OVScene.OSC = DataManager.loadScene(OVSceneName, with: OSCStruct.self)
            finishSettingUpScene()
        }
    } //end choseFile
    

    
    //---<chooserVCDelegate>--------------------------------------
    // 11/17 new delegate return w/ filenames from chooser
    func newFolderContents(c: [String])
    {
       // patchNamez = c
       // patchNum = 0

    }
 //
    //---<chooserVCDelegate>--------------------------------------
    //Delegate callback from Chooser...
    func needToSaveFile(name: String) {
        OVSceneName = name
        OVScene.OSC.name = name //5/11 forgot name!
        OVScene.packupSceneAndSave(sname:OVSceneName)
        pLabel.updateLabelOnly(lStr:"Saved " + OVSceneName)
        OVScene.setLoopQuiet(flag:false) //9/13/21 ok make sounds again...
    }

    
    //=====<oogie2D mainVC>====================================================
    // 9/1/21, go for random patch...
    // BUG: doesnt seem to change patch BUT patch then gets stuck and cant load anything else??
    func loadRandomPatch()
    {
        let randV = OogieVoice()
        
        let bbot = 32;   //FIX BUILTIN SAMPEL LIMITS
        let btop = 320;
        print("RANDOM PATCH")
        let type = Int.random(in:0...3); //set up type first...
        randV.OOP.type = type
        switch Int32(type)
        {
        case SAMPLE_VOICE: randV.loadRandomSamplePatch(builtinBase: bbot, builtinMax: btop, //these numbvers are WRONG
                                                      purchasedBase: 0, purchasedMax: 0)
            randV.OVS.name = "Random Sample"
        case SYNTH_VOICE: randV.loadRandomSynthPatch()
            (sfx() as! soundFX).buildEnvelope(0,true); //arg whichvoice?
            randV.OVS.name = "Random Synth"
        case PERCUSSION_VOICE: randV.loadRandomPercPatch(builtinBase: bbot, builtinMax: btop)
            randV.OVS.name = "Random Percussion"
        case PERCKIT_VOICE : randV.loadRandomPercKitPatch(builtinBase: bbot, builtinMax: btop)
            randV.OVS.name = "Random PercKit"
        default:break
        }  //end switch
        //Clear effects...
        randV.OVS.portamento = 0;
        randV.OVS.vibSpeed   = 0;
        randV.OVS.vibLevel   = 0;
        randV.OVS.vibeSpeed  = 0;
        randV.OVS.vibeLevel  = 0;
        
        randV.OOP.pLevel     = 50;
        randV.OOP.pKeyOffset = 50;
        randV.OOP.pKeyDetune = 50;
        
        if type != PERCKIT_VOICE
        {
            let octaves          = Int.random(in:1...9)
            randV.OVS.bottomMidi = Int.random(in:20...90)
            randV.OVS.topMidi    = min(120,randV.OVS.bottomMidi + (8*octaves))
            //NSLog(@" b/t %d %d",workVoice.bottomMidi,workVoice.topMidi);
        }
        randV.OVS.noteMode   = Int.random(in:0...10)
        randV.OVS.volMode    = Int.random(in:0...10)
        //??randV.OVS.pan        = Int.random(in:0...12) //Is this right?

        randV.OVS.thresh = 2; //default threshold
        randV.OVS.midiDevice  = 0;
        randV.OVS.midiChannel = 0;
        self.OVScene.selectedVoice = randV
    } //end loadRandomPatch
    
    //=====<oogie2D mainVC>====================================================
    func loadPatchByName (pName:String)
    {
        if let oop = allP.patchesDict[pName]
        {
            print("loadPatchByName: \(oop)")
            self.OVScene.selectedVoice.OOP = oop
            let editDict = (paramEdits() as! edits).getForPatch(pName) //10/1 apply any edits
            OVScene.selectedVoice.applyEditsWith(dict: editDict) //modify voices patch to suit edits
            let nn = allP.getSampleNumberByName(ss: oop.name)
            self.OVScene.selectedVoice.OVS.whichSamp = nn.intValue //10/1
            if self.OVScene.selectedVoice.OOP.type == PERCKIT_VOICE
            {
                self.OVScene.selectedVoice.getPercLooxBufferPointerSet() //go get buff ptrs...
            }
            print("load patch \(pName),  buf \(nn)")
        }
    } //end loadPatchByName
    
    //=====<controlPanelDelegate>====================================================
     //controlPanel delegate returns...  9/28 BUG: pvalue for patch param is wrong, points to prev item from selection
    //                                               ALSO pvalue is discarded, why pass it anyway???
     func didSetControlValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         print("mainvc: didSetControlValue \(which) \(newVal) \(pname)")
         
         if pname == "patch" //new patch? 10/3 change toi string
         {
             if newVal == 0 //RANDOM
             {
                 loadRandomPatch()
             }
             else
             {
                 // 10/3 NO NEED? let patchName = allP.getSoundPackPatchNameByIndex(index: Int(newVal-1)) //patches start 1....n
                 print("load patch \(pvalue)")
                 loadPatchByName(pName: pvalue) //10/3
                 OVScene.selectedVoice.OVS.patchName = pvalue  //9/30 wups forgot to save...
             } //end else not random
         } //end which 17
         if pname == "soundpack" //9/11 handle new soundpack
         {
             OVSoundPack = allP.getSoundPackNameByIndex(index: Int(newVal));
             allP.getSoundPackByName(name: OVSoundPack)
             let patchName = allP.getSoundPackPatchNameByIndex(index: 0) //patches start 1....n
             print("choose sp \(OVSoundPack) patch \(patchName)  ... NEED to update patchPicker!!!")
             loadPatchByName(pName: patchName)
             var pnames = [String]()
             pnames.append("Random")
             let psize = allP.getSoundPackSize()
             if psize > 0
             {
                 for i in 0...psize-1
                 {
                     let pname = allP.getSoundPackPatchNameByIndex(index: i)
                     pnames.append(pname)
                 }
             }
             cPanel.paNames = pnames
             //Pack params, send to VC
             cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
             cPanel.configureView()
         }
         else   //Just regular control...
         {
             editParam(which,newVal,pname,pvalue,undoable)
             OVScene.sceneVoices[OVScene.selectedMarkerKey] = OVScene.selectedVoice //WOW STORE IN SCENE?
         } //end else
         
     } //end didSetControlValue


    //=====<patchPanelDelegate>====================================================
    // this needs to loop over all voices with current patch and perform edit
    func didSetPatchValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        print("mainvc: didSetPatchValue \(which) \(newVal) \(pname) \(pvalue)")
        // for now just edit selected voice..
        editParam(which,newVal,pname,pvalue,undoable)
        OVScene.sceneVoices[OVScene.selectedMarkerKey] = OVScene.selectedVoice //WOW STORE IN SCENE?
    }

     
     //=====<shapePanelDelegate>====================================================
     // 9/15 redid to handle  OVScene.loadCurrentShapeParams
     func didSetShapeValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         print("mainvc: didSetShapeValue \(which) \(newVal) \(pname) \(pvalue)")
         if which == 0 //texture?
         {
             //call a delegate return here...
             if pname == "default"
             {
                 let ii = UIImage(named: "spectrumOLD")!   //This really should be defined everywhere!
                 gotTexture(name: pname, tex: ii)
             }
             else if let ii = tc.texDict[pname] //try for texture
             {
                 gotTexture(name: pname, tex: ii)
             }
         }
         else{ //normal param??
             editParam(which,newVal,pname,pvalue,undoable)
         }
     } //end didSetShapeValue

    //=====<shapePanelDelegate>====================================================
    // 9/18/21
    func didSelectShapeDice() {
        //print("didSelectShapeDice")
        pLabel.updateLabelOnly(lStr:"Randomize Shape") //9/18 info for user!
    }
    func didSelectShapeReset() {
        //print("didSelectShapeReset")
        pLabel.updateLabelOnly(lStr:"Reset Shape") //9/18 info for user!
    }
    func didSelectShapeDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectShapeDismiss")
        deselectAndCloseEditPanel()
    }

    
    //=====<pipePanelDelegate>====================================================
    // 9/15 redid to handle  OVScene.loadCurrentShapeParams
    func didSetPipeValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        print("mainvc: didSetPipeValue \(which) \(newVal) \(pname) \(pvalue)")
        editParam(which,newVal,pname,pvalue,undoable)
    }
    // 9/18/21
    func didSelectPipeDice() {
        //print("didSelectPipeDice")
        pLabel.updateLabelOnly(lStr:"Randomize Shape") //9/18 info for user!
    }
    func didSelectPipeReset() {
        //print("didSelectPipeReset")
        pLabel.updateLabelOnly(lStr:"Reset Shape") //9/18 info for user!
    }
    func didSelectPipeDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectPipeDismiss")
        deselectAndCloseEditPanel()
    }

    //=====<oogie2D mainVC>====================================================
    // 9/24 deselects 3D shape and closes open panel; relies on whatWeBeEditing!
    func deselectAndCloseEditPanel ()
    {
        if whatWeBeEditing == "shape"
        {
            selectedSphere.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: shapeEditPanels)  //9/24  put away voice editor
        }
        else if whatWeBeEditing == "pipe"
        {
            selectedPipeShape.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: pipeEditPanels)  //9/24  put away voice editor
        }
        else if whatWeBeEditing == "voice" || whatWeBeEditing == "patch"  //10/3
        {
            selectedMarker.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: voiceEditPanels)  //9/24  put away voice editor
        }
        //OBSOLETE   ??? cancelEdit()  // clears edit state from scene
        whatWeBeEditing = "" //10/3
    } //end deselectAndCloseEditPanel

    //=====<oogie2D mainVC>====================================================
    // 9/11 Makes voice edit controls visible
    func shiftPanelUp(panel:UIView)
    {
        var rr   = panel.frame;
        let hite = rr.size.height
        if rr.origin.y == viewHit //already DOWN?
        {
            rr.origin.y = viewHit - hite
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                panel.frame = rr
            }, completion: { (finished: Bool) in
                //print("shifted panel UP")
            })
        }
    } //end shiftvoiceEditPanelsUp

    //=====<oogie2D mainVC>====================================================
    // 9/11 Makes voice edit controls hidden
    func shiftPanelDown(panel:UIView)
    {
        var rr   = panel.frame;
        let hite = rr.size.height
        if rr.origin.y == viewHit - hite //already UP?
        {
            rr.origin.y = viewHit
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [], animations: {
                panel.frame = rr
            }, completion: { (finished: Bool) in
                //print("shifted panel DOWN")
            })
        }
    } //end shiftPanelDown
    
    //=====<oogie2D mainVC>====================================================
    func shiftPanelLeft(panel:UIView)
    {
        var rr = panel.frame;
        if rr.origin.x == 0  //not shifted?
        {
            rr.origin.x = rr.origin.x - viewWid
            UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                panel.frame = rr
            }, completion: { (finished: Bool) in
                //print("shifted L")
            })
        }
    } //end shiftPanelLeft

    //=====<oogie2D mainVC>====================================================
    func shiftPanelRight(panel:UIView)
    {
        var rr = panel.frame;
        if rr.origin.x < 0  // L shifted?
        {
            rr.origin.x = rr.origin.x + viewWid
            UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                panel.frame = rr
            }, completion: { (finished: Bool) in
                //print("shifted R")
            })
        }
    } //end shiftPanelRight


    //=====<oogie2D mainVC>====================================================
    // Subpanel Right Button, slide voiceEditPanels LEFT
    func didSelectRight() {
        shiftPanelLeft(panel:voiceEditPanels)
        if whatWeBeEditing == "voice" { whatWeBeEditing = "patch" } //9/30 switch editing object...
        print("right")
    }

    //=====<oogie2D mainVC>====================================================
    // Subpanel Left Button, slide voiceEditPanels RIGHT
    func didSelectLeft() {
        shiftPanelRight(panel:voiceEditPanels)
        if whatWeBeEditing == "patch" { whatWeBeEditing = "voice" }  //9/30 switch editing object...
        print("left")
    }

    //=====<controlPanelDelegate>====================================================
    func controlNeedsProMode() {
        print("controlNeedsProMode")
    }
    func didSelectControlDice() {
        //print("didSelectControlDice")
        pLabel.updateLabelOnly(lStr:"Randomize Voice") //9/18 info for user!
    }
    func didSelectControlReset() {
        //print("didSelectControlReset")
        pLabel.updateLabelOnly(lStr:"Reset Voice") //9/18 info for user!
    }
    func updateControlModeInfo(_ infostr: String!) {
        pLabel.updateLabelOnly(lStr: infostr)
    }
    func didSelectControlDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectDismissReset")
        deselectAndCloseEditPanel()
    }

    //=====patchPanelDelegate>====================================================
    // 10/1 
    func didSelectPatchDice() {
        //print("didSelectPatchDice")
        pLabel.updateLabelOnly(lStr:"Randomize Patch") //9/18 info for user!
    }
    func didSelectPatchReset() {
        //print("didSelectPatchReset")
        pLabel.updateLabelOnly(lStr:"Reset Patch") //9/18 info for user!
        loadPatchByName (pName:OVScene.selectedVoice.OVS.patchName)
//        paPanel.patchName = OVScene.selectedVoice.OVS.patchName  //10/3
        paPanel.configureView()
    }
    func didSelectPatchDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectPatchReset")
        deselectAndCloseEditPanel() //same as control dismiss, hide panel
    }

} //end vc class, line 1413 as of 10/10

