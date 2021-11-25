//       _                ____       _                  _
//      / \   _ __  _ __ |  _ \  ___| | ___  __ _  __ _| |_ ___
//     / _ \ | '_ \| '_ \| | | |/ _ \ |/ _ \/ _` |/ _` | __/ _ \
//    / ___ \| |_) | |_) | |_| |  __/ |  __/ (_| | (_| | ||  __/
//   /_/   \_\ .__/| .__/|____/ \___|_|\___|\__, |\__,_|\__\___|
//           |_|   |_|                      |___/
//
//  AppDelegate.swift
//  oogie2D
//
//
//  Look for ARKit Game Tutorial - Part 1,2,3 of 3 by Anyone Can Code
//    https://www.youtube.com/watch?v=xI9Zd238x1k
//    https://www.youtube.com/watch?v=mOTriaIE85Q
//    https://www.youtube.com/watch?v=AlrdLdDOUlg
//  Data storage tutorial : ToDo List
//    https://www.youtube.com/watch?v=5ZUVCyOvZto&t=1600s
//    https://www.youtube.com/watch?v=VxAlvrwIeQM
//
//  General Midi Samples:
//   https://freewavesamples.com/midi-instruments
//  IDea 8/24 try animating the latitude of the marker based on the color,
//     i.e. one color makes the lat go less by a certain number, one color makes it go more.
//      only sample every quanta?  to get new color and direction??
//      also animate canned lat/lon movements back and forth, etc.
//         create a 2d touch screen interface to sketch out animations as such
//  Add rotary knob to mainVC for changing parameters..
//    https://www.raywenderlich.com/5294-how-to-make-a-custom-control-tutorial-a-reusable-knob
//  GM patch definitions:
//   https://www.midi.org/specifications-old/item/gm-level-1-sound-set
//  Jump to definition: control + apple  then doubleclick
//  Add Complete Scene to a SCNNode plane in a scene?
//    https://stackoverflow.com/questions/55700757/how-do-i-add-a-skscene-to-a-scnnode-plane
//  Compiler switching:
//    https://stackoverflow.com/questions/24003291/ifdef-replacement-in-the-swift-language
//  4/20 pull loadallSamples
//  10/25 add copyFactoryScenes... copyInFactoryStuff
//  10/27  add percussionBase , percussionTop
//  11/21  add masterTune, masterTempo
import UIKit



let COMMENT_DEFAULT = ""   //10/30   stoopid global visible everywhere
var appSettings = Dictionary<String, Any>()

@UIApplicationMain
@objc class AppDelegate: UIResponder, UIApplicationDelegate, sfxDelegate {

    var window: UIWindow?
    
    var versionStr = ""
    //All patches: singleton, holds built-in and locally saved patches...
    var allP = AllPatches.sharedInstance
    var masterPitch = 0 //4/19 master pitch shift in notes
    @objc var masterTune  = 0 //11/21
    @objc var masterTempo = 135 //11/21

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    var tc  = texCache.sharedInstance //9/3 texture cache
    
    var percussionBase = 0 //10/27 drums start here
    var percussionTop  = 0
    let externalSampleBase   = 256;
    var userSampleBase = 0 //where user samples live after all soundpacks are loaded

    var OVP  =  OogieVoiceParams.sharedInstance //9/19/21 oogie voice params
    var OSP  =  OogieShapeParams.sharedInstance //9/19/21 oogie shape params
    var OPP  =  OogiePipeParams.sharedInstance  //9/19/21 oogie pipe params
    var OPaP =  OogiePatchParams.sharedInstance //9/28
    var OScP =  OogieScalarParams.sharedInstance  //10/13 new scalar type
    
    var verbose = false //10/12 for debug output

    //========AppDelegate==============================================
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        //Hook up sfx protocol; decl is above
        (sfx() as! soundFX).delegate = self
        
        //4/14/20
        (sfx() as! soundFX).loadAudio(); //  5/28 FIX THISForOOGIE()

        #if V2D
        print("2D Version...")
        #endif
        
        
        //Get version string
        if let nsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject?
        {
            versionStr = nsObject as! String
        }
        // 10/18 for general patch access throughout, change viewControler too!
        //BUG! allp is loading its samples and patches BEFORE it knows if anything was bought...
        //  there needs to be an alloc phase for allp AND then a load all patches phase!
        //10/21 allpatches needs to know if anything was bought!
//        NSArray* A = [self getPurchasedSoundPacksKeys];
//        [allP setPSPNWithA:A]; //cryptic, huh!
        allP.createSubfolders() //10/8 WTF? why wasnt this here?
        allP.loadAllSoundPacksAndPatches();  //11/2 wups was in wrong place

        loadSettings()
        
        copyInFactoryStuff() //10/25
        
        loadSamples()  //7/1/21
        return true
    }
    

    //========AppDelegate==============================================
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    //====(AppDelegate)----------------------------------------------
    func didLoadSFX()
    {
        //Honk a horn to indiucate we've started!
        (sfx() as! soundFX).makeTicSound(withPitchandLevelandPan: 6,64,20,128)
        print("OK! samples loaded now")
    }

    let skMasterTempo       = "masterTempo"
    let skMasterTune        = "masterTune"
    let skSpinTimerPeriod   = "spinTimerPeriod"
    let skColorTimerPeriod  = "colorTimerPeriod"
    let skBlinkTimerPeriod  = "blinkTimerPeriod"
    let skCopyFactoryScenes = "copyFactoryScenes"

    //====(AppDelegate)----------------------------------------------
    //10/24/21 cleanup , add factory copy flag
    func loadSettings()
    {
        let defaults = UserDefaults.standard
        defaults.synchronize()
        let dd = defaults.double(forKey: skSpinTimerPeriod)
        if (dd == 0.0) //no settings yet?
        {
            defaults.setValue(135, forKey: skMasterTempo)
            defaults.setValue(0,   forKey: skMasterTune)
            defaults.setValue(0.1, forKey: skColorTimerPeriod)
            defaults.setValue(0.1, forKey: skSpinTimerPeriod)
            defaults.setValue(0.1, forKey: skBlinkTimerPeriod)
            defaults.setValue(1,   forKey: skCopyFactoryScenes)
            //print("reset defaults ...")
        }
        //print("spintimer  is \(defaults.double(forKey: "spinTimerPeriod"))")
        //print("colortimer is \(defaults.double(forKey: "colorTimerPeriod"))")
        //print("blinktimer is \(defaults.double(forKey: "blinkTimerPeriod"))")
        appSettings[skMasterTempo]       = defaults.double(forKey: skMasterTempo)
        appSettings[skMasterTune]        = defaults.double(forKey: skMasterTune)
        appSettings[skColorTimerPeriod]  = defaults.double(forKey: skColorTimerPeriod)
        appSettings[skSpinTimerPeriod]   = defaults.string(forKey: skSpinTimerPeriod)
        appSettings[skBlinkTimerPeriod]  = defaults.double(forKey: skBlinkTimerPeriod)
        appSettings[skCopyFactoryScenes] = defaults.double(forKey: skCopyFactoryScenes)
        if let d = appSettings[skMasterTempo] as? Double{
            masterTempo = Int(d)
        }
        if let d = appSettings[skMasterTune] as? Double{
            masterTune  = Int(d)
        }
    } //end loadSettings

    //====(AppDelegate)----------------------------------------------
    // 10/24 need to validate!
    func setCopyFactoryScenesFlag(value : Int)
    {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: skCopyFactoryScenes)
    }

    
    //====(AppDelegate)----------------------------------------------
    //11/21
    @objc func updateMasterTempo(value : Int)
    {
        masterTempo = value;
       // let defaults = UserDefaults.standard
        UserDefaults.standard.set(value, forKey: skMasterTempo)
    }

    //====(AppDelegate)----------------------------------------------
    //11/21
    @objc func updateMasterTune(value : Int)
    {
        masterTune = value;
      //  let defaults = UserDefaults.standard
        UserDefaults.standard.set(value, forKey: skMasterTune)
    }


    //====(AppDelegate)----------------------------------------------
    //  6/12/20 redid
    func loadSamples()
    {
        let folders = ["GMPercussion","animals","weirdness"]   //9/11 add weirdness soundpack
        var fcount = 0
        var sampnum = LOAD_SAMPLE_OFFSET //32?  starting point for samples...
        percussionBase = Int(sampnum) //10/27
        for subFolder in folders
        {
            if fcount == 1 //first set of built-in samples?
            {
                sampnum = Int32(externalSampleBase)
            }
            var url = URL(fileURLWithPath: "") //Start w/ empty path
            url = (Bundle.main.resourceURL?.appendingPathComponent(subFolder))!
            var fileNamez : [String] = []
            do {
                fileNamez = try FileManager.default.contentsOfDirectory(atPath: url.path)
            }
            catch{
                print(" loadSamples:could not find \(url)")
                return
            }
            fileNamez = fileNamez.sorted() //sort by alpha?
            for fname in fileNamez
            {
                if fname.lowercased().contains(".wav") //valid wav files only
                {
                    let fnameParts = fname.split(separator: ".")
                    if (fnameParts.count >= 1)
                    {
                        let nameOnly = String(fnameParts[0])
                        let fullPath = subFolder + "/" + nameOnly
                        (sfx() as! soundFX).setNoteOffset(Int32(sampnum), nameOnly)
                        (sfx() as! soundFX).setSoundFileName(Int32(sampnum),fullPath)
                        allP.linkBufferToPatch(nn: NSNumber(value: sampnum), ss: nameOnly)
                        //print("load sample \(fullPath)")
                        sampnum+=1
                    }
                }
            } //end for fname
            if fcount == 0
            {
                percussionTop = Int(sampnum); //10/27 top GMPercussion buffer
            }
            fcount+=1; //update folder count
        }
        (sfx() as! soundFX).loadAudioBKGD(-1)
        userSampleBase = Int(sampnum);
    } //end loadSamples
    
    //========AppDelegate==============================================
    // one-time only? or factory reset file actions
    //  settings bundle should be loaded first!
    func copyInFactoryStuff()
    {
        //do we need fresh scenes for new user?
        var needNewScenes = true
        if let nn = appSettings[skCopyFactoryScenes] as? NSNumber
        {
            //print("skCopyFactoryScenes \(nn)")
            if (nn.intValue == 0)
            {
                needNewScenes = false
                //print("...no need for factory copy scenes")
            }
        }
        if needNewScenes
        {
            //print("copy new scenes...")
            copyFactoryScenesToDocuments()
            setCopyFactoryScenesFlag(value:0) //clear our defaults flag so we dont repeat!
        }
    }
    
    //====(AppDelegate)----------------------------------------------
    func copyFactoryScenesToDocuments()
    {
        var resPath = Bundle.main.resourceURL!.appendingPathComponent("FactorySettings").path
        resPath = resPath + "/" + "Scenes" //Now add proper subpath...
        let fs  = "Factory Scene"
        
        do{
            let dirContents = try FileManager.default.contentsOfDirectory(atPath: resPath)
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            //let filteredFiles = dirContents.filter { $0.contains(".oos")}
            for fileName in dirContents
            {
                if let dURL = documentsURL{
                    let factoryFolderName = "FactorySettings/Scenes/" + fileName
                    let sceneFolderName   = "scenes/" + fileName
                    let sourceURL = Bundle.main.bundleURL.appendingPathComponent(factoryFolderName)
                    if let destURL   = documentsURL?.appendingPathComponent(sceneFolderName)
                    {
                        do {
                            //print("copy from \(sourceURL) to \(destURL)")
                            try FileManager.default.copyItem(at: sourceURL, to: destURL)
                            print("...copied \(fs):\(fileName)")
                        }
                        catch{
                            print("...error copying \(fs):\(fileName)")
                        }
                    }
                }
            }
            setCopyFactoryScenesFlag(value:0) //clear our defaults flag so we dont repeat!
        }
        catch
        {
            print("error finding \(fs)")
        }
    } //end copyFactoryScenesToDocuments


} //end AppDelegate

