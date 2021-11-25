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
//  10/4   update marker3D icon in loadPatch
//  10/7   add selectObjectMenu
//  10/8   synth waves now stored in buffers 0..4
//  10/11  add sceneStatus error info on bad scene loads
//  10/12  pull xtra calls to startLoop, add loadSynthBuffersWithCannedWaves
//          pull knob, synthPanel
//  10/14  add asobject arg to addpipeStepTwo/Three
//  10/20  finish scalar debugging for voice
//  10/20  hook up scalars to shape/voice menu ,move solo voice id out to scene
//  10/21  add deleteScalarBy , cleanup deletePipeBy, cleanup delete prompts
//           add scalar from main meni
//  10/23  add scalar to select, also sendSoundPackAndSampleNamesToControls
//  10/24  add, loadUserSamplesAndPatches external samples now work
//           redo stopPlayingMusic,etc
//  10/28  redo longpress, colorpack / patch handling
//  10/30  add name check needToSaveFile, didStartTextEntry,didChangeTextEntry
//  10/31  put back updateActivity call in updateAllMarkersAndSpinShapes (wups)
//         add patch save to needToSaveFile
//  11/1   shorten rand patch naming
//  11/3   add handleDice and setNewScalarValue, randomize scalars now
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
import UIKit
import SceneKit
import Photos

let pi    = 3.141592627
let twoPi = 6.2831852

//Scene unpacked params live here for now...
var OVtempo = 135 //Move to params ASAP
var camXform = SCNMatrix4()

class ViewController: UIViewController,UITextFieldDelegate,TextureVCDelegate,chooserDelegate,UIGestureRecognizerDelegate,SCNSceneRendererDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,settingsVCDelegate,
                      controlPanelDelegate,patchPanelDelegate,scalarPanelDelegate,shapePanelDelegate,pipePanelDelegate{

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

    var colorTimer = Timer()
    var pLabel = infoText()
    //10/29 version info (mostly for debugging)
    var version = ""
    var build   = ""
    var touchLocation = CGPoint()
    var touchNodeUID = ""  //11/18 track what was touched...
    var touchDragDistance = 0 //11/16
    var startTouch    = UITouch()
    var latestTouch   = UITouch()
    var chooserMode = ""
    var shouldNOTUpdateMarkers = false
    var oldvpname = ""; //for control value changes
    var updatingPipe = false
    var updatingScalar = false   //10/20 new for scalars

    var showStatistics = false

    //12/2 haptics for wheel controls
    var fbgenerator = UISelectionFeedbackGenerator()
    var cPanel  = controlPanel()

    var paPanel = patchPanel()
    var sPanel  = shapePanel()
    var scPanel = scalarPanel()
    var piPanel = pipePanel()
    
    var sVC = samplesVC()
    var setVC = settingsVC()
    
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
    // 3D objects
    var cameraNode        = SCNNode()
    let scene             = SCNScene()
    var selectedMarker    = Marker(newuid:"empty")
    var selectedSphere    = SphereShape(newuid:"empty")
    var selectedPipeShape = PipeShape()   //11/30
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
//        camXform.m43 = 6.0   //5/1 back off camera on z axis
        //Get our default scene, move to appdelegate?
        // OK we are getting path name, but WHY not loaded??
        // PROBLEM: a lot of patches may get loaded into voices, but
        //  NONE of the buffer pointers are OK.  THIS NEEDS TO BE RECTIFIED!
        if DataManager.sceneExists(fileName : "default")
        {
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            self.OVScene.OSC = DataManager.loadScene("default", with: OSCStruct.self)
            self.OVScene.OSC.unpackParams()       //DHS 11/22 unpack scene params
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
        let pwh    : CGFloat   = 40 //11/13 shrink a bit
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

        //11/13 record button
        //11/13 record button
        pRect = CGRect(x: viewWid - pwh - xyinset  , y: xyinset, width: pwh, height: pwh) //11/13 rec button
        recButton.frame = pRect
        recButton.layer.cornerRadius = pwh*0.5  //11/13
        recButton.isHidden = false

        resetButton.isHidden = true  //no reset for now

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
        
        //Sept 28 NEW top label!
        pLabel = infoText(frame: CGRect(x: 0,y: 32,width: viewWid,height: 80))
        pLabel.frame = CGRect(x: 0 , y: 32, width: 375, height: 80)
        self.view.addSubview(pLabel)
        pLabel.infoView.alpha = 0 //Hide label initially

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
        print("STARTLOOP Should ONLY HAPPEN ONCE!")
        OVScene.startLoop()
        loadSynthBuffersWithCannedWaves() //10/12 one-time synth wave load

    } //end viewDidLoad
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //10/24 load any user sample changes
        loadUserSamplesAndPatches()
        testButton.isHidden  = true
        test2Button.isHidden = true
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
    //MARK: - UILongPressGestureRecognizer Action -
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer)
    {
        //print("Longperss")
        var haltVoices = false
        if gestureReconizer.state != UIGestureRecognizer.State.ended {
            let pp = gestureReconizer.location(ofTouch: 0, in: self.view)
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
            case "updatevoicescalar":  // voice moved with scalar?
                if !updatingScalar { updateScalarBy(voice:OVScene.selectedVoice) }
            case "updateshape":  // Shape changed/moved?
                OVScene.update3DShapeBy(uid:OVScene.selectedShapeKey)
            case "updateshapename":  // Shape name/comment changed?
                selectedSphere.updatePanels(nameStr: OVScene.selectedShape.OOS.name,
                                               comm: OVScene.selectedShape.OOS.comment)
            case "updaterotationtype":  // Change rotation type?
                setRotationTypeForSelectedShape()
            case "updateshapepipe":  // shape with Pipe moved?
                updatePipeByShape(s:OVScene.selectedShape)
            case "updateshapescalar":  // shape with Pipe moved?
                 updateScalarBy(shape:OVScene.selectedShape) 
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
        if knobMode == "edit" {cancelEdit()}  //5/3 Editing? Not any more!
        stopPlayingMusic()
        if segue.identifier == "textureSegue" {
            if let nextViewController = segue.destination as? TextureVC {
                nextViewController.delegate = self
            }
        }
        // 11/4 add scene chooser
        else if segue.identifier == "chooserLoadSegue"  || segue.identifier == "chooserSaveSegue"
        {
            // 9/28 note if we dont get fresh copy of chooser, the mode doesnt stick!!
            chooser = segue.destination as! chooserVC  //9/28 declare chooser at init
            chooser.delegate = self
            chooser.mode     = chooserMode
        }
        else if segue.identifier == "samplesVCSegue"
        {
        }
        else if segue.identifier == "settingsVCSegue"
        {
            setVC = segue.destination as! settingsVC  //9/28 declare chooser at init
            setVC.showStatistics = showStatistics
            setVC.delegate = self
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
         if      whatWeBeEditing == "voice"  {ptype = OVP.getParamType(pname: pname)}
         else if whatWeBeEditing == "scalar" {ptype = OScP.getParamType(pname: pname)} //10/16 scalar
         else if whatWeBeEditing == "shape"  {ptype = OSP.getParamType(pname: pname)}
         else if whatWeBeEditing == "pipe"   {ptype = OPP.getParamType(pname: pname)}
         else if whatWeBeEditing == "patch"  {ptype = OPaP.getParamType(pname: pname)} // 9/30

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
             if      whatWeBeEditing == "voice"  {OVScene.loadCurrentVoiceParams()}
             else if whatWeBeEditing == "scalar" {OVScene.loadCurrentScalarParams()}
             else if whatWeBeEditing == "shape"  {OVScene.loadCurrentShapeParams()}
             else if whatWeBeEditing == "pipe"   {OVScene.loadCurrentPipeParams()}
             else if whatWeBeEditing == "patch"  {OVScene.loadCurrentPatchParams()} //9/30 new
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
        // 9/27 wups, save back to scene!!!
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
                //10/20 good chance scalars need updating too!
                updateScalarBy(voice: v)
               }
        }
        //Get all incoming pipes to shape, update positions
        for puid in s.inPipes { updatePipeByUID(puid) }
        updatingPipe = false
    } //end updatePipeByShape
    
    //=======>ARKit MainVC===================================
    // broke out from updatePipeByVoice 5/2  only should be called if we are selected!!!
    func updatePipeByUID(_ puid:String)
    {
        if let pipeObj = OVScene.scenePipes[puid]           //   find pipe struct
        {
            let _ = OVScene.addPipe3DNode(oop: pipeObj, newNode : false) //1/30
            //let vals = pipeObj.ibuffer //11/28 want raw unscaled here!
            if let pipe3D = OVScene.pipes3D[puid]    // get Pipe 3dobject itself to restore texture
            {
               // print("texture pipe \(pipeObj.bptr) \(vals) ")
                // 11/16 potential memory leak fixed?
                pipe3D.updatePipeTexture( bptr : pipeObj.bptr) //11/16 translate texture now
            }
        }
    } //end updatePipeByUID
    
      //=======>ARKit MainVC===================================
      //10/20 new , update scalar if voice lat/lon changes
      func updateScalarBy(voice:OogieVoice)
      {
          if updatingScalar {return}
          updatingScalar = true
          //Get all incoming scalars from voice, update positions
          for puid in voice.inScalars { updateScalarBy(uid:puid) }
          updatingScalar = false
      } //end updateScalarByVoice


    

    //=======>ARKit MainVC===================================
    // 10/19 sometimes scalars must move...
    func updateScalarBy(uid:String)
    {
        if let scalarObj = OVScene.sceneScalars[uid]    //   find scalar struct
        {
            let _ = OVScene.addScalar3DNode(pst: (shape:scalarObj,pos3D:SCNVector3(x:0, y: 0, z: 0)), newNode : false)
        }
    } //end updateScalarBy uid
    
    
    //=======>ARKit MainVC===================================
    // 10/26 new
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

    //=======>ARKit MainVC===================================
    // Used to select items in the AR 3D world...
    // 11/18 keep track of node that was hit too!
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        startTouch    = touch
        touchLocation = startTouch.location(in: skView) //10/15 change name
        //print("start touch \(startTouch.location(in: skView))")
        touchDragDistance = 0
        //11/18 get node that was touched...
        guard let nodeHitTest = skView.hitTest(startTouch.location(in: skView) , options: nil).first else {return}
        let hitNode  = nodeHitTest.node
        if let uid = hitNode.name { touchNodeUID = uid } //11/18 save uid for later...
    } //end touchesBegan

    //=======>ARKit MainVC===================================
    // 10/17 there isnt a real double-tap detector, so instead
    //  we will use touchesMoved to put up a popup for the marker...
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        latestTouch = touch
        //print("touchesmoved...\(latestTouch)")
        guard let sceneView   = skView else {return}
        let t1 = latestTouch.location(in: sceneView)
        let t2 = latestTouch.previousLocation(in: sceneView)
        let dx = t1.x - t2.x
        let dy = t1.y - t2.y
        touchDragDistance = touchDragDistance + Int(sqrt(dx*dx + dy*dy))  //11/16
        
        if touchNodeUID.contains("scalar")  //dragging over scalar? check for up/down
        {
            if OVScene.sceneScalars[touchNodeUID] != nil
            {
                OVScene.savingEdits = true
                let dvert =  touchLocation.y - t1.y // in pixels
                let teensybit = Double(dvert) * 0.001
                let newValue = min(1.0,max(0.0,OVScene.sceneScalars[touchNodeUID]!.value  + teensybit))
                //ok this is the same as in setScalarValue from scalarPanel
                selectedScalarShape.startFadeout() //start scalar3D fade anim
                let paramTuple = setNewScalarValue(sobj:OVScene.sceneScalars[touchNodeUID]! , value: Double(newValue) , pvalue : "")
                let toObjName  = paramTuple.toobj
                let paramName  = paramTuple.param
                let val        = paramTuple.val
                OVScene.sceneScalars[touchNodeUID]!.value = Double(newValue) //11/18 keep trak of value

                //FIX THIS TOO, need to get converted value from setNewScalarValue
                let valueLabel : String = paramName + ":" + String(format: "%.2f", val)
                //Assume 3d object exists!!!
                if OVScene.scalars3D[touchNodeUID] != nil
                {
                    OVScene.scalars3D[touchNodeUID]!.updateIndicator(with: valueLabel, value: CGFloat(newValue))
                    OVScene.scalars3D[touchNodeUID]!.updateLabel(with: toObjName)
                }
                OVScene.savingEdits = false
                let s = String(format: "%@: %4.2f", paramName,val)
                pLabel.updateLabelOnly(lStr: s) ///"\(paramName) :" + String(val))
            }
        }

        //better only have one here!
//        for key in OVScene.sceneScalars.keys
//        {
//            if var scalar = OVScene.sceneScalars[key]
//            {
//               scalar.handleTouch(t1:t1 , t2:t2)
//           }
//        }
        //11/16 was here, moved to touchesEnded... getCamXYZ() //11/24 Save new 3D cam position
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
        var selected = false //9/25
        var gotdice  = false
        if let uid = hitNode.name //9/25 use uid not name now...
        {
            //\]print("hitnode \(uid)")
            if uid.contains("dice") //11/3 handle various dice
            {
                gotdice = handleDice(uid:uid)
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
            else if uid.contains("scalar") //Found a pipe? get which one
            {
                print("BING hit scalar")
                selected = selectOrDeselectScalarBy(uid:uid)
            }
        }     //end let name
        if !selected && !gotdice
        {
            cancelEdit() //DHS 11/3 if editing, cancel
            whatWeBeEditing = ""
        }
    } //end handleTouch
    
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
                if OVScene.scalars3D[luid] != nil //find scalar shape by UID for animation updates
                {
                    let paramTuple = setNewScalarValue(sobj:OVScene.sceneScalars[luid]! , value: newVal , pvalue : "") //11/3 break out to method
                    let toObjName  = paramTuple.toobj
                    let paramName  = paramTuple.param
                    let val        = paramTuple.val
                    //FIX THIS TOO, need to get converted value from setNewScalarValue
                    let valueLabel : String = paramName + ":" + String(format: "%.2f", val)
                    OVScene.scalars3D[luid]!.updateIndicator(with: valueLabel, value: CGFloat(newVal))
                    OVScene.scalars3D[luid]!.updateLabel(with: toObjName)
                    OVScene.scalars3D[luid]!.animateDiceSelect() //11/4 indicate dice was hit
                    let s = String(format: "%@: %4.2f", paramName,val)
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
                        OVScene.sceneShapes[luid]!.OOS.uScale = usc
                        OVScene.sceneShapes[luid]!.OOS.vScale = vsc
                        OVScene.sceneShapes[luid]!.OOS.uCoord = uco
                        OVScene.sceneShapes[luid]!.OOS.vCoord = vco
                        OVScene.shapes3D[luid]!.setTextureScaleAndTranslation(xs: Float(usc), ys: Float(vsc),
                                                               xt: Float(uco), yt: Float(vco) )
                        OVScene.sceneShapes[luid]!.bmp.setScaleAndOffsets(
                            sx: usc, sy: vsc, ox: uco, oy: vco)
                        OVScene.shapes3D[luid]!.animateDiceSelect() // indicate dice was hit
                        pLabel.updateLabelOnly(lStr: "Dice: Shape Texture")
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
                OVScene.selectedVoice = v
                let rPatchName = allP.getRandomPatchName()
                loadPatchByName(pName: rPatchName)

                //11/22 moved here from loadPatchByName
                //WRONG: find appropriate marker and update its icon here!!!
                print("need to update marker icon!!")
                loadRandomPatchToSelectedVoice() //can it be this easy??? control panel needs update too?

                if OVScene.markers3D[luid] != nil
                {
                    print("new type \(OVScene.selectedVoice.OOP.type)")
                    OVScene.markers3D[luid]!.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))
                }
                cPanel.paramDict = OVScene.selectedVoice.getParamDictWith(soundPack: OVSoundPack)
                cPanel.configureView()
                if let mshape = OVScene.markers3D[luid]
                {
                    mshape.animateDiceSelect() //11/11 indicate dice was hit
                }
                OVScene.sceneVoices[luid] = OVScene.selectedVoice; //11/22 save new voice back...
            }
            if needToSaveTemp  { OVScene.selectedVoice = tempVoice } //restore old selected voice
        } //end if voice
        OVScene.savingEdits = false //11/25
        return false
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
                        self.pLabel.updateLabelOnly(lStr:"Selected " + smname)
                        selectedMarker.updatePanels(nameStr: smname) //10/4 fix
                    }
                    OVScene.selectedVoice     = testVoice //Get associated voice for this marker
                    OVScene.selectedMarkerKey = uid      //points to OVS struct in scene
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
                
                self.pLabel.updateLabelOnly(lStr:"Selected " + self.selectedScalarShape.name!)
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
                    let tn = OVScene.selectedShape.OOS.texture
                    var ii = tc.defaultTexture  //11/15 add default to TC
                    if tn != "default" {ii = tc.texDict[tn]}
                    sPanel.texture = ii
                    sPanel.thumbDict = tc.thumbDict //10/28 texture thumbs
                    sPanel.configureView() //9/12 loadup stuff
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
                    self.pLabel.updateLabelOnly(lStr:"Selected " + spo.PS.name)
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
    // MAIN CHOICE menu, appears LH side as a MENU button
    func menu()
    {
        let tstr = "oogie2D" //"Menu (V" + version + ")"
        // 11/25 add big dark title
        let attStr = NSMutableAttributedString(string: tstr)
        attStr.addAttribute(NSAttributedStringKey.font, value: UIFont.boldSystemFont(ofSize: 25), range: NSMakeRange(0, attStr.length))
        let alert = UIAlertController(title: tstr, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.setValue(attStr, forKey: "attributedTitle")
        alert.view.tintColor = UIColor.black //lightText, works in darkmode

        //ADD MAIN MENU OPTIONS BELOW HERE....
        //Should tiffie and senes go together?
        alert.addAction(UIAlertAction(title: "Load Scene...", style: .default, handler: { action in
            self.chooserMode = "loadScene"
            self.performSegue(withIdentifier: "chooserLoadSegue", sender: self)
        }))
//9/28 no tiffie for now
//        alert.addAction(UIAlertAction(title: "Load TIFFIE...", style: .default, handler: { action in
//            self.chooseImageForSceneLoad() ///5/11 new kind of scene storage!
//        }))
        // Reset camera to see all scene, normalize camera tilt perpendicular to XZ plane
        alert.addAction(UIAlertAction(title: "Reset Camera", style: .default, handler: { action in
            self.resetCamera()
        }))
        alert.addAction(UIAlertAction(title: "Save Scene", style: .default, handler: { action in
            self.OVScene.packupSceneAndSave(sname:self.OVSceneName, saveit: true) //11/8
            self.pLabel.updateLabelOnly(lStr:"Saved " + self.OVSceneName)
        }))
        alert.addAction(UIAlertAction(title: "Save Scene As...", style: .default, handler: { action in
            self.chooserMode = "saveSceneAs" //9/28
            self.performSegue(withIdentifier: "chooserSaveSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Save Patch As...", style: .default, handler: { action in
            self.chooserMode = "savePatchAs" //10/31
            self.performSegue(withIdentifier: "chooserSaveSegue", sender: self)
        }))
//9/28 no tiffie for now
//        alert.addAction(UIAlertAction(title: "Save TIFFIE...", style: .default, handler: { action in
//            self.packupAndSaveTiffie() ///5/11 new kind of scene storage!
//        }))
        alert.addAction(UIAlertAction(title: "Clear Scene...", style: .default, handler: { action in
            self.clearScenePrompt()
        }))
        // 10/21 add scalar from main menu to shape or voice
        alert.addAction(UIAlertAction(title: "Add Scalar...", style: .default, handler: { action in
            self.addPipeStepTwo(voice:self.OVScene.selectedVoice, channel : "", asObject : "Scalar")
        }))
        alert.addAction(UIAlertAction(title: "Textures...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "textureSegue", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Samples...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "samplesVCSegue", sender: self) //10/24
        }))
        alert.addAction(UIAlertAction(title: "Toggle Piano KB", style: .default, handler: { action in
            self.updatePkeys() //3/30 update kb if needed
            self.pkeys.isHidden = !self.pkeys.isHidden
        }))
        alert.addAction(UIAlertAction(title: "Select...", style: .default, handler: { action in
            self.selectObjectMenu()
        }))
        alert.addAction(UIAlertAction(title: "Toggle Verbose", style: .default, handler: { action in
            self.toggleVerbose()
        }))
        alert.addAction(UIAlertAction(title: "Dump Scene...", style: .default, handler: { action in
            let s = self.OVScene.getCurrentSceneDumpString()
            print(s)
            self.infoAlert(title:"oogie scene dump" , message : s)
            self.dumpBuffers()
        }))
        alert.addAction(UIAlertAction(title: "Settings...", style: .default, handler: { action in
            self.performSegue(withIdentifier: "settingsVCSegue", sender: self) //10/24
        }))
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
        alert.view.tintColor = UIColor.black //lightText, works in darkmode
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
        // 10/23 add scalar select
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
    // 11/3 add to find bugs in pipe...
    func toggleVerbose()
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.verbose = !appDelegate.verbose //10/12 toggle debug output
        OVScene.verbose = appDelegate.verbose
        
    }
    
    //=====<oogie2D mainVC>====================================================
    // voice popup... various functions
    func voiceMenu(v:OogieVoice)
    {
        let alert = UIAlertController(title: v.OVS.name, message: nil, preferredStyle: UIAlertControllerStyle.alert)

            alert.addAction(UIAlertAction(title: "Edit this Patch...", style: .default, handler: { action in
                self.performSegue(withIdentifier: "EditPatchSegue", sender: self)
        }))
        alert.view.tintColor = UIColor.black //2/6 black text

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
        }))

        tstr = "Mute"
        if v.muted {tstr = "UnMute"}
        alert.addAction(UIAlertAction(title: tstr, style: .default, handler: { action in
            var muted = v.muted
            muted = !muted
            v.muted = muted
            self.selectedMarker.toggleHighlight()
        }))
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: v.OVS, op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete...", style: .default, handler: { action in
           self.deleteVoicePrompt()
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
        alert.addAction(UIAlertAction(title: "Add Scalar", style: .default, handler: { action in
            self.addPipeStepThree(voice: v, channel: "" , //10/20 add scalar to this voice
                                  destination : self.OVScene.selectedMarkerKey ,
                                  isShape: false ,asObject: "Scalar")
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
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Pipe...", style: .default, handler: { action in
            self.deletePipePrompt()
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
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Scalar...", style: .default, handler: { action in
            self.deleteScalarPrompt()
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
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Clone", style: .default, handler: { action in
            self.addShapeToScene(shapeOSS: s.OOS, op: "clone")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            self.deleteShapePrompt() //10/21 redo
        }))
        alert.addAction(UIAlertAction(title: "Add Voice", style: .default, handler: { action in
            self.addVoiceToScene(nextOVS: self.OVScene.selectedVoice.OVS,  op: "new")
        }))
        alert.addAction(UIAlertAction(title: "Add Scalar", style: .default, handler: { action in
            self.addPipeStepThree(voice: self.OVScene.selectedVoice, channel: "" , //10/20 add scalar to this shape
                                  destination : s.OOS.uid , //was selectedShapeKey
                                  isShape: true ,asObject: "Scalar")
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .default, handler: { action in
            self.OVScene.resetShapeByKey(key: s.OOS.key)  //Reset shape object from scene
            self.OVScene.update3DShapeBy(uid:s.OOS.uid)  //9/27 Ripple change thru to 3D
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end shapeMenu

   
    //=====<oogie2D mainVC>====================================================
    // 10/21 pull arg
    func deleteShapePrompt()
    {
        //print("Delete Shape:\(self.OVScene.selectedShape.OOS.name)")
        let alert = UIAlertController(title: "Delete Selected Shape?", message: "Shape will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.shiftPanelDown(panel: self.shapeEditPanels)
            self.OVScene.deleteShapeBy(uid: self.OVScene.selectedShapeKey)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteShapePrompt
    
    
    //=====<oogie2D mainVC>====================================================
    // spawns a series of other stoopid submenus, until there is a smart way
    //    to do it in AR.  like point at something and select?????
    //  Step 1: get output channel, Step 2: pick target , Step 3: choose parameter
    func addPipeStepOne(voice:OogieVoice)
    {
        let alert = UIAlertController(title: "Choose Pipe Output Channel", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
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
        alert.view.tintColor = UIColor.black //2/6 black text
        for l11 in shapeList
        {
            let uid = OVScene.findSceneShapeUIDByName ( name: l11)
            alert.addAction(UIAlertAction(title: l11, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : uid ,
                                      isShape: true ,asObject: asObject)
            }))
        }
        for l12 in voiceList
        {
            let uid = OVScene.findSceneVoiceUIDByName ( name: l12) //10/15 wups!
            alert.addAction(UIAlertAction(title: l12, style: .default, handler: { action in
                self.addPipeStepThree(voice: voice,channel: channel , destination : uid,
                                      isShape: false ,asObject: asObject)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end addPipeStepTwo

    
    //=====<oogie2D mainVC>====================================================
    // 10/14 add asObject so we can use this to add pipes or scalars
    func addPipeStepThree(voice:OogieVoice , channel : String , destination : String , isShape : Bool, asObject : String)
    {
        //print("step 3 chan \(channel) destination \(destination) shape \(isShape)")
        let destItem = isShape ? "Shape" : "Voice" //10/14
        let alert = UIAlertController(title: "Choose " + destItem + " Parameter", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
        var menuNames = OSP.shapeParamNamesOKForPipe
        if !isShape {menuNames = OVP.voiceParamNamesOKForPipe}
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
    }

    //=====<oogie2D mainVC>====================================================
    // 11/30
    func deletePipePrompt()
    {
        let alert = UIAlertController(title: "Delete Selected Pipe?", message: "Pipe will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.shiftPanelDown(panel: self.pipeEditPanels)
            self.OVScene.deletePipeBy(uid: self.OVScene.selectedPipe.PS.uid) //9/25
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deletePipePrompt

  
    //=====<oogie2D mainVC>====================================================
    // 10/21
    func deleteScalarPrompt()
    {
        let alert = UIAlertController(title: "Delete Selected Scalar?", message: "Scalar will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.shiftPanelDown(panel: self.scalarEditPanels)
            self.OVScene.deleteScalarBy(uid: self.OVScene.selectedScalar.SS.uid) //9/25
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteScalarPrompt

    //=====<oogie2D mainVC>====================================================
    // 10/21 redo
    func deleteVoicePrompt()
    {
        //print("Delete Voice... \(self.OVScene.selectedVoice.OVS.name)")
        let alert = UIAlertController(title: "Delete Selected Voice?", message: "Voice will be permanently removed", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.shiftPanelDown(panel: self.voiceEditPanels)
            self.OVScene.deleteVoiceBy(uid: self.OVScene.selectedVoice.uid)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteVoicePrompt

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
            self.OVScene.createDefaultScene(named: "default")  //2/1/20 add an object
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

//        let tooob = toobbShape.createToob(sPos00:SCNVector3(0,0,0))
//        oogieOrigin.addChildNode(tooob)
        self.OVScene.sceneLoaded = true  //11/9 move to here

        
    } //end create3DScene
    
    
    var note : Int32 = 50
    var buf  : Int32 = 0
    var tnote : Int = 20
    //=====<oogie2D mainVC>====================================================
    @IBAction func testSelect(_ sender: Any) {

//        print("savescenetoFB...")
//        saveDatFuckerToFirebase()
        
        //10/31 test saving patch
//        let pname = "patchie"
        //test save patch to user area
//        OVScene.selectedVoice.OOP.saveItem(filename : pname , cat : "US")

        //        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        appDelegate.setCopyFactoryScenesFlag(value:1)
//        appDelegate.loadSettings()
//        print("reload factory settings...")
//        appDelegate.copyInFactoryStuff()
        //let note =  Int.random(in:20...120)
//        tnote = tnote + 8
//        if tnote > 120 { tnote = 20}
//
//        let r = CGFloat.random(in: 0...1)
//        let g = CGFloat.random(in: 0...1)
//        let b = CGFloat.random(in: 0...1)
//        let color = UIColor.init(red: r, green: g, blue: b, alpha: 1)
//        print("play note \(tnote)")
        // pan 0 = L 1 = R
//        toobbShape.nR.addNote( midiNote:tnote, color: color, pan:1 , type:"synth")

        
        
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        appDelegate.verbose = !appDelegate.verbose //10/12 toggle debug output
//        OVScene.verbose = appDelegate.verbose
//        allP.loadUserSoundPack()
//        sendSoundPackAndSampleNamesToControls() //10/23
//        stopPlayingMusic()
//        performSegue(withIdentifier: "samplesVCSegue", sender: self)

        //       OVScene.validate()
//        let scShape = ScalarShape.init()
//        scene.rootNode.addChildNode(scShape)
//
//        scShape.updateIndicator(with: "Testerini", value: 0.8)
//        scShape.updateLabel(with:"Voice_00001:Latitude")
        
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
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

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
                        print("link user sample \(fff) to buf \(sampnum)")
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
        dumpBuffers()
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
        OVScene.addVoice3DNode (voice:newVoice, op:op)
    } //end addVoiceToScene
    

    //=====<oogie2D mainVC>====================================================
    // 10/13 add scalar control object
    func addScalarToScene (scalarSS:ScalarStruct , op : String)
    {
        //ScalarShape cominb back as (shape:ScalarShape,pos3D:SCNVector3)
        let psTuple = OVScene.addScalarSceneData (scalarSS:scalarSS, op:op , startPosition:startPosition)
        let scalarNode = OVScene.addScalar3DNode (pst:psTuple,newNode:true)
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
    func chooseImageForSceneLoad()
    {
        stopPlayingMusic()   //10/24
        let imag = UIImagePickerController()
        imag.delegate = self // as UIImagePickerControllerDelegate & UINavigationControllerDelegate
        imag.sourceType = UIImagePickerController.SourceType.photoLibrary;
        imag.allowsEditing = false
        self.present(imag, animated: true, completion: nil)
    }
    
    //-----<imagePickerDelegate>-------------------------------------
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: false) { }
        stopPlayingMusic()   //10/24
    }

    //-----<imagePickerDelegate>-------------------------------------
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated:true, completion: nil)
        if let i = info["UIImagePickerControllerOriginalImage"]
        {
            let tiffie = OogieTiffie()
            if let s = tiffie.read(fromPhotos: i as? UIImage) //11/25
            {
                if s.contains("error") //Error?
                {
                    infoAlert(title:"TIFFIE load failed" , message : s)
                    stopPlayingMusic()   //10/24
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
                        if !updatingPipe { updatePipeByVoice(v:invoice) }
                    }
                case "updateMarkerRGB": // change marker color (3 xtra args)
                    if ops3D.count > 4  //got valid sequence? (op:key:r:g:b)
                    {
                        guard let rr = Int(ops3D[2]) else {break}  //get rgb ints
                        guard let gg = Int(ops3D[3]) else {break}
                        guard let bb = Int(ops3D[4]) else {break}
                        guard let marker3D = OVScene.markers3D[key] else {break}
                        marker3D.updateRGBData(rrr: rr, ggg: gg, bbb: bb)
                    }
                case "updateMarkerPlayed":   // update marker played status?
                    if ops3D.count > 2      // got a 3rd data value?
                    {
                        let gotPlayed      = String(ops3D[2])   // get data from pipe
                        //10/28 update toob if possible, but tooob is tooo sloooow
//                        if let lastNote = Int(ops3D[2])
//                        {
//                            // test 10/27 update toooob
//                            let r = CGFloat.random(in: 0...1)
//                            let g = CGFloat.random(in: 0...1)
//                            let b = CGFloat.random(in: 0...1)
//                            let color = UIColor.init(red: r, green: g, blue: b, alpha: 1)
//                            toobbShape.nR.addNote( midiNote:lastNote, color: color, pan:1 , type:"synth")
//                        }
                        guard let marker3D = OVScene.markers3D[key] else {break}
                        if gotPlayed != "0"
                        {
                            marker3D.gotPlayed = true
                            // 11/5 try pulling this marker3D.updateActivity() //10/28 OK here instead of in timer?
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
    //Foreground, handles marker appearance...
    //STOOPID place for this. how about a .30 second timer
    // that starts on any segue, but then if  starts
    // the music, then the timer gets invalidated
    //11/19 OBSOLETE
//    @objc func updateAllMarkersAndSpinShapes()
//    {
//        // iterate thru dictionary of markers... and update color
//        for (key,nextMarker) in OVScene.markers3D
//        {
//            nextMarker.updateMarkerPetalsAndColor()
//            if nextMarker.gotPlayed  //10/31 put back, wups
//            {
//                nextMarker.updateActivity()
//                nextMarker.gotPlayed = false //update our flag
//                OVScene.markers3D[key] = nextMarker //11/5 and resave marker
//            }
//
//        } //end for name...
//
//    } //end updateAllMarkersAndSpinShapes
    
    
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
    func cancelledTextures()
    {
        //stubbed for now
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
    func chooserChoseFile(name: String , path: String , fromCloud : Bool)
    {
        if chooserMode == "loadAllPatches"
        {
            //6/29/21 FIX! let ppp = allP.getPatchByName(name: name)
            //6/29/21 FIX! print("ppp \(ppp)")
        }
        else //load new scene?
        {
            OVSceneName  = name
            clearScene(withDefaultScene: false) //5/14 clear before load!
            self.OVScene.sceneLoaded = false //5/7 add loaded flag
            self.OVScene.OSC = DataManager.loadScene(OVSceneName, with: OSCStruct.self)
            finishSettingUpScene()   // finish 3d setup.. this may entail setting up a BAD SCENE!!?!?!?
            // 10/10 handle bad scenes!
            let sceneStatus = OVScene.validate()
            if sceneStatus != "OK" //10/11 error has to be in foreground thread dispatch
            {
                DispatchQueue.main.async { [self] in //err message needs to be in foreground thread
                    infoAlert(title:"Bad Scene Loaded\ncreating Default Scene instead" , message : sceneStatus)
                    self.clearScene(withDefaultScene: true)
                } //end dispatch
            } //end if sceneStatus
            else // valid scene?
            { startPlayingMusic() } //10/24 redo 
        }
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
        let appDelegate    = UIApplication.shared.delegate as! AppDelegate
        var bbot = appDelegate.externalSampleBase;   //10/27 assume sample space
        var btop = appDelegate.userSampleBase-1;
        if btop <= bbot {return} //10/27 handle no sample situation
        //print("RANDOM PATCH")
        let type = Int.random(in:0...3); //set up type first...
        randV.OOP.type = type
        switch Int32(type)
        {
        case SAMPLE_VOICE:
            randV.loadRandomSamplePatch(builtinBase: bbot, builtinMax: btop,
                                                      purchasedBase: 0, purchasedMax: 0)
            randV.OVS.name = "Dice:Sample"
        case SYNTH_VOICE: randV.loadRandomSynthPatch()
            (sfx() as! soundFX).buildEnvelope(Int32(randV.OOP.wave),true); //10/8 synth waves in bufs 0..4
            randV.OVS.name = "Dice:Synth"
        case PERCUSSION_VOICE:
            bbot = appDelegate.percussionBase //10/27
            btop = appDelegate.percussionTop - 1
            randV.loadRandomPercPatch(builtinBase: bbot, builtinMax: btop)
            randV.OVS.name = "Dice:Perc"
        case PERCKIT_VOICE :
            bbot = appDelegate.percussionBase //10/27
            btop = appDelegate.percussionTop - 1
            randV.loadRandomPercKitPatch(builtinBase: bbot, builtinMax: btop)
            randV.getPercLooxBufferPointerSet() //10/27
            randV.OVS.name = "Dice:PercKit"
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
        // ok save to working scene
//11/22 do NOT SAVE to scene!        OVScene.sceneVoices[OVScene.selectedMarkerKey] =  self.OVScene.selectedVoice
        let s = randV.dumpParams()
        print("randvoice \(s)")
    } //end loadRandomPatchToSelectedVoice
    
    //=====<oogie2D mainVC>====================================================
    // 10/8 add shorthand, synth wave setup  asdf
    func loadPatchByName (pName:String)
    {
        if let oop = allP.patchesDict[pName]
        {
            print("loadPatchByName: \(oop)")
            //let ovsel = self.OVScene.selectedVoice // 10/8 shorthand
            OVScene.selectedVoice.OOP = oop
            let editDict = (paramEdits() as! edits).getForPatch(pName) //10/1 apply any edits
            OVScene.selectedVoice.applyEditsWith(dict: editDict) //modify voices patch to suit edits
            let nn = allP.getSampleNumberByName(ss: oop.name)
            
            OVScene.selectedVoice.OVS.whichSamp = nn.intValue //10/1
            if OVScene.selectedVoice.OOP.type == PERCKIT_VOICE
            {
                OVScene.selectedVoice.getPercLooxBufferPointerSet() //go get buff ptrs...
            }
            print("load patch \(pName),  buf \(nn)")
        }
    } //end loadPatchByName
    
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
            let editDict = (paramEdits() as! edits).getForPatch(pName) //10/1 apply any edits
            ovsel.applyEditsWith(dict: editDict) //modify voices patch to suit edits
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
        self.deleteVoicePrompt()
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
     func didSetControlValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
     {
         //print("mainvc: didSetControlValue \(which) \(newVal) \(pname)")
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
             var pnames = [String]()
             var topChoice = "Random"
             if OVSoundPack == "UserSamples" {topChoice = ""} //11/1 pull dice on user area
             pnames.append(topChoice)
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
             cPanel.resetPatchPicker(1) // 10/28 try setting to top patch for now...
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
        OVScene.savingEdits = true //11/23
        //print("mainvc: didSetPatchValue \(which) \(newVal) \(pname) \(pvalue)")
        // for now just edit selected voice..
        editParam(which,newVal,pname,pvalue,undoable)
        OVScene.sceneVoices[OVScene.selectedMarkerKey] = OVScene.selectedVoice //WOW STORE IN SCENE?
        OVScene.savingEdits = false
    }

    //=====<patchPanelDelegate>====================================================
    func setNewScalarValue(sobj : OogieScalar , value : Double , pvalue: String) -> (toobj:String , param : String ,val:Double)
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

        if let shape  = OVScene.sceneShapes[tobject]
        {
            gotshape = true
            toObjName = shape.OOS.name
            // load up param metadata
            if let testArray = OSP.shapeParamsDictionary[paramName]
                { vArray = testArray  }
        }
        if let voice  = OVScene.sceneVoices[tobject]
        {
            gotvoice  = true
            toObjName = voice.OVS.name
            // load up param metadata
            if let testArray = OVP.voiceParamsDictionary[paramName]
            { vArray = testArray }
        }
        if vArray.count > 0   //10/21 make sur something is there
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
            if let shape  = OVScene.sceneShapes[tobject]
            {
                shape.setParam(named: paramName, toDouble: val, toString: pvalue)
                OVScene.sceneShapes[tobject] = shape //saveit back!
                OVScene.update3DShapeBy(uid:tobject)
            }
        }
        else if gotvoice
        {
            if let voice = OVScene.sceneVoices[tobject]
            {
                voice.setParam(named: paramName, toDouble: val, toString: pvalue)
                OVScene.sceneVoices[tobject] = voice //saveit back!
                OVScene.update3DShapeBy(uid:tobject)
                if paramName == "latitude" || paramName == "longitude" //require 3d update?
                {
                    if let marker = OVScene.markers3D[tobject]  //update 3d marker as needed
                    {
                        marker.updateLatLon(llat: voice.OVS.yCoord, llon: voice.OVS.xCoord)
                        updateScalarBy(uid: sobj.SS.uid)
                    }
                }
            }
        } //end gotvoice
        //print(" ....scalar -> set[\(tobject)] \(paramName) to \(val)")
        return( toObjName, paramName , val) //let caller know what was changed
    }

    //=====<scalarPanelDelegate>====================================================
    // 10/17 redid to handle  OVScene.loadCurrentShapeParams
    //  shit this is huge.  maybe break out?
    //KRASH in  voice detune
    func didSetScalarValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        //print("mainvc: didSetScalarValue \(which) \(newVal) \(pname) \(pvalue)")
        if pvalue == "value" //scalar value triggers live 3d response and changes another scene object
        {
            selectedScalarShape.startFadeout() //start scalar3D fade anim
            let paramTuple = setNewScalarValue(sobj:OVScene.selectedScalar , value: Double(newVal) , pvalue : pvalue) //11/3 break out to method
            let toObjName  = paramTuple.toobj
            let paramName  = paramTuple.param
            let val        = paramTuple.val
            OVScene.selectedScalar.value = Double(newVal) //11/18 keep trak of value

            //FIX THIS TOO, need to get converted value from setNewScalarValue
            let valueLabel : String = paramName + ":" + String(format: "%.2f", val)
            selectedScalarShape.updateIndicator(with: valueLabel, value: CGFloat(newVal))
            selectedScalarShape.updateLabel(with: toObjName)
            let s = String(format: "%@: %4.2f", paramName,val)
            pLabel.updateLabelOnly(lStr: s) ///"\(paramName) :" + String(val))
        } //end if pvalue...
        else
        {
            editParam(which,newVal,pname,pvalue,undoable)
        }
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
        self.deleteScalarPrompt()
        deselectAndCloseEditPanel()
    }

    //=====<shapePanelDelegate>====================================================
    // 9/15 redid to handle  OVScene.loadCurrentShapeParams
    func didSetShapeValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        OVScene.savingEdits = true //11/25 prevent krashes?
        //print("mainvc: didSetShapeValue \(which) \(newVal) \(pname) \(pvalue)")
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
            editParam(which,newVal,pname,pvalue,undoable)
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
        self.deleteShapePrompt()
        deselectAndCloseEditPanel()
    }

    //=====<pipePanelDelegate>====================================================
    // 9/15 redid to handle  OVScene.loadCurrentShapeParams
    func didSetPipeValue(_ which: Int32, _ newVal: Float, _ pname: String!, _ pvalue: String!, _ undoable: Bool)
    {
        //print("mainvc: didSetPipeValue \(which) \(newVal) \(pname) \(pvalue)")
        editParam(which,newVal,pname,pvalue,undoable)
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
        self.deletePipePrompt()
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


    //=====patchPanelDelegate>====================================================
    // 10/1 
    func didSelectPatchDice() {
        //print("didSelectPatchDice")
        pLabel.updateLabelOnly(lStr:"Dice: Patch") //9/18 info for user!
    }
    func didSelectPatchReset() {
        //print("didSelectPatchReset")
        pLabel.updateLabelOnly(lStr:"Reset Patch") //9/18 info for user!
        loadPatchByName (pName:OVScene.selectedVoice.OVS.patchName)
        //11/22 moved here from loadPatchByName
        selectedMarker.updateTypeInt(newTypeInt : Int32(OVScene.selectedVoice.OOP.type))

//       paPanel.patchName = OVScene.selectedVoice.OVS.patchName  //10/3
        paPanel.paramDict = OVScene.selectedVoice.getPatchParamDict() //10/5 send new params down...
        paPanel.configureView()
    }
    func didSelectPatchDismiss() {   //9/24 new for touch on editlabel in UI
        //print("didSelectPatchReset")
        deselectAndCloseEditPanel() //same as control dismiss, hide panel
    }

    //=====<settingsVCDelegate>====================================================
    //11/21
    func settingsVCChanged()
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        OVtempo = appDelegate.masterTempo;
        //print("svc changed tempo \(OVtempo)")
        for (_,shape) in OVScene.sceneShapes
        {
            shape.setRotationTypeAndSpeed() //pass new tempo down to shapes...
        }
        //11/22 NOTE this is only set for runtime, doesnt get saved!
        showStatistics = setVC.showStatistics
        skView!.showsStatistics = showStatistics
    } //end settingsVCChanged
} //end vc class, line 1413 as of 10/10

