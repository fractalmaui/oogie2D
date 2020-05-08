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


import UIKit



let COMMENT_DEFAULT = "..."   //2/3   stoopid global visible everywhere
var appSettings = Dictionary<String, Any>()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, sfxDelegate {

    var window: UIWindow?
    
    var versionStr = ""
    

    var masterPitch = 0 //4/19 master pitch shift in notes

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    var tc  = texCache.sharedInstance //9/3 texture cache
    
    let NUM_SFX_SAMPLES = 7  // "GM_001_C3"
    var sfxSoundFiles: [String] = ["dog" , "congaMid" , "clave00" , "bub1",
                                          "clave00" , "congaMid" , "vwhorn44k"]

    //========AppDelegate==============================================
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        //Hook up sfx protocol; decl is above
        (sfx() as! soundFX).delegate = self
        
        //4/14/20
        (sfx() as! soundFX).loadAudioForOOGIE()

        #if V2D
        print("2D Version...")
        #endif
        
        //Get version string
        if let nsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject?
        {
            versionStr = nsObject as! String
        }

        loadSettings()
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
    }

    //====(AppDelegate)----------------------------------------------
    // 5/7 add settings bundle...
    func loadSettings()
    {
        let defaults = UserDefaults.standard
        defaults.synchronize()
        let dd = defaults.double(forKey: "spinTimerPeriod")
        if (dd == 0.0) //no settings yet?
        {
            defaults.setValue(0.1, forKey: "colorTimerPeriod")
            defaults.setValue(0.1, forKey: "spinTimerPeriod")
            defaults.setValue(0.1, forKey: "blinkTimerPeriod")
            print("reset defaults ...")
        }
        print("spintimer  is \(defaults.double(forKey: "spinTimerPeriod"))")
        print("colortimer is \(defaults.double(forKey: "colorTimerPeriod"))")
        print("blinktimer is \(defaults.double(forKey: "blinkTimerPeriod"))")
        appSettings["colorTimerPeriod"] = defaults.double(forKey: "colorTimerPeriod")
        appSettings["spinTimerPeriod"]  = defaults.string(forKey: "spinTimerPeriod")
        appSettings["blinkTimerPeriod"] = defaults.double(forKey: "blinkTimerPeriod")
    } //end loadSettings

    //====(AppDelegate)----------------------------------------------
    // no need yet...
    func saveSettings()
    {
//        let defaults = UserDefaults.standard
//        defaults.setValue(appSettings["colorTimerPeriod"], forKey: "colorTimerPeriod")
//        defaults.setValue(myTextField.text, forKey: textFieldKeyConstant)
//        defaults.set(mySwitch.isOn, forKey: switchKeyConstant)
    }
    
} //end AppDelegate

