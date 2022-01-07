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
//   Build Settings: Swift Compiler - Custom Flags
//      fields for Debug / Release, set flags here for #if / #else / #endif
//  11/1   shorten rand patch naming
//  11/3   add handleDice and set NewScalarValue, randomize scalars now
//  11/5   remove updateActivity call in handle3DUpdates
//  11/7   cross integrate with oogireAR w/ FireStore bindings (not used herein!)
//  11/8   add saveit to packupSceneAndSave, add toCloud to needToSaveFile
//  11/9   move all 3D shape dicts to oogieScene
//           also all add/delete 3Dnodes, updateAllMarkersAndSpinShapes
//  11/10  add dice to marker, and voice randomizer to handleDice
//  11/11  add dice to shape, and shape randomizer to handleDice
//  11/16  redo touch begin/end, add drag distance, add call to setBitmap in setNewTexture
//  11/21  add settingsVC / delegate support
//  11/22  change oadPatchByName, pull scene save from loadRandomPatch
//  11/25  add edit flags to handleDice, cleanup too
//  11/28  add wrapST tex support in handleDice
//  11/29  pull all refs to cancelEdit, add setupShapePanelWithFreshParams
//  11/30  add canned presets / quick scene loads
//  12/3   add try/catch around all datamanager loads
//  12/5   add random synth/etc to carpetbomb, also lastselectedvoice
//  12/6   pull imagePicker stuff, photos
//  12/7   add noVoices to clearScene, make all alerts black tint
//  12/9   fix bug in setupShapePanelWithFreshParams
//  12/10  remove add  scalar from main menu,
//            add s arg and use voice/shape name in delete prompts
//  12/11  disable allowsCameraControl when touching scalar, to make it easy to drag up/down knob
//  12/12  add factoryReset
//  12/13  add scalarTrackLocation,handleScalarTouchesMoved
//  12/14  add updatescalarname, redo scalar update args
//  12/15  pull which arg from edit Param , did SetControlValue..., updateScalarBy..., set NewScalarValue
//  12/17  use scalar.SS.value now, add update3DSceneForSceneChanges
//  12/19  comment out black tint for all uialerts, use default for now, works w/ darkmode
//             fix display bug in handleScalarTouchesMoved
//  12/21  remove patchPanel, use patchVC  , remove shiftPanelLeft/Right
//  12/24  replace all issShape bools with objjType strings
//  12/29  implement deleteAllShapeVoices, add prompt flags for all deletes, object arg to delete scalar/pipe
//  1/1    in loadPatchByName, add detune for userSamples patches
//  1/2    redo param in/max in editParam
import UIKit
import SceneKit

//Scene unpacked params live here for now...
var OVtempo = 135 //Move to params ASAP
var camXform = SCNMatrix4()

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,chooserDelegate,UIGestureRecognizerDelegate,
                      SCNSceneRendererDelegate,settingsVCDelegate,samplesVCDelegate,
                      controlPanelDelegate,scalarPanelDelegate,
                      shapePanelDelegate,pipePanelDelegate, patchVCDelegate
{

    @IBOutlet weak var skView: SCNView!
    @IBOutlet weak var editButtonView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var recButton: UIButton!
    
    @IBOutlet weak var testButton: UIButton!
    @IBOutlet weak var test2Button: UIButton!
    @IBOutlet weak var voiceEditPanels: UIView!
    @IBOutlet weak var shapeEditPanels: UIView!
    @IBOutlet weak var pipeEditPanels: UIView!
    @IBOutlet weak var scalarEditPanels: UIView!
    @IBOutlet weak var presetsView: UIStackView!
    
    //12/2 need handle to app delegate
    let appDelegate    = UIApplication.shared.delegate as! AppDelegate

    var colorTimer = Timer()
    var pLabel = infoText()
    //10/29 version info (mostly for debugging)
    var version = ""
    var build   = ""
    var touchLocation = CGPoint()
    var scalarTrackLocation = CGPoint() //12/13
    var touchNodeUID = ""  //11/18 track what was touched...
    var touchDragDistance = 0 //11/16
    var startTouch    = UITouch()
    var latestTouch   = UITouch()
    var chooserMode = ""
    var shouldNOTUpdateMarkers = false
    var oldvpname = ""; //for control value changes
    var showStatistics = false

    var sceneError = false //12/3 for checking initial scene loads

    //12/2 haptics for wheel controls
    var fbgenerator = UISelectionFeedbackGenerator()
    var cPanel  = controlPanel()

    var sPanel  = shapePanel()
    var scPanel = scalarPanel()
    var piPanel = pipePanel()
    
    var sVC   = samplesVC()
    var setVC = settingsVC()
    var pVC   = patchVC()
    var workPatch = OogiePatch() //12/20 for patchVC editor
    var patchToEdit = ""         //12/30 used to select patch to edit
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
    var OScP =  OogieScalarParams.sharedInstance  //10/13 new scalar type

    //12/23 clumsy but needed
    var workScalarUID = ""
    
    //10/27 for finding new marker lat/lons
    let llToler = Double.pi / 10.0
    let llStep  = Double.pi / 8.0 //must be larger than toler
    
    var whatWeBeEditing = "" //voice, shape, pipe, etc...

    var recording = false
    
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
    var hitPoint3D    = SCNVector3(x: 0, y: 0, z:0) //12/11
    // 3D objects
    var cameraNode        = SCNNode()
    let scene             = SCNScene()
    var selectedMarker    = Marker(newuid:"empty")
    var selectedSphere    = SphereShape(newuid:"empty")
    var selectedPipeShape = PipeShape()
    var selectedScalarShape   = ScalarShape()  //10/15

    var oogieOrigin = SCNNode() //3D origin, all objects added to this parent
    var pkeys = PianoKeys()    //3D keys for playing test samples
//    var toobbShape = tooobShape()

    var isLooping = false  //11/2 dj loop
    
    // Overall scene, performs bulk of data workload
    var OVScene           = OogieScene()
    var OVSceneName       = "default"
    var OVSoundPack       = "Synth/Perc" //9/16 keep track of selected soundpack
    var isPlaying         = false
    var updating3D        = false
    var screenCaptureFlag = false // Used by TIFFIE
    var needTiffie        = false // Used by TIFFIE
    
    //10/7  for selectObjectMenu
    let imageS = UIImage(named: "shapeIcon.jpg")
    let imageP = UIImage(named: "pipeIcon.jpg")
    let imageV = UIImage(named: "voiceIcon.jpg")
    let imageL = UIImage(named: "leverIcon")

   //=====<oogie2D mainVC>====================================================
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //12/19 tried this to make menus work in dark mode. DIDNT WORK.
        //  menus are still black text in dark mode, they should be white or some other bright color
//        if #available(iOS 13.0, *)
//        {
//            overrideUserInterfaceStyle = .light
//        }
        
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
       // sceneView.showsStatistics = true
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
        camXform.m43 = 1.0   // 10/26 all units in meters for AR

        var needCannedScene = true
        if DataManager.sceneExists(fileName : "default")
        {
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            do{  //12/3 add try/catch to all datamanager loads
                self.OVScene.OSC = try DataManager.loadScene("default", with: OSCStruct.self)
                self.OVScene.OSC.unpackParams()       //DHS 11/22 unpack scene params
                self.OVScene.OSC.name = OVSceneName //DHS 5/10 wups
                #if VERSION_2D
                setCamXYZ() //11/24 get any 3D scene cam position...
                #endif
                print("...load default scene")
                needCannedScene = false
            }
            catch{
                sceneError = true  //12/3 for later reporting
            }
        }
        if needCannedScene  //12/3 cant find default?
        {
            self.OVScene.createDefaultScene(named: "default" , noVoices:false) //12/7
            self.OVScene.OSC.setDefaultParams()
            print("...no default scene found, create!")
        }

        //Place bottom buttons / knobs automagically...
        let csz = UIScreen.main.bounds.size;
        viewWid = csz.width   //10/27 enforce portrait aspect ratio!
        viewHit = csz.height
        if (viewWid > viewHit) //wups? started in landscape, fixit!
        {
            viewHit = csz.width
            viewWid = csz.height
        }
        
        //11/30 test button top left, will add preset buttons later here
//        testButton.frame = CGRect(x: 0, y: 100, width: 60, height: 40)
        testButton.isHidden = true
        test2Button.isHidden = true
        
        //11/30 add presets
        let ff = presetsView.frame
        presetsView.frame = CGRect(x: 50, y: 300, width: ff.size.width, height: ff.size.height)
        presetsView.isHidden = true
        let pwh    : CGFloat   = 50 //12/24 enlarge
        let inset2 : CGFloat = 100 //11/13 move a bit up
        var pRect = CGRect(x: viewWid - inset2 , y: viewHit - inset2, width: pwh, height: pwh)
        //make edit button round
        editButtonView.frame = pRect
        editButtonView.layer.cornerRadius = pwh*0.5  //11/13
        editButtonView.isHidden = true
        
        let xyinset : CGFloat = 20
        pRect = CGRect(x: viewWid - pwh - xyinset , y: viewHit - pwh - xyinset, width: pwh, height: pwh) //11/11 put menu on RH bottom
        menuButton.frame = pRect
        menuButton.backgroundColor = .yellow

        resetButton.isHidden = true  //no reset for now

        //8/11/21 voiceEditPanels view... double wide
        let allphit = 320
        // 9/11 voiceEditPanels start off bottom of screen
        voiceEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(2*viewWid), height: allphit)
        //Live controls / patch or colorpack select
        //10/1 REDO: just set view rect here, then add to view hierarchy
        cPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        voiceEditPanels.backgroundColor = .clear
        voiceEditPanels.addSubview(cPanel)
        cPanel.delegate = self
        
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

        // 9/14 pipe editing panel(s)
        pipeEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(viewWid), height: allphit)
        //10/1 REDO: just set view rect here, then add to view hierarchy
        piPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        pipeEditPanels.backgroundColor = .clear
        pipeEditPanels.addSubview(piPanel)
        piPanel.delegate = self

        //10/15 TEMP, get scalar panel offscreen
        scPanel.setupView(CGRect(x: 0 , y: 0, width: Int(viewWid), height: allphit))
        scalarEditPanels.backgroundColor = .clear
        scalarEditPanels.addSubview(scPanel)
        scPanel.delegate = self
        scalarEditPanels.frame = CGRect(x: 0 , y: Int(viewHit) , width: Int(2*viewWid), height: allphit)
        //1/3 shrink infolabel
        pLabel = infoText(frame: CGRect(x: 0,y: 32,width: viewWid,height: 40))
        pLabel.frame = CGRect(x: 0 , y: 32, width: 375, height: 80)
        self.view.addSubview(pLabel)
        pLabel.infoView.alpha = 0 //Hide label initially

        //11/29 moved recbutton yet again!  works w/ slot?
        pRect = CGRect(x: viewWid - pwh - xyinset  , y: 24, width: pwh, height: pwh) //11/13 rec button
        recButton.frame = pRect
        recButton.layer.cornerRadius = pwh*0.5  //11/13
        recButton.isHidden = false
        self.view.bringSubview(toFront: recButton); //pop rec button up on top of status label


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
        //11/19  Update markers in foreground on a timer
        var colorTimerPeriod = 0.1 //5/14 default on settings bundle fail
        if let ctp = appSettings["colorTimerPeriod"] as? Double //5/14 get time from settings bundle
        {
            colorTimerPeriod = ctp
        }
        print("...start colorTimer, period \(colorTimerPeriod)")
        colorTimer = Timer.scheduledTimer(timeInterval: colorTimerPeriod, target: self, selector: #selector(self.updateAllMarkers), userInfo:  nil, repeats: true)
        _ = DataManager.getSceneVersion(fname:"default")
        //Try running color player in bkgd...
        OVScene.startLoop()
        loadSynthBuffersWithCannedWaves() //10/12 one-time synth wave load

    } //end viewDidLoad
    
    
    //====(OOGIECAM MainVC)============================================
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserSamplesAndPatches()  //10/24 load any user sample changes
    }

    //====(OOGIECAM MainVC)============================================
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if sceneError //12/3 only happens if default is missing at startup time!
        {
            infoAlert(title:"Default Scene Error" ,
                      message: "default scene file not found or in wrong format, creating empty scene instead" )
            sceneError = false
        }
    }
    

    
    //====(OOGIECAM MainVC)============================================
    // 7/13 called at start AND when sample files are changed!
    // 10/18 update for userSampleBase
//    -(void) loadUsermadeSamples
//    {
//        //NSLog(@"loadUsermadeSamples");
//        // look in user samples folder, get bufLookups 256 and up 10/29 redo
//        NSArray<NSString *> *userSampleFnames = [_sfx loadSamplesNow:
//                                                 @"UserSamples" : userSampleBase];
//        sampnum = userSampleBase; //start at user sample area...
//        for (NSString *s in userSampleFnames) //setup buffer lookups for
//            if (![s containsString : @"#"]) //1/31 NO deleted files please!
//            {
//                NSNumber *n = [NSNumber numberWithInt:sampnum];
//                //NSLog(@" usersample %@ ---> %d",s,n.intValue);
//                [allp linkBufferToPatchWithNn:n ss:s];
//                sampnum++;
//            }
//        userSampleTop = sampnum; //topmost sample!
//    } //end loadUsermadeSamples

    
    //=====<oogie2D mainVC>====================================================
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask(rawValue: UIInterfaceOrientationMask.portrait.rawValue | UIInterfaceOrientationMask.portraitUpsideDown.rawValue)
    }

    //=====<oogie2D mainVC>====================================================
    func startPlayingMusic()
    {
        isPlaying = true
        OVScene.setLoopQuiet(flag: false) //10/24 quiet loop!
    }
    //=====<oogie2D mainVC>====================================================
    func stopPlayingMusic()
    {
        isPlaying = false   //NO Sounds!
        OVScene.setLoopQuiet(flag: true) //10/24 quiet loop!
    }
    
    //=====<oogie2D mainVC>====================================================
    func startPlayingLoop(loopName:String)
    {
        let nn = allP.patLookups[loopName] //NSNumber
        //Looping? Reset and start loop again!
        if isLooping  {(sfx() as! soundFX).releaseAllLoopedNotes()};
            //NSLog(@" start loop");
            //NOTE these need to be tunable if we want different BPM! but how??
            // for now set to middle C, with no detune / offset / level diff
            // We need as generic a sample setting as possible:
            //   maybe make these calls into a builtin synth method?
        (sfx() as! soundFX).setSynthPLevel(50)
        (sfx() as! soundFX).setSynthPKeyOffset(50)
        (sfx() as! soundFX).setSynthPKeyDetune(50)
        (sfx() as! soundFX).setSynthPoly(0)
        (sfx() as! soundFX).setSynthAttack(0)
        (sfx() as! soundFX).setSynthDecay(0)
        (sfx() as! soundFX).setSynthSustain(0)
        (sfx() as! soundFX).setSynthSustainL(0)
        (sfx() as! soundFX).setSynthRelease(0)
        (sfx() as! soundFX).setSynthPortamento(0)
        (sfx() as! soundFX).setSynthVibAmpl(0)
        (sfx() as! soundFX).setSynthVibeAmpl(0)
        (sfx() as! soundFX).setSynthSampOffset(0)
        (sfx() as! soundFX).setSynthMono(0)
        (sfx() as! soundFX).setSynthDetune(1)
        (sfx() as! soundFX).setSynthGain(240) //NEED CONTROL HOOKUP
        (sfx() as! soundFX).setSynthInfinite(1)
        if let bnum = nn?.intValue
        {
            print("loop \(loopName) buf \(bnum)")
            let loopBuffer = Int32(bnum)
            //{
                //tried middle C (60) but it was slower than input sample played native
                (sfx() as! soundFX).playNote(64,  loopBuffer ,  SAMPLE_VOICE)
                isLooping  = true;

            //}

        }
//            djPerf.loopBuffer = loopBuffer;
//            //for tweaking the sample while it is playing...
//            djPerf.lastToneHandle = [_sfx getSynthLastToneHandle];
//            //6/26 for updating loop progress
//            loopProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
//                                    selector:@selector(loopProgressTick:) userInfo:nil repeats:YES];
//
        

    } //end startPlayingLoop
    

    //=====<oogie2D mainVC>====================================================
    func sendSoundPackAndSampleNamesToControls()
    {
        //CAN this be done earlier???
        print("...samples loaded, hopefully we can set up soundpack/patch stuff...")
        cPanel.spNames = allP.allSoundPackNames

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
    // 10/16 we can only create voices AFTER samples load!
    @objc func samplesLoaded(notification: NSNotification)
    {
        //DHS 11/22 all patches needs to do a final sweep...
       //6/29/21 FIX! allP.getAllPatchInfo() //11/22 Get sample rates, key offsets, etc.
        //6/29/21 FIX! allP.loadGMOffsets()  //11/22
        //DHS 10/16 create our scene?
        create3DScene(scene: scene)

        sendSoundPackAndSampleNamesToControls() //10/23
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
    // change this so longpress only halts notes over background!
    //MARK: - UILongPressGestureRecognizer Action -
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer)
    {
        //print("Longperss")
        var haltVoices = false
        if gestureReconizer.state != UIGestureRecognizer.State.ended {
            let pp = gestureReconizer.location(ofTouch: 0, in: self.view)
//why doesnt this work? cant detect if longpress was over an obnect or not
//            hitPoint3D = getHitPointOnObject( for:pp, in :skView)
//            print("lp pp :\(pp)")
//           if  let nodeHitTest = skView.hitTest(startTouch.location(in: skView) , options: nil).first
//           {
//               print("lp hit \(nodeHitTest)")
//
//           }

            // 11/3 make sure longpress is near original touch spot!
            if ((abs(pp.x - touchLocation.x) < 40) &&
                (abs(pp.y - touchLocation.y) < 40))
            {
                if whatWeBeEditing == "voice"        { voiceMenu(v:self.OVScene.selectedVoice)  }
                else if whatWeBeEditing == "shape"   { shapeMenu(s:self.OVScene.selectedShape)  }
                else if whatWeBeEditing == "pipe"    { pipeMenu()   }
                else if whatWeBeEditing == "scalar"  { scalarMenu() } //10/21
                else  {haltVoices = true}  //10/28 halt voices ?
            }
        }
        else {
            haltVoices = true  //10/28
        }
        if haltVoices //10/28
        {
            (sfx() as! soundFX).releaseAllNotes()
            pLabel.updateLabelOnly(lStr: "Release all Notes")
        }
    } //end handleLongPress
    
    //=====<oogie2D mainVC>====================================================
    // 11/15? record / save current audio
    let MAX_RECORDING_TIME = 60  //limits memory use
    @IBAction func recSelect(_ sender: Any)
    {
        //print(" recordit")
        
        if !recording
        {
            pLabel.updateLabelOnly(lStr: "Recording...")
            (sfx() as! soundFX).startRecording(Int32(MAX_RECORDING_TIME))
            recButton.setTitle("X", for: .normal) // 11/21 shrink label, use x instead of stop
            recording = true
        }
        else
        {
           // NSString *txt = [NSString stringWithFormat:@"saved %@.",[_sfx getAudioOutputFileName]];
            (sfx() as! soundFX).stopRecording(0) //stop no cancel
            recButton.setTitle("Rec", for: .normal)
            let ofname = "saved:" + (sfx() as! soundFX).getAudioOutputFileName()
            pLabel.updateLabelOnly(lStr: ofname)
            recording = false
        }
    } //end recSelect
    
    
    //=====<oogie2D mainVC>====================================================
    // 9/13 reset parameter to default, called by multiple panels
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
    // input is a list of strings, go through it and
    //   perform 3d scene updates as needed
    // called after voice/shape/pipe params get changed
    func update3DSceneForSceneChanges(_ sceneChanges:[String])
    {
        for r in sceneChanges //loop over array of update indicators
        {
            print("sceneChange :" + r)
            switch r
            {
            case "movemarker": // Marker moved?
                selectedMarker.updateLatLon(llat: OVScene.selectedVoice.OVS.yCoord, llon: OVScene.selectedVoice.OVS.xCoord)
            case "updatevoicetype": // New Voice type?
                selectedMarker.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))
            case "updatevoicename":  // Voice name changed?
                selectedMarker.updatePanels(nameStr: OVScene.selectedVoice.OVS.name)
            case "updatevoicepipe":  // Pipe moved?
                OVScene.updatePipeByVoice(v:OVScene.selectedVoice)
            case "updatevoicescalar":  // voice moved with scalar?
                OVScene.updateScalarBy(voice:OVScene.selectedVoice)
            case "updatescalarmarker":  //12/23 scalar marker moved?
                //NOTE THIS does NOT work with scalar touch events, there is NO selected scalar! WTF?
                if OVScene.sceneScalars[workScalarUID] != nil
                {
                    let muid = OVScene.sceneScalars[workScalarUID]!.SS.toObject //should be target marker UID
                    if OVScene.markers3D[muid] != nil && OVScene.sceneVoices[muid] != nil
                    {
                        let lat = OVScene.sceneVoices[muid]!.OVS.yCoord
                        let lon = OVScene.sceneVoices[muid]!.OVS.xCoord
                        OVScene.markers3D[muid]!.updateLatLon(llat: lat, llon: lon)
                    }
                    OVScene.updateScalarBy(uid: workScalarUID)
                }
            case "updatescalarname":  //12/14 Scalar name changed?
                selectedScalarShape.updatePedestalLabel(with: OVScene.selectedScalar.SS.name) //12/14
            case "updatescalarxyz":  //12/21 Scalar moved?
                OVScene.updateScalarBy(uid: OVScene.selectedScalar.uid)
            case "updateshape":  // Shape changed/moved?
                OVScene.update3DShapeBy(uid:OVScene.selectedShapeKey)
            case "updateshapename":  // Shape name/comment changed?
                selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                               comm: OVScene.selectedShape.OOS.comment)
            case "updaterotationtype":  // Change rotation type?
                setRotationTypeForSelectedShape()
            case "updateshapepipe":  // shape with Pipe moved?
                OVScene.updatePipeByShape(s:OVScene.selectedShape)
            case "updateshapescalar":  // shape with Pipe moved?
                OVScene.updateScalarBy(shape:OVScene.selectedShape)
            case "updatepipe":  // Pipe label / etc needs changing?
                if let pipe3D = OVScene.pipes3D[OVScene.selectedPipeKey] //12/5 USE SCENE-LOADED NAME!
                {
                    //sprint("update pipe info???  \(OVScene.selectedPipe.ibuffer)")
                    //12/5 update pipe label and graphfff
                    pipe3D.updateInfo(nameStr: OVScene.selectedPipe.PS.name,
                                      pinfo: OVScene.selectedPipe.getPipeInfo())
                    pipe3D.pipeColor = pipe3D.getColorForChan(chan: OVScene.selectedPipe.PS.fromChannel)
                }
            default: break
            }
        }
    } //end update3DSceneForSceneChanges

 
    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if appDelegate.haltAudio == 1 {stopPlayingMusic()} //12/2 add haltAudio
        if segue.identifier == "textureSegue" {
            if let nextViewController = segue.destination as? TextureVC {
                nextViewController.delegate = self
            }
        }
        // 11/4 add  scene chooser
        else if segue.identifier == "chooserLoadSegue"  || segue.identifier == "chooserSaveSegue"
        {
            // 9/28 note if we dont get fresh copy of chooser, the mode doesnt stick!!
            chooser = segue.destination as! chooserVC  //9/28 declare chooser at init
            chooser.delegate = self
            chooser.mode     = chooserMode
        }
        else if segue.identifier == "samplesVCSegue"
        {
            sVC = segue.destination as! samplesVC  //11/25 get fresh handle
            sVC.delegate = self //11/26
            sVC.initAllVars() //11/25 make sure we initialize!
            sVC.patLookups = allP.patLookups //11/25 pass patch lookups down...
        }
        else if segue.identifier == "settingsVCSegue"
        {
            setVC = segue.destination as! settingsVC  //9/28 declare chooser at init
            setVC.showStatistics = showStatistics
            setVC.verbose        = appDelegate.verbose  //12/9
            setVC.delegate       = self
        }
        else if segue.identifier == "patchVCSegue"
        {
            pVC = segue.destination as! patchVC  //9/28 declare chooser at init
            pVC.delegate    = self
        }
    } //end prepareForSegue

    //=====<oogie2D mainVC>====================================================
    override func unwind(for unwindSegue: UIStoryboardSegue, towardsViewController subsequentVC: UIViewController) {
        print("unwind from segue")
    }

    //=====<oogie2D mainVC>====================================================
    override func canPerformUnwindSegueAction(_ action: Selector, from fromViewController: UIViewController, sender: Any?) -> Bool {
        print("can? unwind from segue")
        return false
    }
    
    //=====<oogie2D mainVC>====================================================
    // Tries to set camera nearest to scene as possible along Zaxis
    func resetCamera()
    {
        let crTuple = OVScene.getSceneCentroidAndRadius()
        camXform = SCNMatrix4Identity //11/24 add camera matrix from scene file
        let centroid = crTuple.c
        let radius   = max(3,crTuple.r)
        camXform.m41 = centroid.x  //set X coord
        camXform.m42 = centroid.y  //set X coord
        print("reset cam \(centroid) : \(radius)")
        camXform.m43 = centroid.z + radius   //10/26 used to be 2*radius
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
    // 11/13 add uid arg, generalize for any shape
    func setNewTexture(uid :String ,name: String, tex: UIImage)
    {
        OVScene.savingEdits = true //11/19 prevent data collision
        if OVScene.shapes3D[uid] != nil //11/19 cleanup
        {
            OVScene.shapes3D[uid]!.setBitmapImage(i: tex) //set 3d shape texture
            OVScene.shapes3D[uid]!.name           = name // save texture name
            OVScene.shapes3D[uid]!.setBitmap(s: name) //11/16 DO WE NEED THIS AT ALL?
            if OVScene.sceneShapes[uid] != nil
            {
                OVScene.sceneShapes[uid]!.setBitmap(s: name) //11/16/21
                OVScene.sceneShapes[uid]!.OOS.texture = name
                if uid == OVScene.selectedShapeKey  //update selected shape as needed
                {
                    OVScene.selectedShape.OOS.texture = name
                }
            }
        }
        OVScene.savingEdits = false  //11/19
    } //end setNewTexture
    

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
        for (_,voice) in OVScene.sceneVoices
        {
            voice.masterPitch = appDelegate.masterPitch
        }
    } //end setMasterPitchShiftForAllVoices
    
    //=====<oogie2D mainVC>====================================================
    // 1/2 this method looks LATE. slider display values seem to show the LAST param edited, for shapes at least. WTF?
     // called when patch,pipe,scalar,shape or voice are changed.
     func editParam( _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         var displayVal = Double(newVal) //10/2 need to convert in some cases..
         var ptype = ""
         if      whatWeBeEditing == "voice"  {ptype = OVP.getParamType(pname: pname)}
         else if whatWeBeEditing == "scalar" {ptype = OScP.getParamType(pname: pname)} //10/16 scalar
         else if whatWeBeEditing == "shape"  {ptype = OSP.getParamType(pname: pname)}
         else if whatWeBeEditing == "pipe"   {ptype = OPP.getParamType(pname: pname)}
         else if whatWeBeEditing == "patch"  {ptype = OPaP.getParamType(pname: pname)} // 9/30

         //let ptype = OVP.getParamType(pname: pname)
         if pname != oldvpname //user changed parameter? load up info to UI
         {
             OVScene.selectedFieldName = pname //1/3 moved from below

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
             //1/3/22 NOTE: combine ptype get above with these calls somehow, maybe just return the type?
             //  how about return a tuple with type , min , max, default?
             if      whatWeBeEditing == "voice"  {OVScene.loadCurrentVoiceParams()}
             else if whatWeBeEditing == "scalar" {OVScene.loadCurrentScalarParams()}
             else if whatWeBeEditing == "shape"  {OVScene.loadCurrentShapeParams()}
             else if whatWeBeEditing == "pipe"   {OVScene.loadCurrentPipeParams()}
             else if whatWeBeEditing == "patch"  {OVScene.loadCurrentPatchParams()} //9/30 new

             //1/2 get min/max back from scene...
             let pmin = OVScene.selectedFieldMin
             let pmax = OVScene.selectedFieldMax
             print("param " + pname + "min \(pmin)  max \(pmax)")
              pLabel.setupForParam( pname : pname , ptype : pt , //1/2 use scene min/max
                                    pmin : Double(pmin) , pmax : Double(pmax) , choiceStrings: choiceStrings)
              oldvpname = pname; //remember for next time
//1/3 WRONG PLACE?              OVScene.selectedFieldName = pname
         } //end if pname
         //convert from slider unit to proper units...
         // 9/30 there is a problem here for some param types???
        if OVScene.selectedFieldType == "double" //10/2 check for double type param
        {
            //print("...indouble \(displayVal)")
            displayVal = OVScene.unitToParam (inval : displayVal)  //oknconvertit
            //print("...   converted... \(displayVal)")
            //12/25 HOKEY? handle scalar snap output
            if whatWeBeEditing == "scalar" && ["xpos","zpos"].contains(pname)
                { displayVal = OVScene.selectedScalar.snapToGrid(dxyz: displayVal) }
        }
         pLabel.updateit(value : displayVal)
         //4/26 Dig up last param value and save
         let sceneChanges = OVScene.setNewParamValue(newEditState : whatWeBeEditing,
                                                     named : pname,
                                                     toDouble : Double(newVal),
                                                     toString : pvalue )
        // 9/27 wups, save back to scene!!!
        OVScene.saveEditBackToSceneWith(objType:whatWeBeEditing)

        update3DSceneForSceneChanges(sceneChanges)
     } // end editParam
     
    //=======>ARKit MainVC===================================
    //Generic function, but where to put it?
    func getDirection(for point: CGPoint, in view: SCNView) -> SCNVector3
    {
        let farPoint  = view.unprojectPoint(SCNVector3Make(Float(point.x), Float(point.y), 1))
        let nearPoint = view.unprojectPoint(SCNVector3Make(Float(point.x), Float(point.y), 0))
        print("farpoint \(farPoint)")
        return SCNVector3Make(farPoint.x - nearPoint.x, farPoint.y - nearPoint.y, farPoint.z - nearPoint.z)
    }
    func getHitPointOnObject(for point: CGPoint, in view: SCNView) -> SCNVector3
    {
        let farPoint  = view.unprojectPoint(SCNVector3Make(Float(point.x), Float(point.y), 1))
        return farPoint
    }

    //=======>ARKit MainVC===================================
    // Used to select items in the AR 3D world...
    // 11/18 keep track of node that was hit too!
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else {return}
        startTouch    = touch
        touchLocation = startTouch.location(in: skView) //10/15 change name
        //print("touchlocation :\(touchLocation)")
        //Use this to figure out where on a shape to place a voice for example
        hitPoint3D = getHitPointOnObject( for:touchLocation, in :skView)
        touchDragDistance = 0
        skView.allowsCameraControl = true  //12/11 make sure tilt/zoom/pan is ON
        //11/18 get node that was touched...
        guard let nodeHitTest = skView.hitTest(startTouch.location(in: skView) , options: nil).first else
            { return }
        let hitNode  = nodeHitTest.node
        if let uid = hitNode.name
        {
            touchNodeUID = uid  //11/18 save uid for later...
            //ONLY works in 2d version
            #if VERSION_2D
            skView.allowsCameraControl = (!uid.contains("scalar"))   //disable tilt/rot on scalar
            #endif
            if uid.contains("scalar") {scalarTrackLocation = touchLocation} //12/13 for scalar tracking
        }
    } //end touchesBegan

    //=======>ARKit MainVC===================================
    // 10/17 there isnt a real double-tap detector, so instead
    //  we will use touchesMoved to put up a popup for the marker...
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        guard let touch = touches.first else {return}
        latestTouch = touch
//        print("touchesmoved...\(latestTouch)")
//        if let pov = skView.pointOfView
//        {
//            print("pov \(pov)")
//        }
        guard let sceneView   = skView else {return}
        let t1 = latestTouch.location(in: sceneView)
        let t2 = latestTouch.previousLocation(in: sceneView)
        let dx = t1.x - t2.x
        let dy = t1.y - t2.y
        touchDragDistance = touchDragDistance + Int(sqrt(dx*dx + dy*dy))  //11/16
        
        if touchNodeUID.contains("scalar")  //dragging over scalar? check for up/down
        {
            handleScalarTouchesMoved(t1:t1)  //interact w/ scalar
        }
    } //end touchesMoved
    
    //=======>ARKit MainVC===================================
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        //print("touches ENDED.. drag is \(touchDragDistance)")
        guard let touch = touches.first else {return}
        let tcount = touches.count
        //NOTE the 10 here should be a configurable parameter! 
        if tcount == 1 && touchDragDistance < 10   {  handleSingleTouch(touch: touch ) } //11/16 ignore double touch for now
        getCamXYZ() //11/16/21 Save new 3D cam position
        touchNodeUID = "" //11/18 used for dragging only now...

    }
    
    
    //=====<oogie2D mainVC>====================================================
    //11/18 called by touchesEnded
    func handleSingleTouch(touch:UITouch)
    {
        guard let sceneView   = skView else {return}
        touchLocation         = startTouch.location(in: sceneView) //10/15 change name
        guard let nodeHitTest = sceneView.hitTest(touchLocation, options: nil).first else {return}
        let hitNode  = nodeHitTest.node
        //var selected = false //9/25
        //var gotdice  = false
        if let uid = hitNode.name //9/25 use uid not name now...
        {
            //print("hitnode \(uid)")
            if uid.contains("dice") //11/3 handle various dice
            {
                _ = handleDice(uid:uid)
            }
            else if uid.contains("menu") //11/13 handle menu
            {
                _ = handleMenuFrom3D(uid:uid)
            }
            else if uid.contains("pianoKeys") //2/28 keyboard hit test => output note
            {
                let localCoordinates = nodeHitTest.localCoordinates
                handleKeyboardPressWith(coords:localCoordinates)
            }
            else if uid.contains("shape") //Found a shape? get which one
            {
                _ = selectOrDeselectShapeBy(uid:uid)
            }
            else if uid.contains("voice") // 9/27 Found a marker? get which one
            {
                _ = selectOrDeselectMarkerBy(uid:uid)
             }
            else if uid.contains("pipe") //Found a pipe? get which one
            {
                _ = selectOrDeselectPipeBy(uid:uid)
            }
            else if uid.contains("scalar") //Found a pipe? get which one
            {
                _ = selectOrDeselectScalarBy(uid:uid)
            }
        }     //end let name
    } //end handleSingleTouch
    
    //=====<oogie2D mainVC>====================================================
    // 12/13 for pure 3D scalar interaction, user drags and scalar changes
    func handleScalarTouchesMoved(t1:CGPoint)
    {
        if OVScene.sceneScalars[touchNodeUID] != nil
        {
            OVScene.savingEdits = true
            let dvert =  scalarTrackLocation.y - t1.y // 12/13 in pixels
            scalarTrackLocation = t1 //12/13 remember for next time
            let teensybit = Double(dvert) * 0.002  //12/13 make larger
            let newValue = min(1.0,max(0.0,OVScene.sceneScalars[touchNodeUID]!.SS.value  + teensybit))
            //ok this is the same as in setScalarValue from scalarPanel
            // this call does the work, changes the scene as needed
            workScalarUID = touchNodeUID //12/23 need this for 3d update
            let paramTuple = OVScene.setNewScalarValue(sobj:OVScene.sceneScalars[touchNodeUID]! , value: Double(newValue) , pvalue : "")
            let paramName  = paramTuple.param
            let displayVal = paramTuple.val //12/19
            update3DSceneForSceneChanges(paramTuple.sceneChanges) //12/15 handle 3d updates

            OVScene.sceneScalars[touchNodeUID]!.SS.value = Double(newValue) //12/17 keep trak of value
            if OVScene.scalars3D[touchNodeUID] != nil //Assume 3d object exists!!!
            {
                OVScene.scalars3D[touchNodeUID]!.updateIndicator(toObject: paramName, //12/19
                                               value: CGFloat(newValue),dvalue: CGFloat(displayVal))
            }
            OVScene.savingEdits = false
            let s = String(format: "%@: %4.2f", paramName,displayVal)
            pLabel.updateLabelOnly(lStr: s) ///"\(paramName) :" + String(val))
        }
    } //end handleScalarTouchesMoved

    
    //=====<oogie2D mainVC>====================================================
    // 11/13 new handle menu, triggered by yellow menu boxes in scene
    func handleMenuFrom3D(uid:String) -> Bool
    {
        if uid.count < 8 {return false} //too short to contain anything?
        let ss = uid.split(separator: "_")   //divide up
        if ss.count != 3 {return false} //should be format dice_object_UID#
        let luid : String =  ss[1] + "_" + ss[2]  //reassemble 2nd two items

        if luid.contains("voice")
         {
            if let v = OVScene.sceneVoices[luid]
            {
                voiceMenu(v: v)
                if let mshape = OVScene.markers3D[luid]
                {
                    mshape.animateMenuSelect() //11/13 indicate menu was hit
                }
            }
         }
        else if luid.contains("shape")
         {
            if let s = OVScene.sceneShapes[luid]
            {
                shapeMenu(s: s)
                if let sshape = OVScene.shapes3D[luid]
                {
                    sshape.animateMenuSelect() //11/13 indicate menu was hit
                }
            }
         }
        return false
    } //end handleMenuFrom3D
    
    //=====<oogie2D mainVC>====================================================
    // 11/25 for interaction w/ 3d Dice objects
    func handleDice(uid:String) -> Bool
    {
        var gotDice = false
        //print("dice \(uid)")
        //strip 2nd half of dice uid...
        if uid.count < 8 {return false} //too short to contain anything?
        let ss = uid.split(separator: "_")   //divide up
        if ss.count != 3 {return false} //should be format dice_object_UID#
        OVScene.savingEdits = true //11/25 DUH! avoid data collisions
        let luid : String =  ss[1] + "_" + ss[2]  //reassemble 2nd two items
        if luid.contains("scalar") //randomize scalar?
        {
            //print("randomize scalar \(luid)")
            let newVal     = Double.random(in:0.0...1.0)
            //ok find scalar by uid...
            if OVScene.sceneScalars[luid] != nil //get our scalar and its shape
            {
                gotDice = true
                if OVScene.scalars3D[luid] != nil //find scalar shape by UID for animation updates
                {
                    workScalarUID = luid //12/23 need this for 3d update
                    let paramTuple = OVScene.setNewScalarValue(sobj:OVScene.sceneScalars[luid]! , value: newVal , pvalue : "") //11/3 break out to method
                    let toObjName  = paramTuple.toobj
                    let paramName  = paramTuple.param
                    let displayVal = paramTuple.val //12/25
                    update3DSceneForSceneChanges(paramTuple.sceneChanges) //12/15 handle 3d updates
                    //FIX THIS TOO, need to get converted value from set NewScalarValue
                    OVScene.scalars3D[luid]!.updateIndicator(toObject: paramName,
                                 value: CGFloat(newVal),dvalue: CGFloat(displayVal)) //12/19
                    OVScene.scalars3D[luid]!.updatePedestalLabel(with: toObjName)
                    OVScene.scalars3D[luid]!.animateDiceSelect() //11/4 indicate dice was hit
                    let s = String(format: "%@: %4.2f", paramName,displayVal)
                    pLabel.updateLabelOnly(lStr: s)
                    OVScene.savingEdits = false //11/25
                    return true
                }
            }
        } //end scalar
        else if luid.contains("shape") //randomize a shape...
        {
            if OVScene.sceneShapes[luid] != nil
            {
                gotDice = true
                let randTexName = tc.getRandomTextureName()
                //lets get a random texture!
                if let randTexImage = tc.texDict[randTexName]
                {
                    if OVScene.shapes3D[luid] != nil
                    {
                        OVScene.shapes3D[luid]!.setBitmapImage(i: randTexImage) //set 3d shape texture
                        OVScene.sceneShapes[luid]!.setBitmap(s: randTexName)
                        OVScene.sceneShapes[luid]!.OOS.texture = randTexName
                        //randomize texture scale/offsets
                        let usc = Double.random(in: 0.05...10.0) //11/25 cleanup
                        let vsc = Double.random(in: 0.05...10.0)
                        let uco = Double.random(in: 0.0...1.0)
                        let vco = Double.random(in: 0.0...1.0)
                        let wrapST = 1 //11/28 stick to repeat for now
                        OVScene.sceneShapes[luid]!.OOS.uScale = usc
                        OVScene.sceneShapes[luid]!.OOS.vScale = vsc
                        OVScene.sceneShapes[luid]!.OOS.uCoord = uco
                        OVScene.sceneShapes[luid]!.OOS.vCoord = vco
                        OVScene.sceneShapes[luid]!.OOS.wrapS  = wrapST //11/28
                        OVScene.sceneShapes[luid]!.OOS.wrapT  = wrapST
                        OVScene.shapes3D[luid]!.setTextureScaleTranslationAndWrap(xs: Float(usc), ys: Float(vsc),
                                                                                  xt: Float(uco), yt: Float(vco) ,
                                                                                  ws: wrapST , wt : wrapST) //11/28
                        OVScene.sceneShapes[luid]!.bmp.setScaleAndOffsets(
                            sx: usc, sy: vsc, ox: uco, oy: vco)
                        OVScene.shapes3D[luid]!.animateDiceSelect() // indicate dice was hit
                        pLabel.updateLabelOnly(lStr: "Dice: Shape Texture")
                        if whatWeBeEditing == "shape" && luid == OVScene.selectedShapeKey  //currently editing this shape?
                        {
                            OVScene.selectedShape = OVScene.sceneShapes[luid]!  //pull edited shape from scene
                            setupShapePanelWithFreshParams() //11/29
                        }
                    }
                } //end let randtexImage
            } //end sceneShapes[] !=nil
        } //end shape
        else if luid.contains("voice") //randomize a voice... COMPLICATED!
        {
            // note we randomize voice and get random patch, patch load goes to selecteVoice.
            //  as a result if already editing a voice and another voice 3D dice is hit, then
            //  selected voice gets overwritten during this operation! hence tempVoice saving
            var needToSaveTemp = false
            var tempVoice = OogieVoice()
            //are we randomizing a non-selected voice? save selected voice for temp
            if whatWeBeEditing == "voice" && OVScene.selectedVoice.uid != luid
            {
                needToSaveTemp = true
                tempVoice = OVScene.selectedVoice
            }
            //ok select voice that was hit...
            if let v = OVScene.sceneVoices[luid]
            {
                gotDice = true
                OVScene.selectedVoice = v
                let rPatchName = allP.getRandomPatchName()
                loadPatchByName(pName: rPatchName)
                //11/22 moved here from loadPatchByName
                loadRandomPatchToSelectedVoice() //can it be this easy??? control panel needs update too?
                if OVScene.markers3D[luid] != nil
                {
                    //print("new type \(OVScene.selectedVoice.OOP.type)")
                    OVScene.markers3D[luid]!.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))
                }
                if whatWeBeEditing == "voice" && luid == OVScene.selectedMarkerKey  //11/29 currently editing this voice?
                {
                    //let pd = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
                    cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
                    cPanel.configureView()
                }
                if let mshape = OVScene.markers3D[luid]
                {
                    mshape.animateDiceSelect() //11/11 indicate dice was hit
                }
                OVScene.sceneVoices[luid] = OVScene.selectedVoice; //11/22 save new voice back...
            }
            if needToSaveTemp  { OVScene.selectedVoice = tempVoice } //restore old selected voice
        } //end if voice
        OVScene.savingEdits = false //11/25
        return gotDice
    } //end handleDice
    
    
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
    //Kluge 10/15
    func closePanels(otherThan:String)
    {
        var allPanels = [pipeEditPanels,shapeEditPanels,voiceEditPanels] //assume scalar for starter
        if otherThan      == "pipe"   {allPanels = [shapeEditPanels,scalarEditPanels,voiceEditPanels]}
        else if otherThan == "shape"  {allPanels = [pipeEditPanels,scalarEditPanels,voiceEditPanels]}
        else if otherThan == "voice"  {allPanels = [pipeEditPanels,scalarEditPanels,shapeEditPanels]}
        for panel in allPanels
        {
            shiftPanelDown(panel: panel!) //we know panel is legit, force unwrap
        } //ok shiftem down
        if otherThan != "pipe"      { piPanel.stopAnimation()  } //10/23 halt pipe anim

    } //end closePanels
    
    //=====<oogie2D mainVC>====================================================
    // 9/25 Toggle select for desired marker, returns selected status
    func selectOrDeselectMarkerBy(uid:String) -> Bool
    {
        var selected = false
        unselectAnyOldStuffBy(uid:uid)
        closePanels(otherThan: "voice")
        if let testMarker = OVScene.markers3D[uid]
        {
            print("...select marker \(uid)")
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
                    {
                        self.pLabel.updateLabelOnly(lStr:"Select " + smname)
                        selectedMarker.updatePanels(nameStr: smname) //10/4 fix
                    }
                    OVScene.selectedVoice     = testVoice //Get associated voice for this marker
                    OVScene.selectedMarkerKey = uid      //points to OVS struct in scene
                    updatePkeys() //3/30 update kb if needed
                    //Pack params, send to VC
                    cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
                    cPanel.configureView()
                    shiftPanelUp(panel: voiceEditPanels) //9/11 shift controls so they are visible
                }
                selected = true
            }
            else
            {
                OVScene.selectedMarkerKey = "" //11/16 indicate no select
                selected = false
                shiftPanelDown(panel: voiceEditPanels) //9/11 shift controls offscreen
            }
        } //end let testMarker...
        return selected
    } //end selectOrDeselectMarkerBy
    
    //=====<oogie2D mainVC>====================================================
    // 10/14 new
    func selectOrDeselectScalarBy(uid:String) -> Bool
    {
        var selected = false
        unselectAnyOldStuffBy(uid: uid) //9/26
        closePanels(otherThan: "scalar")
        if let testShape = OVScene.scalars3D[uid]
        {
            OVScene.selectedScalarKey = uid
            selectedScalarShape   = testShape
            selectedScalarShape.toggleHighlight()
            //Wow is this redundant?
            if selectedScalarShape.highlighted  //hilited? Set up edit
            {
                whatWeBeEditing = "scalar"   //2/6 WTF?
                
                self.pLabel.updateLabelOnly(lStr:"Select " + self.selectedScalarShape.name!)
                if let testScalarObj = OVScene.sceneScalars[uid] //got legit voice?
                {
                    OVScene.selectedScalar     = testScalarObj
                    OVScene.selectedShapeKey  = uid //10/21
                    shiftPanelUp(panel: scalarEditPanels) //9/11 shift controls so they are visible
                    scPanel.paramDict = OVScene.selectedScalar.getParamDict()
                    //10/18  we need to set up menu depending on salar output object, shape vs voice
                    if testScalarObj.SS.toObject.contains ("shape")//hooked to shape?
                    {
                        scPanel.outputNames = OSP.shapeParamNamesOKForPipe
                    }
                    else
                    {
                        scPanel.outputNames = OVP.voiceParamNamesOKForPipe
                    }
                    //???OVScene.selectedFieldDisplayVals //now we should have our outputs

                    scPanel.configureView() //9/12 loadup stuff
                }
                selected = true
            }
            else //deselect?
            {
                OVScene.selectedScalarKey = "" //11/16 indicate no select
                shiftPanelDown(panel: scalarEditPanels) //9/11 shift controls so they are visible
                selected = false
            }
        }
        return selected
    } //end selectOrDeselectScalarBy
    
    //=====<oogie2D mainVC>====================================================
    // 9/25 Toggle select for desired shape, returns selected status
    func selectOrDeselectShapeBy(uid:String) -> Bool
    {
        var selected = false
        unselectAnyOldStuffBy(uid: uid) //10/20 wups
        closePanels(otherThan: "shape")
        if let testShape = OVScene.shapes3D[uid] //1/26
        {
            OVScene.selectedShapeKey = uid
            selectedSphere    = testShape
            selectedSphere.toggleHighlight()
            //Wow is this redundant?
            if selectedSphere.highlighted  //hilited? Set up edit
            {
                whatWeBeEditing = "shape"   //2/6 WTF?
                self.pLabel.updateLabelOnly(lStr:"Select " + self.selectedSphere.name!)
                if let testShape = OVScene.sceneShapes[uid] //got legit voice?
                {
                    OVScene.selectedShape     = testShape
                    OVScene.selectedShapeKey  = uid //10/21
                    //2/3 add name/comment to 3d shape info box
                    selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                                comm: OVScene.selectedShape.OOS.comment)
                    sPanel.texNames = tc.loadNamesToArray() //populates texture chooser
                    shiftPanelUp(panel: shapeEditPanels) //9/11 shift controls so they are visible
                    setupShapePanelWithFreshParams()
                }
                selected = true
            }
            else //deselect?
            {
                OVScene.selectedShapeKey = "" //11/16 indicate no select
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
        if let pipe3D = OVScene.pipes3D[uid]
        {
            selectedPipeShape = pipe3D
            unselectAnyOldStuffBy(uid:uid) //11/30
            closePanels(otherThan: "pipe")
            OVScene.selectedPipeKey = uid
            selectedPipeShape.toggleHighlight()
            //9/25 WOW. this is looking at the LOADED pipe data.
            //  however data freshly loaded into the scene memory has NEW UIDs.
            //  should I keep the old uids from scenes when creating objects?
            //12/6 KRASH, just trying to select pipe , just loaded scene...
            if let spo = OVScene.scenePipes[uid] //now get pipe record...
            {
                whatWeBeEditing      = "pipe"  //2/6 WTF?
                OVScene.selectedPipe = spo // get 3d scene object...
                //Beam pipe name and output buffer to a texture in the pipe...
                // ideally this should be updaged on a timer!
                let name = OVScene.selectedPipe.PS.name //9/25
                selectedPipeShape.updateInfo(nameStr: name,
                                             pinfo: spo.getPipeInfo())
                selected = true
                if selectedPipeShape.highlighted  //hilited? Set up edit
                {
                    self.pLabel.updateLabelOnly(lStr:"Select " + spo.PS.name)
                    shiftPanelUp(panel: pipeEditPanels) //9/11 shift controls so they are visible
                    piPanel.paramDict = OVScene.selectedPipe.getParamDict()
                    //WOW THIS IS HOKEY!
                    // get correct output parameter names for this pipe
                    OVScene.selectedFieldName = "outputparam" //Force selection to get possible output pipe values...
                    OVScene.loadCurrentPipeParams()
                    //TEST DELETE THIS
                    //let duhhh = OVScene.selectedFieldDisplayVals
                    piPanel.outputNames = OVScene.selectedFieldDisplayVals //now we should have our outputs
                    piPanel.configureView() //9/12 loadup stuff
                    piPanel.startAnimation() //10/5
                    selected = true
                }
                else //deselect?
                {
                    shiftPanelDown(panel: pipeEditPanels)
                    piPanel.stopAnimation() //10/5
                    selected = false
                    OVScene.selectedPipeKey = "" //11/16 indicate no select
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
        else if whatWeBeEditing == "scalar" //10/15 new
        {
            if selectedScalarShape.highlighted &&
                OVScene.selectedScalarKey != uid
                { selectedScalarShape.unHighlight() }
            OVScene.selectedScalarKey = ""
        }
        else if whatWeBeEditing == "shape"
        {
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
    // 11/29 called from handleDice and selectOrDeselectShapeBy
    func setupShapePanelWithFreshParams()
    {
        sPanel.paramDict = OVScene.selectedShape.getParamDict()
        let tn = OVScene.selectedShape.OOS.texture
        var ii = tc.defaultTexture  //11/15 add default to TC
        if tn != "default" {ii = tc.texDict[tn]}
        sPanel.texture = ii
        sPanel.thumbDict = tc.thumbDict //10/28 texture thumbs
        sPanel.updateTextureDisplay() //12/9 wups forgot?
        sPanel.configureView() //9/12 loadup stuff
    } //end setupShapePanelWithFreshParams


    //=====<oogie2D mainVC>====================================================
    // MAIN CHOICE menu, appears LH side as a MENU button
    func menu()
    {
        //12/16 DEBUG: dump scene on menu select, COMMENT out for delivery!
        let s = self.OVScene.getCurrentSceneDumpString()
        print(s)

        let tstr = "oogie2D" //"Menu (V" + version + ")"
        // 11/25 add big dark title
        let attStr = NSMutableAttributedString(string: tstr)
        attStr.addAttribute(NSAttributedStringKey.font, value: UIFont.boldSystemFont(ofSize: 25), range: NSMakeRange(0, attStr.length))
        let alert = UIAlertController(title: tstr, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.setValue(attStr, forKey: "attributedTitle")
    //12/19 test for dark mode    alert.view.tintColor = UIColor.black //lightText, works in darkmode

        alert.addAction(UIAlertAction(title: "Load Scene...", style: .default, handler: { action in
            self.chooserMode = "loadScene"
            self.performSegue(withIdentifier: "chooserLoadSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene", style: .default, handler: { action in
            self.OVScene.packupSceneAndSave(sname:self.OVSceneName, saveit: true) //11/8
            self.pLabel.updateLabelOnly(lStr:"Saved " + self.OVSceneName)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene As...", style: .default, handler: { action in
            self.chooserMode = "saveSceneAs" //9/28
            self.performSegue(withIdentifier: "chooserSaveSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Clear Scene...", style: .default, handler: { action in
            self.clearScenePrompt()
        }))
        // Reset camera to see all scene, normalize camera tilt perpendicular to XZ plane
        alert.addAction(UIAlertAction(title: "Reset Camera", style: .default, handler: { action in
            self.resetCamera()
        }))
        alert.addAction(UIAlertAction(title: "3D Piano KB", style: .default, handler: { action in
            self.updatePkeys() //3/30 update kb if needed
            self.pkeys.isHidden = !self.pkeys.isHidden
        }))
        alert.addAction(UIAlertAction(title: "Patches...", style: .default, handler: { action in
            self.patchToEdit = ""  //12/30
            self.performSegue(withIdentifier: "patchVCSegue", sender: self) //10/24
        }))
        alert.addAction(UIAlertAction(title: "Samples...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "samplesVCSegue", sender: self) //10/24
        }))
        alert.addAction(UIAlertAction(title: "Textures...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "textureSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "General Settings...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "settingsVCSegue", sender: self) //10/24
        }))
        alert.addAction(UIAlertAction(title: "Select...", style: .default, handler: { action in
            self.selectObjectMenu()
        }))
//        alert.addAction(UIAlertAction(title: "Dump Scene...", style: .default, handler: { action in
//            let s = self.OVScene.getCurrentSceneDumpString()
//            print(s)
//            self.infoAlert(title:"oogie scene dump" , message : s)
//            self.dumpBuffers()
//        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end menu
    

    
    //=====<oogie2D mainVC>====================================================
    // 10/7 it would be nice to sort the names in this menu...??
    func selectObjectMenu()
    {
        let tstr = "Select Object"
        let attStr = NSMutableAttributedString(string: tstr)
        attStr.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 25), range: NSMakeRange(0, attStr.length))
        let alert = UIAlertController(title: tstr, message: nil, preferredStyle: UIAlertController.Style.alert)
        alert.setValue(attStr, forKey: "attributedTitle")
       //12/19  alert.view.tintColor = UIColor.black //lightText, works in darkmode
        let dv = OVScene.getNameUIDDict(forEvery: "voice") //get name -> UID map
        for name in dv.keys.sorted()
        {
            let uid = dv[name]
            if uid != OVScene.selectedMarkerKey
            {
                let action = UIAlertAction(title: name, style: .default, handler: { action in
                    let _ = self.selectOrDeselectMarkerBy(uid:uid!) //we definitely have UID!
                })
                action.setValue(imageV?.withRenderingMode(.alwaysOriginal), forKey: "image")
                alert.addAction(action)
            }
        }
        let ds = OVScene.getNameUIDDict(forEvery: "shape") //get name -> UID map
        for name in ds.keys.sorted()
        {
            let uid = ds[name]
            if uid != OVScene.selectedShapeKey
            {
                let action = UIAlertAction(title: name, style: .default, handler: { action in
                    let _ = self.selectOrDeselectShapeBy(uid:uid!) //we definitely have UID!
                })
                action.setValue(imageS?.withRenderingMode(.alwaysOriginal), forKey: "image")
                alert.addAction(action)
            }
        }
        // 10/23 add  scalar select
        let dsc = OVScene.getNameUIDDict(forEvery: "scalar") //get name -> UID map
        for name in dsc.keys.sorted()
        {
            let uid = dsc[name]
            if uid != OVScene.selectedScalarKey
            {
                let action = UIAlertAction(title: name, style: .default, handler: { action in
                    let _ = self.selectOrDeselectScalarBy(uid:uid!) //we definitely have UID!
                })
                action.setValue(imageL?.withRenderingMode(.alwaysOriginal), forKey: "image")
                alert.addAction(action)
            }
        }
        let dp = OVScene.getNameUIDDict(forEvery: "pipe") //get name -> UID map
        for name in dp.keys.sorted()
        {
            let uid = dp[name]
            if uid != OVScene.selectedPipeKey
            {
                let action = UIAlertAction(title: name, style: .default, handler: { action in
                    let _ = self.selectOrDeselectPipeBy(uid:uid!) //we definitely have UID!
                })
                action.setValue(imageP?.withRenderingMode(.alwaysOriginal), forKey: "image")
                alert.addAction(action)
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            print("cancel...")
        }))

        self.present(alert, animated: true, completion: nil)
    } //end selectObjectMenu

    //=====<oogie2D mainVC>====================================================
    // voice popup... various functions
    func voiceMenu(v:OogieVoice)
    {
        let alert = UIAlertController(title: v.OVS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode

        alert.addAction(UIAlertAction(title: "Edit Voice Patch...", style: .default, handler: { action in
            self.patchToEdit = v.OVS.patchName //12/30
            self.performSegue(withIdentifier: "patchVCSegue", sender: self)
        }))
        //12/19  alert.view.tintColor = UIColor.black //2/6 black text
        
        var tstr = "Solo"    //10/20 move solo voice id out to scene
        if OVScene.soloVoiceID != "" {tstr = "UnSolo"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            if self.OVScene.soloVoiceID == ""
            {
                self.OVScene.soloVoiceID = v.uid
            }
            else
            {
                self.OVScene.soloVoiceID = ""
            }
            self.selectedMarker.toggleHighlight() //WHY IS thiS HERE???
            self.OVScene.handleSoloToggle()
        }))

        tstr = "Mute"
        if v.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            var muted = v.muted
            muted = !muted
            v.muted = muted
            self.selectedMarker.toggleHighlight()
        }))
        alert.addAction(UIAlertAction(title: "Clone along Lat", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: v.OVS, op: "clonelat") //12/10 add clone lat/lon
        }))
        alert.addAction(UIAlertAction(title: "Clone along Lon", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: v.OVS, op: "clonelon") //12/10 add clone lat/lon
        }))
        alert.addAction(UIAlertAction(title: "Delete...", style: .default, handler: { action in
            self.deleteVoice(v:v) //12/5 new arg
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            let key = v.OVS.key
            self.OVScene.resetVoiceByKey(key: key)  //1/14 Reset shape object from scene
            if let marker = self.OVScene.markers3D[key] //4/28 new dict
            {
                marker.updateLatLon(llat: v.OVS.yCoord, llon: v.OVS.xCoord)
            }
        }))
        alert.addAction(UIAlertAction(title: "Add Pipe...", style: .default, handler: { action in
           self.addPipeStepOne(voice: v)
        }))
        // 12/10 moved from main menu add  scalar from main menu to shape or voice
        alert.addAction(UIAlertAction(title: "Add Scalar...", style: .default, handler: { action in
            self.addPipeStepThree(voice: v,channel: "" , destination : v.OVS.uid ,
                                  objType: "voice" ,asObject: "Scalar")
        }))
        alert.addAction(UIAlertAction(title: "Randomize...", style: .default, handler: { action in
            let _ = self.handleDice(uid:"dice_" + v.OVS.uid) //12/18
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end voiceMenu
    
    //=====<oogie2D mainVC>====================================================
    // 11/30 pipe menu options
    func pipeMenu()
    {
        let alert = UIAlertController(title: self.OVScene.selectedPipe.PS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Pipe...", style: .default, handler: { action in
            self.deletePipe(p:self.OVScene.selectedPipe)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end pipeMenu

    //=====<oogie2D mainVC>====================================================
    // 10/21 scalar menu options
    func scalarMenu()
    {
        let alert = UIAlertController(title: self.OVScene.selectedScalar.SS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Scalar...", style: .default, handler: { action in
            self.deleteScalar(s:self.OVScene.selectedScalar)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end scalarMenu

 
    //=====<oogie2D mainVC>====================================================
    // operations available to selected shape...
    func shapeMenu(s: OogieShape)
    {
        let alert = UIAlertController(title: s.OOS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addShapeToScene(shapeOSS: s.OOS, op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShape(s:s) //12/10
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS,  op: "new")
        }))
        alert.addAction(UIAlertAction(title: "Delete all Voices on Shape ...", style: .default, handler: { action in
            self.deleteAllShapeVoices(s:s) //12/4 new
        }))
        alert.addAction(UIAlertAction(title: "CarpetBomb...", style: .default, handler: { action in
            self.carpetBombPhaseOne(s:s)  //12/4 new
        }))
        alert.addAction(UIAlertAction(title: "Randomize...", style: .default, handler: { action in
            let _ = self.handleDice(uid:"dice_" + s.OOS.uid) //12/18
        }))
        
        alert.addAction(UIAlertAction(title: "Add Scalar...", style: .default, handler: { action in
            self.addPipeStepThree(voice: self.OVScene.selectedVoice, channel: "" , //10/20 add  scalar to this shape
                                  destination : s.OOS.uid , //was selectedShapeKey
                                  objType: "shape" ,asObject: "Scalar")
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end shapeMenu
    
    //=====<oogie2D mainVC>====================================================
    // 12/29 new, w prompt For Deletes
    func deleteAllShapeVoices(s: OogieShape)
    {   //First get a count and UID list
        let vuids = OVScene.getListOfShapeVoices(suid:s.OOS.uid) //12/29 get voices on this shape
        if appDelegate.promptForDeletes != 0 //12/29
        {
            let tit   = "Delete all voices for shape " + s.OOS.name + "?"
            let alert = UIAlertController(title: tit, message: String(vuids.count) + " voices will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.OVScene.deleteVoicesBy(list: vuids)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else { self.OVScene.deleteVoicesBy(list: vuids) }  //12/29 delete w/o prompt
    } //end deleteAllShapeVoices

    //=====<oogie2D mainVC>====================================================
    // 12/4 scatter stuff around the shape..  does NOT check for existing voices.
    //  phase one gets patch name
    func carpetBombPhaseOne(s: OogieShape)
    {
        let alert = UIAlertController(title: "Carpet Bomb Phase One", message: "Creates arrays of voices. Set Bombing Size...", preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
        //what do i put here? cant put hundredds of patches???
        for i in [3,4,5,6,7]
        {
            alert.addAction(UIAlertAction(title: String(i) + " voices", style: .default, handler: { action in
                self.carpetBombPhaseTwo( s:s , count: i)
            }))
        } //end for i
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end carpetBombPhaseOne

    //=====<oogie2D mainVC>====================================================
    func carpetBombPhaseTwo(s: OogieShape , count: Int)
    {
        let alert = UIAlertController(title: "Carpet Bomb Phase Two", message: "Set Bombing Pattern...", preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
        //what do i put here? cant put hundredds of patches???
        for pattern in ["horizontal","vertical","angle","chevron","random"]
        {
            alert.addAction(UIAlertAction(title: pattern, style: .default, handler: { action in
                self.carpetBombPhaseThree( s:s , count:count , pattern:pattern )
            }))
        } //end for pattern
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end carpetBombPhaseOne

    //=====<oogie2D mainVC>====================================================
    func carpetBombPhaseThree(s: OogieShape , count: Int , pattern: String)
    {
        let alert = UIAlertController(title: "Carpet Bomb Phase Three", message: "Select Patch...", preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
        
        if OVScene.selectedVoice.uid != "" //past selected voice?
        {
            alert.addAction(UIAlertAction(title: "Last Selected Voice", style: .default, handler: { action in
                self.carpetBombCreate( s:s , count:count , pattern:pattern  , patchName:"lastselectedvoice" )
            }))
        }
        alert.addAction(UIAlertAction(title: "Random Synth", style: .default, handler: { action in
            self.carpetBombCreate( s:s , count:count , pattern:pattern  , patchName:"randomsynth" )
        }))
        alert.addAction(UIAlertAction(title: "Random Percussion", style: .default, handler: { action in
            self.carpetBombCreate( s:s , count:count , pattern:pattern  , patchName:"randompercussion" )
        }))
        alert.addAction(UIAlertAction(title: "Random PercKit", style: .default, handler: { action in
            self.carpetBombCreate( s:s , count:count , pattern:pattern  , patchName:"randomperckit" )
        }))
        alert.addAction(UIAlertAction(title: "Random Sample", style: .default, handler: { action in
            self.carpetBombCreate( s:s , count:count , pattern:pattern  , patchName:"randomsample" )
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end carpetBomb
    
    
    //=====<oogie2D mainVC>====================================================
    func carpetBombCreate(s: OogieShape , count: Int , pattern: String , patchName:String)
    {
        // get our points...
        let pointz = createBombingPattern(count: count, pattern: pattern)
        OVScene.savingEdits = true //12/5
        for p in pointz //ok add our pattern point by point
        {
            let lat : Float =  -0.5 * .pi + Float(p.y) * .pi   //convert from unit space to radians
            let lon : Float =  -1.0 * .pi + Float(p.x) * .pi * 2.0
            var ovs = OVStruct()  //start with a default voice struct...
            ovs.shapeKey  = s.OOS.uid  //hook up to our shape...
            var pname = patchName // get mutable patchName, it may have to change
            switch(patchName) //12/5 nandle randomizers...
            {
            case "randomsynth":      pname = allP.getRandomSynthPatchName()
                if pname == "SwooshNoise" {pname = "Bubbles"}  //12/7 avoid the noise!
            case "randompercussion": pname = allP.getRandomPercussionPatchName()
            case "randomperckit":    pname = allP.getRandomPercKitPatchName()
            case "randomsample":     pname = allP.getRandomSamplePatchName()
            case "lastselectedvoice":
                var incomingOVS   = OVScene.selectedVoice.OVS //pull last selected OVStruct
                incomingOVS.uid   = ovs.uid  //we need new uid/name
                incomingOVS.name  = ovs.name
                ovs = incomingOVS //pass to our working OSV
                pname = ovs.patchName //reuse its patchname
            default: continue //do nothing
            }
            ovs.patchName = pname //  and select patch...
            let opstr : String = "new_latitude:" + String(lat) +  "_longitude:" + String(lon)
            print("patch:" + pname + " ll:" + opstr)
            self.addVoiceToSceneWithPatch(nextOVS: ovs, op: opstr , patchName: pname)   //add out voices
        }
        OVScene.savingEdits = false
    } //end carpetBombWith
    
    //=====<oogie2D mainVC>====================================================
    func createBombingPattern ( count:Int , pattern:String) -> [CGPoint]
    {
        var results: [CGPoint] = []
        if count > 2  //dont perform trivial patterns
        {
            if !pattern.contains("random") //do a linear pattern...
            {
                let np1 : CGFloat = CGFloat(count) - 1.0 //number of segments
                let minlen = np1 * 0.04;
                var x0 : CGFloat = 0.0
                var x1 : CGFloat = 0.0
                var y0 : CGFloat = 0.0
                var y1 : CGFloat = 0.0
                var d  : CGFloat = 0.0
                while d < minlen
                {
                    x0 = CGFloat.random(in: 0...1)
                    x1 = CGFloat.random(in: 0...1)
                    y0 = CGFloat.random(in: 0.1...0.9)  //y range is smaller!
                    y1 = CGFloat.random(in: 0.1...0.9)
                    if pattern == "horizontal" {y1 = y0}  //trivialize for H
                    if pattern == "vertical"   {x1 = x0}  //trivialize for V
                    d = sqrt((x1-x0)*(x1-x0) + (y1-y0)*(y1-y0)) //distance...
                }
                //ok create output
                let xd = (x1 - x0) / np1
                let yd = (y1 - y0) / np1
                for _ in 0..<count
                {
                    results.append(CGPoint(x: x0, y: y0))
                    x0 = x0 + xd
                    y0 = y0 + yd
                }
                if pattern == "chevron" //chevron is special...
                {
                    var istart = 0
                    var iend   = results.count-1
                    while (istart < iend) //copy start xcoords to end points
                    {
                        let cp0 = results[istart]
                        var cp1 = results[iend]
                        cp1.x = cp0.x
                        results[iend] = cp1
                        istart+=1
                        iend-=1
                    }
                }
            } //end if pattern
            else //random?
            {
                for _ in 0..<count
                {
                    let x = CGFloat.random(in: 0...1)
                    let y = CGFloat.random(in: 0.1...0.9)  //y range is smaller!
                    results.append(CGPoint(x: x, y: y))
                }
            }
        } //end if count
        return results
    } //end createBombingPattern
    
    //=====<oogie2D mainVC>====================================================
    // 12/29 add prompt flag
    func deleteShape(s: OogieShape)
    {
        if appDelegate.promptForDeletes != 0 //12/29
        {
            let tit   = "Delete shape " + s.OOS.name + "?"
            let alert = UIAlertController(title: tit, message: "Shape will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
            //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.shiftPanelDown(panel: self.shapeEditPanels)
                self.OVScene.deleteShapeBy(uid: s.OOS.uid) //12/10
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else //perform delete w/o prompt
        {
            self.shiftPanelDown(panel: self.shapeEditPanels) //12/29 if shape selected
            self.OVScene.deleteShapeBy(uid: s.OOS.uid)
        }
    }  //end deleteShape
    
    
    //=====<oogie2D mainVC>====================================================
    // spawns a series of other stoopid submenus, until there is a smart way
    //    to do it in AR.  like point at something and select?????
    //  Step 1: get output channel, Step 2: pick target , Step 3: choose parameter
    func addPipeStepOne(voice:OogieVoice)
    {
        let alert = UIAlertController(title: "Choose Pipe Output Channel", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        //DHS 12/1 REPLACE!!!
        let chanz = ["Red","Green","Blue","Hue","Saturation","Luminosity","Cyan", "Magenta" ,"Yellow"]
        for chan in chanz
        {
            alert.addAction(UIAlertAction(title: chan, style: .default, handler: { action in
                self.addPipeStepTwo(voice: voice,channel: chan.lowercased(), asObject:"Pipe") //10/14
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end addPipeStepOne
  
    //=====<oogie2D mainVC>====================================================
    // 10/14 add asObject so we can use this to add pipes or scalars
    func addPipeStepTwo(voice:OogieVoice , channel : String, asObject : String)
    {
        //print("step 2 chan \(channel)")
        //12/30 we should look in sceneShapes/sceneVoices for our list...
        let shapeList = OVScene.getListOfSceneShapeNames() //9/28
        let voiceList = OVScene.getListOfSceneVoiceNames()
        let alert = UIAlertController(title: "Choose " + asObject + " Destination", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        for l11 in shapeList
        {
            let uid = OVScene.findSceneShapeUIDByName ( name: l11)
            alert.addAction(UIAlertAction(title: l11, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : uid ,
                                      objType: "shape",asObject: asObject)
            }))
        }
        for l12 in voiceList
        {
            let uid = OVScene.findSceneVoiceUIDByName ( name: l12) //10/15 wups!
            alert.addAction(UIAlertAction(title: l12, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : uid,
                                      objType: "voice" ,asObject: asObject)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end addPipeStepTwo

    
    //=====<oogie2D mainVC>====================================================
    // 10/14 add asObject so we can use this to add pipes or scalars
    // 12/24 issShape -> objjType
    func addPipeStepThree(voice:OogieVoice , channel : String , destination : String , objType:String, asObject : String)
    {
        let alert = UIAlertController(title: "Choose " + objType + " Parameter", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //2/6 black text
        var menuNames = OSP.shapeParamNamesOKForPipe
        if objType == "voice" {menuNames = OVP.voiceParamNamesOKForPipe}
        for pname in menuNames
            {
                alert.addAction(UIAlertAction(title: pname, style: .default, handler: { action in
                    if asObject == "Pipe" //10/14
                    {
                        let ps = PipeStruct(fromObject: voice.OVS.uid, fromChannel: channel.lowercased(), toObject: destination, toParam: pname.lowercased())
                        self.addPipeToScene(ps: ps, op: "new")
                    }
                    else //10/18 handle scalar
                    {
                        let ss = ScalarStruct(toObject: destination, toParam: pname.lowercased())
                        self.addScalarToScene(scalarSS: ss, op: "new")
                    }
                }))
            }
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end addPipeStepThree
    
    //=====<oogie2D mainVC>====================================================
    // 12/29 add prompt flag
    func deletePipe(p:OogiePipe)
    {
        if appDelegate.promptForDeletes != 0 //12/29
        {
            let alert = UIAlertController(title: "Delete Selected Pipe?", message: "Pipe will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
            //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.shiftPanelDown(panel: self.pipeEditPanels)
                self.OVScene.deletePipeBy(uid: p.PS.uid) //9/25
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else
        {
            self.shiftPanelDown(panel: self.pipeEditPanels) //12/29 if selected
            self.OVScene.deletePipeBy(uid: self.OVScene.selectedPipe.PS.uid) //9/25
        }
    }  //end deletePipe
  
    //=====<oogie2D mainVC>====================================================
    // 12/29 add prompt flag, s arg
    func deleteScalar(s:OogieScalar)
    {
        if appDelegate.promptForDeletes != 0 //12/29
        {
            let alert = UIAlertController(title: "Delete Scalar?", message: "Scalar will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
            //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.shiftPanelDown(panel: self.scalarEditPanels)
                self.OVScene.deleteScalarBy(uid: s.SS.uid) //9/25
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else
        {
            self.shiftPanelDown(panel: self.scalarEditPanels) //12/29 if selected?
            self.OVScene.deleteScalarBy(uid: self.OVScene.selectedScalar.SS.uid) //9/25
        }
    }  //end deleteScalar
    
    //=====<oogie2D mainVC>====================================================
    // 12/29 add prompt flag
    func deleteVoice(v:OogieVoice)
    {
        if appDelegate.promptForDeletes != 0 //12/29
        {
            let tit   = "Delete voice " + v.OVS.name + "?"
            let alert = UIAlertController(title: tit, message: "Voice will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
            //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.shiftPanelDown(panel: self.voiceEditPanels)
                self.OVScene.deleteVoiceBy(uid: v.uid)  //12/5 use uid from incoming voice
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            }))
            self.present(alert, animated: true, completion: nil)
        }
        else
        {
            self.shiftPanelDown(panel: self.voiceEditPanels) //12/29 incase selected...
            self.OVScene.deleteVoiceBy(uid: v.uid)  //12/5 use uid from incoming voice
        }
    }  //end deleteVoice

    //=====<oogie2D mainVC>====================================================
    func dumpBuffers()
    {
        let d = allP.getBufferReport(); //returns dict of number/string combos
        print("dumpBUFFERS \(d)")
        var dstr = ""
        for i in 0..<MAX_SAMPLES
        {
            let nn = NSNumber(value:i)
            if let bn = d[nn]  //11/25 cleanup
            {
                let bsize = (sfx() as! soundFX).getBufferSize(Int32(i))
                if bsize > 0
                {
                    dstr = dstr + "[\(i)]:\(bsize): " + bn + "\n"  //11/25 cleanup
                }
            }
        }
       print(dstr)

    } //end dumpBuffers
    
    //=====<oogie2D mainVC>====================================================
    func clearScenePrompt()
    {
    let alert = UIAlertController(title: "Clear Current Scene?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
        alert.addAction(UIAlertAction(title: "Shape Only", style: .default, handler: { action in
            self.pLabel.updateLabelOnly(lStr:"Clear:Shape only")
            self.clearScene(withDefaultScene: true, noVoices:true)
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            self.pLabel.updateLabelOnly(lStr:"Clear:Normal")
            self.clearScene(withDefaultScene: true, noVoices:false)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end clearScenePrompt
    
    
    //=====<oogie2D mainVC>====================================================
    // 4/30 NOTE: this has a bug resetting the camera position!
    func clearScene(withDefaultScene addDefaultScene:Bool , noVoices:Bool)
    {
        OVScene.savingEdits = true //11/16 prevent data collisions during delete
        //9/28 NO panesl up please!
        shiftPanelDown(panel: voiceEditPanels)   //put away pipe editor
        shiftPanelDown(panel: shapeEditPanels)
        shiftPanelDown(panel: pipeEditPanels)
        shiftPanelDown(panel: scalarEditPanels)   //10/21
        piPanel.stopAnimation() //10/5

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
            self.OVScene.createDefaultScene(named: "default",noVoices:noVoices)  //12/7
            self.create3DScene(scene:scene) //  then create new scene from file
            #if VERSION_2D
            cameraNode.transform = SCNMatrix4Identity
            cameraNode.position  = SCNVector3(x:0, y: 0, z: 2) //10/26 AR coords only : closer in
            #endif
        }
        OVScene.savingEdits = false //11/16 prevent data collisions during delete

    } //end clearScene
    
    //=====<oogie2D mainVC>====================================================
    func clearAll3DNodes(scene:SCNScene)
    {
        oogieOrigin.enumerateChildNodes { (node, _) in //1/20 new origin
            //print("remove node \(node.name)")
            if (node.name != nil) {node.removeFromParentNode()}
        }
        OVScene.markers3D.removeAll() //4/28 new dict
        OVScene.shapes3D.removeAll()
        OVScene.pipes3D.removeAll()          //1/21 wups?
        OVScene.pipeUIDToName.removeAll()  //1/22
    } //end clearAll3DNodes
    
    
    //=====<oogie2D mainVC>====================================================
    // Assumes shapes already loaded..
    func create3DScene(scene:SCNScene)
    {
        //iterate thru dictionary of shapes...
        for (_, nextShape) in OVScene.OSC.shapes
            { addShapeToScene(shapeOSS: nextShape, op: "load") }
        //iterate thru dictionary of shapes...
        for (_, nextOVS) in OVScene.OSC.voices
            { addVoiceToScene(nextOVS: nextOVS,   op: "load") }
        //OK add pipes too
        for (_, nextPipe) in OVScene.OSC.pipes
            { addPipeToScene(ps: nextPipe, op: "load") }
        for (_, nextScalar) in OVScene.OSC.scalars    // 10/18 new scalars
            { addScalarToScene(scalarSS: nextScalar, op: "load") }
        pkeys          = PianoKeys() //make new 3d shape, texture it
        pkeys.isHidden = true //Hide for now
        oogieOrigin.addChildNode(pkeys)
        #if GOT_AXES
        //10/25 test add axes
        let axes = createAxes() //1/11/20 test azesa
        oogieOrigin.addChildNode(axes)
        #endif
        //12/17 make sure scalar values ripple downstream b4 starting
        let sceneChanges = self.OVScene.setupAllScalarDownstreamObjects()
        update3DSceneForSceneChanges(sceneChanges) //4/29
//        let tooob = toobbShape.createToob(sPos00:SCNVector3(0,0,0))
//        oogieOrigin.addChildNode(tooob)
        self.OVScene.sceneLoaded = true  //11/9 move to here
    } //end create3DScene
    
    
    var note : Int32 = 50
    var buf  : Int32 = 0
    var tnote : Int = 20
    //=====<oogie2D mainVC>====================================================
    @IBAction func testSelect(_ sender: Any) {
    } //end testSelect
    
    
    //====(OOGIECAM MainVC)============================================
    // 9/1/21 dump bufers, names, sizes
    func getBufferDump() -> String
    {
        print("dump buffers...");
        let D = allP.getBufferReport(); //returns dict of number/string combos
        var report = ""
        for i in 0...MAX_SAMPLES-1
        {
            let nn = NSNumber(value: i)
            if let bn = D[nn]
            {
                let bsize = (sfx() as! soundFX).getBufferSize(Int32(i))
                if bsize > 0
                {
                    report = report + "[\(i)]: \(bsize) ," + bn + "\n"
                }
            }
        }
        return report;
    } //end getBufferDump
    
    //=====<oogie2D mainVC>====================================================
    // 10/23 get fresh user samples, link to proper buffers
    //   should be called whenever user sample folder changes??
   func loadUserSamples()
    {
        let userSampleBase = appDelegate.userSampleBase //should point above canned samples
        if userSampleBase == 0 {return} //err check: no samples loaded yet
        if let userSampleFnames = (sfx() as! soundFX).loadSamplesNow("UserSamples" , Int32(userSampleBase))
        {
            var sampnum = userSampleBase
            for fname in userSampleFnames
            {
                if let fff = fname as? String
                {
                    let fnameParts = fff.split(separator: ".")
                    if (fnameParts.count >= 1)
                    {
                        //print("link user sample \(fff) to buf \(sampnum)")
                        allP.linkBufferToPatch(nn: NSNumber(value: sampnum), ss: fff)
                        sampnum = sampnum + 1
                    }
                }
            } //end for fname
        } //end let userSample..
     } //end loadUserSamples

    //=====<oogie2D mainVC>====================================================
    // 10/24 new
    func loadUserSamplesAndPatches()
    {
        allP.loadUserSoundPack()
        loadUserSamples()
        sendSoundPackAndSampleNamesToControls() //10/23
        //dumpBuffers()
    }
    
    //=====<oogie2D mainVC>====================================================
    @IBAction func test2Select(_ sender: Any) {

       startPlayingLoop(loopName:"teknoLoop001.wav")

    } //end test2select
    
    
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
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    //=====<oogie2D mainVC>====================================================
    func infoAlert(title:String , message : String)
    {
        let alert = UIAlertController(title: title, message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        //12/19 alert.view.tintColor = UIColor.black //lightText, works in darkmode
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
    // note loads default patch!
    //  NOTE patch edits are applied in add VoiceSceneData
    func addVoiceToScene(nextOVS : OVStruct ,  op : String)
    {
        //First, set up scene structures, get fresh voice back...
        let newVoice = OVScene.addVoiceSceneData(nextOVS : nextOVS , op:op )
        // use this voice and create the 3D marker
        OVScene.addVoice3DNode (voice:newVoice, op:op )
    } //end addVoiceToScene

    //=====<oogie2D mainVC>====================================================
    // 12/4 new for carpetbombing
    func addVoiceToSceneWithPatch(nextOVS : OVStruct ,  op : String , patchName: String)
    {
        //First, set up scene structures, get fresh voice back...
        var newVoice = OVScene.addVoiceSceneData(nextOVS : nextOVS , op:op )
        newVoice = loadPatchByNameToVoice (pName:patchName , ov:newVoice)
        // use this voice and create the 3D marker  12/11 new arg
        OVScene.addVoice3DNode (voice:newVoice, op:op )
    } //end addVoiceToSceneWithPatch

    //=====<oogie2D mainVC>====================================================
    // 10/13 add  scalar control object
    func addScalarToScene (scalarSS:ScalarStruct , op : String)
    {
        //ScalarShape cominb back as (shape:ScalarShape,pos3D:SCNVector3)
        let scalar     = OVScene.addScalarSceneData (scalarSS:scalarSS, op:op) //12/21 no 2nd arg now
        let scalarNode = OVScene.addScalar3DNode (scalar:scalar,newNode:true)
        oogieOrigin.addChildNode(scalarNode)  // Add shape node to scene
    } //end addScalarToScene
    

    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addShapeToScene (shapeOSS:OSStruct , op : String)
    {
        //9/26 remove key arg
        let psTuple = OVScene.addShapeSceneData (shapeOSS:shapeOSS, op:op , startPosition:startPosition)
        let sphereNode = OVScene.addShape3DNode (pst:psTuple)
        oogieOrigin.addChildNode(sphereNode)  // Add shape node to scene

    } //end addShapeToScene
    
    
    //=====<oogie2D mainVC>====================================================
    // 4/29 cleanup, peel off 3d part to separate method, data to OVScene
    func addPipeToScene(ps : PipeStruct , op : String)
    {
        if let oop = OVScene.addPipeSceneData(ps : ps ,  op : op) // 10/4 cleanup
        {
            // 1/22 split off 3d portion
            let pipeNode = OVScene.addPipe3DNode(oop : oop , newNode : true) //1/30
            oogieOrigin.addChildNode(pipeNode)  //1/20 new origin
        }
    } //end addPipeToScene
    
   
    
    //=====<oogie2D mainVC>====================================================
    // 11/24 load canned 3D pos back from where we got it!
    // BROKEN: sets position and rotation OK but orientation is a 4x4 and it isn't set!
    //  OUCH! do i have to save the entire 4x4?
    //  https://stackoverflow.com/questions/42029347/position-a-scenekit-object-in-front-of-scncameras-current-orientation
    func setCamXYZ()
    {
        if let pov = skView.pointOfView
        {
            print("setCamXYZ \(camXform)")
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
    // 10/9 pull setTimerSpeed case
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
                case "update3DShapeByKey": OVScene.update3DShapeBy(uid:key) //handle shape param change
                case "updatePipeTexture":  // update pipe texture motion
                    if let pipe3D = OVScene.pipes3D[key] //get 3D pipe handle
                    {
                        guard let pipe = OVScene.scenePipes[key] else {break} //also need pipe data handle
                        //let vals = pipe.ibuffer // get raw pipe input data...pass to 3D object
                        // 11/16 potential memory leak fixed?
                        pipe3D.updatePipeTexture( bptr : pipe.bptr) //11/16 translate texture now
                        //10/5 update selected pipe graphic display...
                        if whatWeBeEditing == "pipe"
                        {
                            selectedPipeShape.updateInfo(nameStr: OVScene.scenePipes[key]!.PS.name, //11/16/21
                                                         pinfo: pipe.getPipeInfo()) //10/6
//                             selectedPipeShape.updateInfo(nameStr: pipe3D.name!,
//                                                         pinfo: pipe.getPipeInfo()) //10/6
                        }
                    } //end pipe3D
                case "updateMarkerPosition":  // change a marker 3D position
                    if let marker = OVScene.markers3D[key]
                    {
                        guard let voice = OVScene.sceneVoices[key] else {break}
                        marker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
                } //end if let
                case "updatePipePosition":  //change a pipe 3D position
                    if let invoice = OVScene.sceneVoices[key]
                    {
                       OVScene.updatePipeByVoice(v:invoice) 
                    }
                case "updateMarkerRGB": // change marker color (3 xtra args)
                    if ops3D.count > 4  //got valid sequence? (op:key:r:g:b)
                    {
                        guard let rr = Int(ops3D[2]) else {break}  //get rgb ints
                        guard let gg = Int(ops3D[3]) else {break}
                        guard let bb = Int(ops3D[4]) else {break}
                        guard let marker3D = OVScene.markers3D[key] else {break}
                        //print("updatemarker \(rr) \(gg) \(bb)")
                        marker3D.updateRGBData(rrr: rr, ggg: gg, bbb: bb)
                    }
                case "updateMarkerPlayed":   // update marker played status?
                    if ops3D.count > 2      // got a 3rd data value?
                    {
                        let gotPlayed      = String(ops3D[2])   // get data from pipe
                        if OVScene.markers3D[key] != nil //12/25 avoid mem leaks
                        {
                            if gotPlayed != "0"
                            {
                                OVScene.markers3D[key]!.gotPlayed = true
                            }
                        }
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
    //11/19 moved back here from scene yet again
    @objc func updateAllMarkers()
    {
        OVScene.updateAllMarkers() //this calls methods which use NSTIMERs
    }
    
    
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
    // Menu / etc button bottom left
    @IBAction func buttonSelect(_ sender: Any) {
        //TEST  self.performSegue(withIdentifier: "patchVCSegue", sender: self) //10/24
        menu()
    } //end buttonSelect
    
    
    //=====<oogie2D mainVC>====================================================
    //11/30 for quick scene loads
    @IBAction func presetSelect(_ sender: Any)
    {
        let n = ["clones","default","infront","pipey","pipey2voice","s2s","triplet","twopipes"]
        let b : UIButton = sender as! UIButton
        let tag = b.tag
        print("preset \(tag)")
        OVSceneName = n[tag-1000]
        OVScene.savingEdits = true
        self.clearScene(withDefaultScene: true , noVoices:true )
        self.OVScene.sceneLoaded = false //5/7 add loaded flag
        do{  //12/3 add try/catch to all datamanager loads
            self.OVScene.OSC = try DataManager.loadScene(OVSceneName, with: OSCStruct.self)
        }
        catch{
            print("failure loading preset!");
        }
        finishSettingUpScene()   // finish 3d setup.. this may entail setting up a BAD SCENE!!?!?!?
        OVScene.savingEdits = false
    }
    
    
    
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
    func cancelledTextures()
    {
        startPlayingMusic() //11/29 turn on sound!
    }
    
    func gotTexture(name: String, tex: UIImage)
    {
        //stubbed for now
        //11/16 shapePanel needs to know about this!
        if whatWeBeEditing == "shape"  //11/16 update spanel if needed
        {
            sPanel.texNames  = tc.loadNamesToArray() //populates texture chooser
            sPanel.thumbDict = tc.thumbDict //10/28 texture thumbs
            sPanel.updateTextureDisplay()  
            sPanel.configureView()
        }
    }
    
    //perform scene bookkeeping, reload default texture where needed
    func deletedTexture(name: String)
    {
        if let ii = tc.defaultTexture  //11/15 add default to TC
        {
            for (key,shapeObj) in OVScene.sceneShapes //loop over all shape objects
            {
                if shapeObj.OOS.texture == name //match? Delete!
                {
                    shapeObj.OOS.texture = "default"
                    setNewTexture(uid:shapeObj.OOS.uid,name: "default",tex: ii)
                    OVScene.sceneShapes[key] = shapeObj //save object back too...
                }
            }
            if whatWeBeEditing == "shape" //11/16 update spanel if needed
            {
                sPanel.texture   = ii  //restore default texture
                sPanel.texNames  = tc.loadNamesToArray() //populates texture chooser
                sPanel.thumbDict = tc.thumbDict //10/28 texture thumbs
                sPanel.updateTextureDisplay()
                sPanel.configureView()
            }
        }
    } //end deletedTexture
    
    //---<chooserVCDelegate>--------------------------------------
    func chooserCancelled()
    {
        print("...chooser cancel")
        startPlayingMusic()  //10/24 redo
    }

    //---<chooserVCDelegate>--------------------------------------
    //Delegate callback from Chooser... 11/07 add args for more info
    // 12/3 redo to support try/catch
    func chooserChoseFile(name: String , path: String , fromCloud : Bool)
    {
        if chooserMode == "loadAllPatches"
        {
            //6/29/21 FIX! let ppp = allP.getPatchByName(name: name)
            //6/29/21 FIX! print("ppp \(ppp)")
        }
        else //load new scene?
        {
            var sceneError = false
            do{
                let tempScene = try DataManager.loadScene(name, with: OSCStruct.self)
                self.OVScene.sceneLoaded = false //5/7 add loaded flag
                self.clearScene(withDefaultScene: false, noVoices:false) //12/10
                OVSceneName      = name
                self.OVScene.OSC = tempScene
                finishSettingUpScene()   // finish 3d setup.. this may entail setting up a BAD SCENE!!?!?!?
            }
            catch{
                print("error loading \(name)")
                sceneError = true
            }
            if !sceneError //loaded ok, doublecheck file...
            {
                let sceneStatus = OVScene.validate() //double check
                if sceneStatus != "OK" { sceneError =  true }
            }
            if sceneError //bad file / not found ?
            {
                //BUG: somehow if there is an error the shape motors dont start up again!
                DispatchQueue.main.async { [self] in //err message needs to be in foreground thread
                    infoAlert(title:"Bad Scene" , message : "could not load scene:" + name)
                } //end dispatch
            }
        }
        startPlayingMusic()
        OVScene.savingEdits = false //11/16 prevent data collisions during delete
    } //end choseFile

    //---<chooserVCDelegate>--------------------------------------
    // 11/17 new delegate return w/ filenames from chooser
    func newFolderContents(c: [String])
    {
    }

    //---<chooserVCDelegate>--------------------------------------
    //Delegate callback from Chooser... 11/8 add toCloud
    func needToSaveFile(name: String , type: String, toCloud: Bool)
    {
        print("saveit \(name)  . . . type \(type)")
        if name.count > 1 //10/30 no nils/shorties!
        {
            if type == "saveSceneAs"
            {
                OVSceneName = name
                OVScene.OSC.name = name //5/11 forgot name!
                OVScene.packupSceneAndSave(sname:OVSceneName, saveit: true) //11/8
            }
            else if type == "savePatchAs" //10/31 save patch already
            {
                OVScene.selectedVoice.OOP.saveItem(filename : name , cat : "US") //test save patch to user area
                allP.loadUserPatches() //11/1 load into internal patch area...
            }
            pLabel.updateLabelOnly(lStr:"Saved " + OVSceneName)
        } //end name.count
        startPlayingMusic() //10/24 redo
    } //end needToSaveFile
    
    //=====<oogie2D mainVC>====================================================
    // 9/1/21, go for random patch...
    // BUG: doesnt seem to change patch BUT patch then gets stuck and cant load anything else??
    func loadRandomPatchToSelectedVoice()
    {
        let randV = self.OVScene.selectedVoice //10/27
        var bbot = appDelegate.externalSampleBase;   //10/27 assume sample space
        var btop = appDelegate.userSampleBase-1;
        if btop <= bbot {return} //10/27 handle no sample situation
        //print("RANDOM PATCH")
        let type = Int.random(in:0...3); //set up type first...
        randV.OOP.type = type
        randV.OVS.patchName = "Random" //11/29
        switch Int32(type)
        {
        case SAMPLE_VOICE:
            randV.loadRandomSamplePatch(builtinBase: bbot, builtinMax: btop,
                                                      purchasedBase: 0, purchasedMax: 0)
            //12/6 bad idea randV.OVS.name = "Dice:Sample"
        case SYNTH_VOICE: randV.loadRandomSynthPatch()
            (sfx() as! soundFX).buildEnvelope(Int32(randV.OOP.wave),true); //10/8 synth waves in bufs 0..4
            //12/6 bad idea randV.OVS.name = "Dice:Synth"
        case PERCUSSION_VOICE:
            bbot = appDelegate.percussionBase //10/27
            btop = appDelegate.percussionTop - 1
            randV.loadRandomPercPatch(builtinBase: bbot, builtinMax: btop)
            //12/6 bad idea randV.OVS.name = "Dice:Perc"
        case PERCKIT_VOICE :
            bbot = appDelegate.percussionBase //10/27
            btop = appDelegate.percussionTop - 1
            randV.loadRandomPercKitPatch(builtinBase: bbot, builtinMax: btop)
            randV.getPercLooxBufferPointerSet() //10/27
            //12/6 bad idea randV.OVS.name = "Dice:PercKit"
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
        
        pLabel.updateLabelOnly(lStr:randV.OVS.name)
        self.OVScene.selectedVoice = randV
        //let s = randV.dumpParams()
    } //end loadRandomPatchToSelectedVoice
    
    //=====<oogie2D mainVC>====================================================
    // 10/8 add shorthand, synth wave setup
    func loadPatchByName (pName:String)
    {
        if let oop = allP.patchesDict[pName]
        {
            //print("loadPatchByName: \(oop)")
            //let ovsel = self.OVScene.selectedVoice // 10/8 shorthand
            OVScene.selectedVoice.OOP = oop
            if OVSoundPack == "UserSamples" //1/1 make sure user samples detune
            {
                OVScene.selectedVoice.OVS.detune = 1
            }
            if let editDict = (paramEdits() as! edits).getForPatch(pName) //12/3 why unwrap error now?  10/1 apply any edits
            {
                OVScene.selectedVoice.applyEditsWith(dict: editDict) //modify voices patch to suit edits
            }
            let nn = allP.getSampleNumberByName(ss: oop.name)
            
            OVScene.selectedVoice.OVS.whichSamp = nn.intValue //10/1
            if OVScene.selectedVoice.OOP.type == PERCKIT_VOICE
            {
                OVScene.selectedVoice.getPercLooxBufferPointerSet() //go get buff ptrs...
            }
            //print("load patch \(pName),  buf \(nn)")
        }
    } //end loadPatchByName
    
    //=====<oogie2D mainVC>====================================================
    func loadPatchByNameToVoice (pName:String , ov : OogieVoice) -> OogieVoice
    {
        if let oop = allP.patchesDict[pName]
        {
            //print("loadPatchByName: \(oop)")
            //let ovsel = self.OVScene.selectedVoice // 10/8 shorthand
            ov.OOP = oop
            if let editDict = (paramEdits() as! edits).getForPatch(pName) //12/3 why unwrap error now?  10/1 apply any edits
            {
                ov.applyEditsWith(dict: editDict) //modify voices patch to suit edits
            }
            let nn = allP.getSampleNumberByName(ss: oop.name)
            
            ov.OVS.whichSamp = nn.intValue //10/1
            if ov.OOP.type == PERCKIT_VOICE
            {
                ov.getPercLooxBufferPointerSet() //go get buff ptrs...
            }
            //print("load patch \(pName),  buf \(nn)")
        }
        return ov
    } //end loadPatchByNameToVoice

    //=====<oogie2D mainVC>====================================================
    // 10/8 add shorthand, synth wave setup
    // DHS 11/22 LOOKS WRONG< does it save to scene? how does scene know it changed?
    func OLDloadPatchByName (pName:String)
    {
        if let oop = allP.patchesDict[pName]
        {
            print("loadPatchByName: \(oop)")
            let ovsel = self.OVScene.selectedVoice // 10/8 shorthand
            ovsel.OOP = oop
            // 12/3 why unwrap error now?
            if let editDict = (paramEdits() as! edits).getForPatch(pName) //10/1 apply any edits
            {
                ovsel.applyEditsWith(dict: editDict) //modify voices patch to suit edits
            }
            let nn = allP.getSampleNumberByName(ss: oop.name)
            ovsel.OVS.whichSamp = nn.intValue //10/1
            selectedMarker.updateTypeInt(newTypeInt : Int32(ovsel.OOP.type)) //10/4
            if ovsel.OOP.type == PERCKIT_VOICE
            {
                ovsel.getPercLooxBufferPointerSet() //go get buff ptrs...
            }
            print("load patch \(pName),  buf \(nn)")
        }
    } //end loadPatchByName

    //=====<controlPanelDelegate>====================================================
    func controlNeedsProMode() {
        print("controlNeedsProMode")
    }
    func didSelectControlDice() {
        //print("didSelectControlDice")
        pLabel.updateLabelOnly(lStr:"Dice: Voice") //9/18 info for user!
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
    func didSelectControlDelete() {   //10/21 new for dismiss button on panel
        self.deleteVoice(v:OVScene.selectedVoice) //12/5 new arg
        deselectAndCloseEditPanel()
    }
    //10/30 NOTE these are common to all panels!
    func didStartTextEntry(_ pname: String!) {
        pLabel.updateLabelOnly(lStr:"edit " + pname + ":")
    }
    func didChangeTextEntry(_ pstr: String!) {
        pLabel.updateLabelOnly(lStr: pstr )
    }
    
    //=====<controlPanelDelegate>====================================================
    //10/12 load synth buffers with the basic 5 wave types UP FRONT...
    // IS there a better place for this?
    // ONLY CALL THIS ONCE!
    func loadSynthBuffersWithCannedWaves()
    {
        for i in 0...4   //sine, saw,square,ramp,noise
        {
            (sfx() as! soundFX).buildaWaveTable(Int32(i),Int32(i));  //This could be dangerous!

        }
    } //end loadSynthBuffersWithCannedWaves
    
    //=====<controlPanelDelegate>====================================================
    //controlPanel delegate returns...  9/28 BUG: pvalue for patch param is wrong, points to prev item from selection
    //                                               ALSO pvalue is discarded, why pass it anyway???
     func didSetControlValue( _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         OVScene.savingEdits = true //11/23
         if pname == "patch" //new patch? 10/3 change toi string
         {
             if pvalue == "random"
             {
                 loadRandomPatchToSelectedVoice()
                 selectedMarker.updateTypeInt(newTypeInt : Int32(self.OVScene.selectedVoice.OOP.type)) //11/22
                 OVScene.sceneVoices[OVScene.selectedMarkerKey] =  self.OVScene.selectedVoice //11/22 ok saveit!
             }
             else
             {
                 if let ps = pvalue //unwrap our string...
                 {
                     loadPatchByName(pName: pvalue) //10/3
                     //11/22 moved here from loadPatchByName
                     selectedMarker.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))

                     OVScene.selectedVoice.OVS.patchName = ps  //9/30 wups forgot to save...
                     pLabel.updateLabelOnly(lStr:"patch:\(ps)") //10/12 add output
                 }
             } //end else not random
         } //end which 17
         // 10/12 add else here,
         else if pname == "soundpack" //9/11 handle new soundpack
         {
             OVSoundPack = allP.getSoundPackNameByIndex(index: Int(newVal));
             allP.getSoundPackByName(name: OVSoundPack)
             let patchName = allP.getSoundPackPatchNameByIndex(index: 0) // 10/28 just get first patch
             pLabel.updateLabelOnly(lStr:"cpack:\(OVSoundPack)") //10/12 add output
             loadPatchByName(pName: patchName)
             //11/22 moved here from loadPatchByName
             selectedMarker.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))
             //CREATE A NEW PATCH LIST....HMM this should be separate??
             var pnames = allP.getPatchNamesForSoundpack(spname: OVSoundPack) // 12/17
             pnames.insert("Random", at: 0)
             cPanel.paNames = pnames
             //Pack params, send to VC
             cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
             cPanel.configureView()
             cPanel.resetPatchPicker(1) // 10/28 try setting to top patch for now...
         }
         else   //Just regular control...
         {
             editParam(newVal,pname,pvalue,undoable) //12/15
             OVScene.sceneVoices[OVScene.selectedMarkerKey] = OVScene.selectedVoice //WOW STORE IN SCENE?
         } //end else
         OVScene.savingEdits = false //11/23

     } //end didSetControlValue


    //=====<scalarPanelDelegate>====================================================
    // 10/17 redid to handle  OVScene.loadCurrentShapeParams
    //  shit this is huge.  maybe break out?
    //KRASH in  voice detune
    func didSetScalarValue( _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        OVScene.savingEdits = true //12/2 prevent krashes?
        if pvalue == "value" //scalar value triggers live 3d response and changes another scene object
        {
            selectedScalarShape.startFadeout() //start scalar3D fade anim
            let paramTuple = OVScene.setNewScalarValue(sobj:OVScene.selectedScalar , value: Double(newVal) , pvalue : pvalue) //11/3 break out to method
            //let toObjName  = paramTuple.toobj
            let paramName  = paramTuple.param
            let dval        = paramTuple.val //12/19
            update3DSceneForSceneChanges(paramTuple.sceneChanges) //12/15 handle 3d updates
            OVScene.selectedScalar.SS.value = Double(newVal) //12/17 keep trak of value

            //let valueLabel : String = paramName + ":" + String(format: "%.2f", val)
            selectedScalarShape.updateIndicator(toObject: paramName,
                              value: CGFloat(newVal),dvalue: CGFloat(dval)) //12/19
            let s = String(format: "%@: %4.2f", paramName,dval)
            pLabel.updateLabelOnly(lStr: s) ///"\(paramName) :" + String(val))
        } //end if pvalue...
        else
        {
            editParam(newVal,pname,pvalue,undoable) //12/15
        }
        OVScene.savingEdits = false //11/25 prevent krashes?
    } //end didSetScalarValue

    // 10/15/21
    func didSelectScalarDice() {
        //print("didSelectScalarDice")
        pLabel.updateLabelOnly(lStr:"Dice: Scalar") //9/18 info for user!
    }
    func didSelectScalarReset() {
        pLabel.updateLabelOnly(lStr:"Reset Scalar") //9/18 info for user!
    }
    func didSelectScalarDismiss() {   //9/24 new for touch on editlabel in UI
        deselectAndCloseEditPanel()
    }
    func didSelectScalarDelete() {   //10/21 new for dismiss button on panel
        self.deleteScalar(s:self.OVScene.selectedScalar)
        deselectAndCloseEditPanel()
    }

    //=====<shapePanelDelegate>====================================================
    // 9/15 redid to handle  OVScene.loadCurrentShapeParams
    //  1/3/22 HORRIBLE error changing rotation speed
    func didSetShapeValue( _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        print("set shape value " + pname + " \(newVal) string\(pvalue)")
        OVScene.savingEdits = true //11/25 prevent krashes?
        if pname == "texture" //texture?  10/7 use string! 11/25 TEST
        {
            //call a delegate return here...
            if pvalue == "default"
            {
                if let ii = tc.defaultTexture  //11/15 add default to TC
                {
                    setNewTexture(uid: OVScene.selectedShapeKey, name: pvalue, tex: ii)
                    sPanel.texture = ii
                }
            }
            else if let ii = tc.texDict[pvalue] //10/7 try for texture
            {
                setNewTexture(uid: OVScene.selectedShapeKey, name: pvalue, tex: ii) //10/7
                sPanel.texture = ii
            }
            sPanel.updateTextureDisplay() //11/9 renamed method
        }
        else{ //normal param??
            editParam(newVal,pname,pvalue,undoable) //12/15
        }
        OVScene.savingEdits = false //11/25 prevent krashes?
    } //end didSetShapeValue
    
    //=====<shapePanelDelegate>====================================================
    func didSelectShapeDice() {
        //print("didSelectShapeDice")
        pLabel.updateLabelOnly(lStr:"Dice: Shape") //9/18 info for user!
    }
    func didSelectShapeReset() {
        pLabel.updateLabelOnly(lStr:"Reset Shape") //9/18 info for user!
    }
    func didSelectShapeDismiss() {   //9/24 new for touch on editlabel in UI
        deselectAndCloseEditPanel()
    }
    func didSelectShapeDelete() {   //10/21 new for dismiss button on panel
        self.deleteShape(s:OVScene.selectedShape) //12/10
        deselectAndCloseEditPanel()
    }

    //=====<pipePanelDelegate>====================================================
    // 9/15 redid to handle  OVScene.loadCurrentShapeParams
    func didSetPipeValue(  _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        editParam(newVal,pname,pvalue,undoable) //12/15
        if pname == "name" //11/16 update pipe info on name change
        {selectedPipeShape.updateInfo(nameStr: pvalue,
                                      pinfo: OVScene.selectedPipe.getPipeInfo())}
    }
    func didSelectPipeDice() {  // 9/18/21
        //print("didSelectPipeDice")
        pLabel.updateLabelOnly(lStr:"Dice: Shape") //9/18 info for user!
    }
    func didSelectPipeReset() {
        //print("didSelectPipeReset")
        pLabel.updateLabelOnly(lStr:"Reset Shape") //9/18 info for user!
    }
    func didSelectPipeDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectPipeDismiss")
        deselectAndCloseEditPanel()
    }
    func didSelectPipeDelete() {   //10/21 new for dismiss button on panel
        self.deletePipe(p:self.OVScene.selectedPipe)
        deselectAndCloseEditPanel()
    }
    func needPipeDataImage() {   //10/5
        piPanel.setDataImage(selectedPipeShape.dataImage) //update panel!
    }

    //=====<oogie2D mainVC>====================================================
    // 9/24 deselects 3D shape and closes open panel; relies on whatWeBeEditing!
    func deselectAndCloseEditPanel ()
    {
        if whatWeBeEditing == "scalar" //10/15 new
        {
            selectedScalarShape.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: scalarEditPanels)
        }
        if whatWeBeEditing == "shape"
        {
            selectedSphere.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: shapeEditPanels)  //9/24  put away voice editor
        }
        else if whatWeBeEditing == "pipe"
        {
            selectedPipeShape.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: pipeEditPanels)  //9/24  put away voice editor
            piPanel.stopAnimation() //10/5
        }
        else if whatWeBeEditing == "voice" || whatWeBeEditing == "patch"  //10/3
        {
            selectedMarker.toggleHighlight()   //handle 3D update
            shiftPanelDown(panel: voiceEditPanels)  //9/24  put away voice editor
        }
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
    // 12/13 test not used yet
    func didSelectDown()
    {
        //print("shift down?")
    }

    //=====<settingsVCDelegate>====================================================
    //11/21
    func settingsVCChanged()
    {
        OVtempo = appDelegate.masterTempo;
        OVScene.liveMarkers = appDelegate.liveMarkers //11/29
        //print("svc changed tempo \(OVtempo)")
        for (_,shape) in OVScene.sceneShapes
        {
            shape.setRotationTypeAndSpeed() //pass new tempo down to shapes...
        }
        //11/22 NOTE this is only set for runtime, doesnt get saved!
        showStatistics = setVC.showStatistics
        skView!.showsStatistics = showStatistics
        appDelegate.verbose = setVC.verbose  //12/9 add verbsoe
        OVScene.verbose = setVC.verbose
    } //end settingsVCChanged
    // 12/12 handle factory reset
    func didResetSettingsVC()
    {
        (paramEdits() as! edits).factoryReset()      // delete patch edits
        appDelegate.copyFactoryScenesToDocuments()  // restore factory scenes
    }
    // start playing music again on dismissal of settings
    func didDismissSettingsVC() {
        startPlayingMusic()
    }

    //=====<samplesVCDelegate>====================================================
    func didDismissSamplesVC(_ changed: Bool) {
        //print("dismiss samplesVC...")
        startPlayingMusic()
    }
    func didRenameSample(_ oldName: String!, _ newName: String!, _ lookup: NSNumber!)
    {
        print("didRenameSample...")
        //11/26 handle internal buffer -> sample linkage
        allP.linkBufferToPatch(nn: lookup, ss: newName)
        allP.unlinkOldBufferByName(ss: oldName)
        sVC.patLookups = allP.patLookups //send new lookups back to VC...
    }

    //=====<patchVCDelegate>====================================================
    // 12/20 this is for editing a working patch!
    //   note param conversion is handled HERE to keep it quick
    func patchVCChangedWorkPatch( _ pname: String!, _ newVal: Float, _ newValString: String!)
    {
        print("patchVCChangedWorkPatch...  " + pname + " val: \(newVal) " + newValString)
        
        var convertedValue = Double(newVal)
        if ["sampleoffset","plevel","pkeyoffset","pkeydetune"].contains(pname) //12/20
        {
            convertedValue = 100.0 * Double(newVal)  // percent parms 0...100
        }
        else if !["type","wave"].contains(pname) //need conversion?
        {
            convertedValue = 255.0 * Double(newVal)  //most patch params are 0...255 ranged
        }        
        workPatch.setParam(named: pname, toDouble: convertedValue, toString: newValString)
        
        let d = workPatch.getParamDict()
        pVC.paramDict = workPatch.getParamDict()  //load params THE LONG WAY back to pVC
        if let na = d["name"]
        {
            print("na \(na)")
        }
        
    }
    
    //NOTE: the patchVC needs to be all assembled and displayed BEFORE any
    // fields can be setup with patch names, etc!
    func patchVCDidAppear()
    {
        
        
        print("patchVCDidAppear... refresh w new data???")
        pVC.spNames     = allP.allSoundPackNames
        pVC.sampleNames = allP.getGMPercussionNames()
        pVC.patLookups  = allP.patLookups  //12/20
        pVC.configureView()
        
        if patchToEdit != "" //12/30
        {
            let spname  = allP.getSoundPackNameByPatchName(pname: patchToEdit)
            if spname != "" {pVC.paNames  = allP.getPatchNamesForSoundpack(spname: spname)}
            patchVCDidSetPatch( patchToEdit)
            pVC.setPatchAndPackPickersFor(patchToEdit, spname)
        }
        else
        {
            pVC.paNames     = allP.getPatchNamesForSoundpack(spname: OVSoundPack) //12/17
        }
         
    }
    

    func patchVCDidSetPatch(_ paname: String!) 
    {
//        if allP.patchesDict[paname] != nil{
//            workPatch = allP.patchesDict[paname]!
//            workPatch.attack = 123
//        }
        //need to go load a patch and send paramsDict to patchVC
        if let oop = allP.patchesDict[paname] //try for patch...
        {
            workPatch = oop.copy() as! OogiePatch //NOTE WE NEED A COPY HERE!
            //as it is, the patchesDict keeps getting changed with each edit!
            
            if let editDict = (paramEdits() as! edits).getForPatch(paname)
            {
                workPatch.applyEditsWith(dict: editDict) //modify patch to suit edits
            }

            pVC.paramDict = workPatch.getParamDict()  //load params to pVC
            pVC.configureView()
        }
    }
    func patchVCDidSetPack(_ spname: String!) 
    {
        //need to go load a soundpack / patch and send paramsDict to patchVC
        let pnames = allP.getPatchNamesForSoundpack (spname : spname)
        pVC.paNames = pnames
        pVC.configureView()

    }
    func didDismissPatchVC()
    {
        startPlayingMusic()
    }
    func didResetPatchVC()
    {
        
    }

    
} //end vc class, line 1413 as of 10/10

