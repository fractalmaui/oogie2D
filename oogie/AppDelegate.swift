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

//return [NSString stringWithFormat:@"PRI-%@",[[NSProcessInfo processInfo] globallyUniqueString]];


import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, sfxDelegate {

    var window: UIWindow?

    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    var tc = texCache.sharedInstance //9/3 texture cache
    
    let NUM_SFX_SAMPLES = 7  // "GM_001_C3"
    var sfxSoundFiles: [String] = ["dog" , "congaMid" , "clave00" , "bub1",
                                          "clave00" , "congaMid" , "vwhorn44k"]

    //========AppDelegate==============================================
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        //Hook up sfx protocol; decl is above
        (sfx() as! soundFX).delegate = self
        
        loadAllSamples()
        
        #if V2D
        print("2D Version...")
        #endif
        return true
    }
    
    //========AppDelegate==============================================
    func loadAllSamples()
    {
        //Get percussion samples loaded, start at index 64?
        let purl = Bundle.main.resourceURL!.appendingPathComponent("Percussion").path
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: purl)
                print("contents of percussion folder...")
                print(files)
            }catch{
                fatalError("error: no percussion!")
            }
        //now check GM area...
        let gurl = Bundle.main.resourceURL!.appendingPathComponent("GeneralMidi").path
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: gurl)
            print("contents of GMIDI folder...")
            print(files)
        }catch{
            fatalError("error: no GMidi!")
        }
        //Load up sound effects...
        //BUG in sfx: try loading samples 8 and up, they all get clobbered or vanish!
        //  need to load GM stuff starting at 8!!!
        for i in 0...NUM_SFX_SAMPLES-1
        {
            let sampleNumber = i
            //NSLog("...setSoundFileName[%d] %@",i+8,sfxSoundFiles[i]);
            (sfx() as! soundFX).setSoundFileName(Int32(sampleNumber),sfxSoundFiles[i])
        }
        // 10/15 NOTE this is a background call!
        //  it may not finish until after it is time to create our scene!
        //  but the scene depends on information gathered by this method! OUCH!
        //10/16 add notification to see when samples are loaded...
        (sfx() as! soundFX).loadAudioForOOGIE()
    } //end loadAllSamples
    
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


}

