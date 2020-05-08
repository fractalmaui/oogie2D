//   ____       _       _     _____    _ _ _ __     ______
//  |  _ \ __ _| |_ ___| |__ | ____|__| (_) |\ \   / / ___|
//  | |_) / _` | __/ __| '_ \|  _| / _` | | __\ \ / / |
//  |  __/ (_| | || (__| | | | |__| (_| | | |_ \ V /| |___
//  |_|   \__,_|\__\___|_| |_|_____\__,_|_|\__| \_/  \____|
//
//  PatchEditVC.swift
//  Oogie2D / OogieAR
//
//  Created by Dave Scruton on 11/4/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
//  BUG? KB didn't work, in Sim, Hardware / Keyboard / Connect Hardware KB was set.
//          OUCH!
//  Note relation between arrow buttons and the animated views.
//    button tags go from 101...105  and views are 1101...1105.
//  The tag relationship is used to produce view animation for each button.
//  More views can be added this way, as long as the tags are incremented
//  Each view is evaluated and sized based on the bottommost control it contains,
//   this becomes the "bigHeight". The view then can be toggled between this and
//   the "smallHeight".  Note there are 2 different types of animations used,
//   CABasicAnimation and UIView.animate(with...
//  11/13 add envelopeChanged flag in setupSynthOrSample, now env shows up on load
//  11/15 add subfolders to builtin saves, add save info prompt
//  11/16 get patchname again when save is hit, in case KB is up
//  2/27  pull stuff for PERCKIT_VOICE in setupSynthOrSample
//  5/8   update chooser protocol, add chooserCancelled
import UIKit

protocol patchEditVCDelegate
{
    func patchEditVCSavePatchNow(name : String)
    func patchEditVCDone(namez : [String] , userPatch : Bool, allNew : Bool)
}



//This is used by each expandable view in the VC
struct ViewSetup {
    var expanded    : Bool
    var canExpand   : Bool
    var smallHeight : Int
    var bigHeight   : Int
    let fieldHeight = 60
    let yMargin     = 5
    var view        = UIView()
    
    //-------------------------------------------
    init()
    {
        expanded    = true
        canExpand   = true
        smallHeight = 60
        bigHeight   = 300 //This will vary!
    }
    //-------------------------------------------
    mutating func setupComputedHeight(v : UIView)
    {
        var bottom = 0
        //find bottommost item
        for view in v.subviews as [UIView] {
            let bt = view.frame.origin.y + view.frame.size.height
            bottom = max(Int(bt),bottom)
        }
        bigHeight = bottom + yMargin
    }
    //-------------------------------------------
    mutating func setCanExpand(flag:Bool)
    {
        canExpand = flag
        var bgcolor = UIColor.init(white: 0.8, alpha: 1)
        if !flag  //Close view , set dark bkgd if disabled
            {   expanded = false
                bgcolor = UIColor.darkGray
            }
        view.backgroundColor = bgcolor
    }
    
    //-------------------------------------------
    mutating func toggle()
    {
        if canExpand {expanded = !expanded}
    }
} //end ViewSetup struct


//=========PatchEditVC==============================================
class PatchEditVC: UIViewController,
                    UITextFieldDelegate,
                    UIPickerViewDelegate,
                    UIPickerViewDataSource,
                    chooserDelegate {

    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var titleView: UIView!
    
    @IBOutlet weak var bTLabel: UILabel!
    @IBOutlet weak var tTLabel: UILabel!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var factoryButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var adsrToggle: UISwitch!
    @IBOutlet weak var typePicker: UIPickerView!
    // Next section...
    @IBOutlet weak var wtypePicker: UIPickerView!
    @IBOutlet weak var dutySlider: UISlider!
    // Next section...
    @IBOutlet weak var attackSlider: UISlider!
    @IBOutlet weak var decaySlider: UISlider!    
    @IBOutlet weak var sustainSlider: UISlider!
    @IBOutlet weak var slevelSlider: UISlider!
    @IBOutlet weak var releaseSlider: UISlider!
    @IBOutlet weak var sOffsetSlider: UISlider!
    
    @IBOutlet weak var playPicker: UIPickerView!
    @IBOutlet weak var pkSlider1: UISlider!
    @IBOutlet weak var pkSlider2: UISlider!
    @IBOutlet weak var pkSlider3: UISlider!
    @IBOutlet weak var pkSlider4: UISlider!
    @IBOutlet weak var pkSlider5: UISlider!
    @IBOutlet weak var pkSlider6: UISlider!
    @IBOutlet weak var pkSlider7: UISlider!
    @IBOutlet weak var pkSlider8: UISlider!
    

    @IBOutlet weak var prevButton: UIButton!
    
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var arpPicker: UIPickerView!
    @IBOutlet weak var adsrImage: UIImageView!
    var delegate: patchEditVCDelegate?
    var chooserMode = "load"
    
    var viewz = Dictionary<Int, ViewSetup>() //Hashed by UIView Tag
    let rhArrow = UIImage.init(named: "rhArrow")
    let dnArrow = UIImage.init(named: "dnArrow")
    let firstTop = 150
    let typePickerValues  = ["Synth", "Percussion", "Perc Kit" , "Sample"]
    let wtypePickerValues = ["Sine", "Sawtooth", "Square" , "Ramp" , "Noise"]
    let playPickerValues  = ["Off", "Basic", "Scale" , "Octaves" , "Random"]

    let umsg = "This patch exists. If you write over it the old patch will be lost."
    let bmsg = "This is a Built-In patch. If you write over it the old patch will be replaced. You can restore later from Factory Settings."

    var patchNamez : [String] = []
    var patchNum   = 0
    
    var patchName = "default"
    var patchInfo = PatchieInfo()
    var opatch    = OogiePatch()
    var needToUseADSR = false
    var newPatchNamez : [String] = []
    var allPatchNamesFromChooser : [String] = []
    var userPatch = false
    var allNew    = true
    var sampleChooserTag = 0
    //NOTE: animshiftTime should be smaller than
    //       the large rotation time to avoid glitches
    let animRotTime1  = 0.05
    let animRotTime2  = 0.3
    let animShiftTime = 0.25
    var animCount     = 0  //checks if anim is done?
    
    var playTimer   = Timer()
    var playMode    = 0
    var playLooping = false
    var needNewBuffer   = true   //This triggers buffer realloc
    var bufferChanged   = true   //     triggers buffer copy
    var envelopeChanged = true   //     triggers envelope copy
    
    var helpAnchor = ""
    
    let basicsViewTag   = 1100
    let waveViewTag     = 1101
    let adsrViewTag     = 1102
    let sampleViewTag   = 1103
    let perclooxViewTag = 1104

    var notesToLoopOver : [Int] = []
    var noteIndex = 0
    let basicNotes = [64,68,71,76]
    let scaleNotes = [64,65,66,67,68,69,70,71,72,73,74]
    let octaveNotes = [28,40,52,64,76,88,100]
    //Audio Sound Effects...
    var sfx = soundFX.sharedInstance
    var allP = AllPatches.sharedInstance

    //=====PatchEditorVC===========================================
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        scrollView.contentSize = CGSize(width: 410, height: 1500)
        setupViewToggles()
        updateViewFrames()

        typePicker.dataSource = self
        typePicker.delegate   = self

        wtypePicker.dataSource = self
        wtypePicker.delegate   = self

        playPicker.dataSource = self
        playPicker.delegate   = self

        //Hook up text fields...
        nameText.delegate = self
        setFieldsFromPatch()
        updateViewsBasedOnPatchType()
        
        let gotFastCode = true
        //ADSR Update not fast enuf ??
        attackSlider.isContinuous  = gotFastCode
        decaySlider.isContinuous   = gotFastCode
        sustainSlider.isContinuous = gotFastCode
        slevelSlider.isContinuous  = gotFastCode
        releaseSlider.isContinuous = gotFastCode
        
        playTestNote(midiNote: 64) //Ping! makes full UI OK

        
        //Place bottom buttons / knobs automagically...
        let csz = UIScreen.main.bounds.size;
        let viewWid = csz.width   //10/27 enforce portrait aspect ratio!
        let viewHit = csz.height

        //11/16 Cosmetic: Line up bottom buttons...
        // start at Bottom Left, go across to right
        let steppie = 3
        var x       = 0
        var bwh     = 60
        var y       = Int(viewHit) - 120
        loadButton.layer.cornerRadius = CGFloat(bwh/2)
        loadButton.frame =  CGRect(x: x , y: y, width: bwh, height: bwh)
        
        x+=(bwh + steppie)
        saveButton.layer.cornerRadius = CGFloat(bwh/2)
        saveButton.frame = CGRect(x: x , y: y, width: bwh, height: bwh)

        x+=(bwh + steppie)
        prevButton.layer.cornerRadius = CGFloat(bwh/2)
        prevButton.frame = CGRect(x: x , y: y, width: bwh, height: bwh)

        x+=(bwh + steppie)
        nextButton.layer.cornerRadius = CGFloat(bwh/2)
        nextButton.frame = CGRect(x: x , y: y, width: bwh, height: bwh)

        //RH Bottom, layout going to left...
        x = Int(viewWid) - bwh
        cancelButton.layer.cornerRadius = CGFloat(bwh/2)
        cancelButton.frame = CGRect(x: x , y: y, width: bwh, height: bwh)

        bwh += 40 //go wider for the stepper
        x   -= (bwh + steppie)
        y   -= 20 //stagger up 1/3 button hite
        playPicker.frame = CGRect(x: x , y: y , width: bwh, height: bwh)
        updateForPatchInfo() //11/12 set factory button if needed

    } //end viewDidLoad
    
    //=====PatchEditorVC===========================================
    override var canBecomeFirstResponder: Bool
    {
        return true
    }

    //=====PatchEditorVC===========================================
    @IBAction func prevSelect(_ sender: Any) {
        //print("get prev patch??")
        if (patchNamez.count < 1) {return} //Bail on no namez!
        patchNum = patchNum-1;
        if patchNum < 0  {patchNum = patchNamez.count-1}
        loadPatchFromChooserAndUpdateUI(name: patchNamez[patchNum])
    }
    
    //=====PatchEditorVC===========================================
    @IBAction func nextSelect(_ sender: Any) {
        print("get next patch??")
        if (patchNamez.count < 1) {return} //Bail on no namez!
        patchNum = patchNum+1;
        if patchNum > patchNamez.count-1 {patchNum = 0}
        loadPatchFromChooserAndUpdateUI(name: patchNamez[patchNum])
    }
    
    //=====PatchEditorVC===========================================
    //Triggered by Load button
    @IBAction func loadSelect(_ sender: Any) {
        sampleChooserTag = -1
        //chooser?
        //try test for now
        //asdf
        chooserMode = "loadAllPatches"
        self.performSegue(withIdentifier: "chooserSegue", sender: self)
//
//        let patchie = DataManager.loadPatch(url: DataManager.getPatchDirectory(), with: "default", with: OogiePatch.self)
            
//
//            url:DataManager.getPatchDirectory() ,
//
//
//        (url: DataManager.getPatchDirectory(),
//                                            with: "default", with: OogiePatch)
//        print("patchie \(patchie)")
    }
    //=====PatchEditorVC===========================================
    @IBAction func testSelect(_ sender: Any) {
        if playLooping {stopTestLoop()}
        playTestNote(midiNote : 64)
    }
    
    //=====PatchEditorVC===========================================
    @IBAction func factoryReset(_ sender: Any) {
        print("factory reset!")
    }
    
    //=====PatchEditorVC===========================================
    func getFreshPatchinfo() -> PatchieInfo
    {
        if let pinfo = allP.patchInfoDict[opatch.name] {return pinfo}
        return PatchieInfo()
    }
    
    //=====PatchEditorVC===========================================
    // called from setupSynthOrSample
    func updateADSRDisplay()
    {
        let asize = 256
        guard let NNvalz = (sfx() as! soundFX).getEnvelopeForDisplay( 255  , Int32(asize))
            else {return}
        //OUCH. comes back as array of nsnumbers
        var valz : [Float] = []
        for val in NNvalz  //should be an array of nsnumber floats
        {
            if let nn = val as? NSNumber { valz.append(nn.floatValue) }
        }
        adsrImage.image = createADSRImage(frame:adsrImage.frame,vals: valz)
    } //end updateADSRDisplay
    
    //=====PatchEditorVC===========================================
    //11/12 needed at load time or if patch name changes
    func updateForPatchInfo()
    {
        //Try to get patch info for this patch
        patchInfo = getFreshPatchinfo()
        factoryButton.isHidden = true
        var s = "User Patch"
        if patchInfo.builtin {s = "Builtin Patch"}
        print(patchInfo)
        //Update BOTH contrasting labels...
        bTLabel.text = s
        tTLabel.text = s
        factoryButton.isHidden = !patchInfo.factorySettingWasChanged
    } //end updateForPatchInfo
    
    //=====PatchEditorVC===========================================
    // Rotates one of our arrow button background +/- 90 degrees
    func rotate90(bb:UIButton, clockwise : Bool , dur : Double)
    {
        animCount+=1
        let ar = CABasicAnimation(keyPath:"transform.rotation.z")
        ar.duration = dur
        ar.isAdditive = true
        ar.isRemovedOnCompletion = false
        var v0 = 0.0
        var v1 = Double.pi/2
        if !clockwise
        {
            v0 = 0.0
            v1 = -Double.pi/2
        }
        ar.fromValue = v0
        ar.toValue   = v1
        CATransaction.setCompletionBlock {
            var i = self.rhArrow
            if clockwise {i = self.dnArrow}
            bb.setBackgroundImage(i, for: .normal)
            self.animCount-=1
        }
        bb.layer.add(ar,forKey:nil)
    } //end rotate90

    
    
    //=====PatchEditorVC===========================================
    @IBAction func cancelSelect(_ sender: Any) {
        //May have patch names, depending on what was saved
        delegate?.patchEditVCDone(namez : newPatchNamez , userPatch : false, allNew : false)
        stopTestLoop()
        dismiss(animated: true, completion: nil)
        self.parent?.viewDidLayoutSubviews() //Need to goose parent?
    }

    //=====PatchEditorVC===========================================
    // Triggered by "Save" button
    @IBAction func okSelect(_ sender: Any) {
        stopTestLoop()
        //Get patch name in case kb is up...
        if let t = nameText.text
        {
            patchName = t
            checkPatchAndSave()
        }
    }

    //=====PatchEditorVC===========================================
    @IBAction func helpSelect(_ sender: Any) {
        let b = sender as! UIButton
        switch b.tag{
            case 41: helpAnchor     = "edit_patch"
            case 42: helpAnchor = "edit_wave"
            case 43: helpAnchor = "edit_adsr"
            case 44: helpAnchor = "edit_sample"
            case 45: helpAnchor = "edit_perkit"
            default: helpAnchor = ""
        }
        self.performSegue(withIdentifier: "helpSegue", sender: self)
    }

    //=====PatchEditorVC===========================================
    @IBAction func arrowSelect(_ sender: Any) {
        if animCount > 0 {return} //arrow / view animating? bail!
        let b = sender as! UIButton
        print("tag \(b.tag)")
        if let vt = viewz[b.tag+1000]  //get matching view for this button
        {
            if vt.canExpand //Only expand views that are enabled
            {
                rotate90(bb: b,clockwise: !vt.expanded , dur: animRotTime2)
                toggleViewSize(btag:b.tag)
            }
        }
    } //end arrowSelect
    
    //=====PatchEditorVC===========================================
    @IBAction func loadSampleSelect(_ sender: Any) {
        let button = sender as! UIButton
        sampleChooserTag = button.tag
        chooserMode = "load"
        self.performSegue(withIdentifier: "chooserSegue", sender: self)
    }


    //=====PatchEditorVC===========================================
     @IBAction func adsrChanged(_ sender: Any) {
        let t = sender as! UISwitch
        needToUseADSR   = t.isOn //11/17 wrohg polarity
        envelopeChanged = true
     }

    //=====PatchEditorVC===========================================
    // Slider tags: 30... wave,ADSR, sample sliders
    //               1... percKit sliders
    @IBAction func sliderChanged(_ sender: Any) {
        let sl = sender as! UISlider
        //print("sl tag \(sl.tag) val \(sl.value)")
        let val = Double(sl.value)
        var pki = -1
        let tag = sl.tag
        //Now set approp. param
        switch(tag)
        {
            case 11...18: pki = Int(tag-11)
            case 30: opatch.duty    = val
            case 31: opatch.attack  = val
            case 32: opatch.decay   = val
            case 33: opatch.sustain = val
            case 34: opatch.sLevel  = val
            case 35: opatch.release = val
            case 36: opatch.sampleOffset = Int(val) //NOTE we need sample size here!
            default: return
        }
        //Changed PK pan? update array
        if pki != -1 {opatch.percLooxPans[pki] = Int(256.0 * val)}
        envelopeChanged = (tag > 29 && tag < 36)
        bufferChanged   = (tag == 30) //Duty? Need to redo wave
        if envelopeChanged { setupSynthOrSample() }  //Too much crap?
    } //end sliderChanged
    
    
    //=====PatchEditorVC===========================================
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "chooserSegue" {
            if let chooser = segue.destination as? chooserVC {
                chooser.delegate = self
                //DETERMINE which chooser folder need?
                var folder = "gmidi"
                //handle the 8 percKit chooser boxes...
                //  also sample box if patch type is percussion
                if sampleChooserTag == -1  //Load button? look for patches
                   { folder = "patches" }
                else if sampleChooserTag < 39 || opatch.type == PERCUSSION_VOICE
                   { folder = "percussion"}
                chooser.chooserFolder = folder
                chooser.mode          = chooserMode
            }
        }
        else if segue.identifier == "helpSegue" {
//            if let helpvc = segue.destination as? helpVC {
//                helpvc.anchor = helpAnchor
//            }
            
        }
    } //end prepare...

    
    //=====PatchEditorVC===========================================
    // sets from opatch structure...
    func setFieldsFromPatch()
    {
        nameText.text = patchName
        typePicker.selectRow(opatch.type, inComponent:0, animated:true)
        //Hmm. how do we set this?
        if opatch.type == SYNTH_VOICE  { needToUseADSR  = true }
        if opatch.type == SAMPLE_VOICE { needToUseADSR = !opatch.gotAllZeroes() }  //Zero ADSR? dont use!
        let isPercussion = (opatch.type == PERCUSSION_VOICE || opatch.type == PERCKIT_VOICE)
        adsrToggle.setOn(needToUseADSR, animated: true)
        adsrToggle.isEnabled = !isPercussion
        dutySlider.setValue(Float(opatch.duty), animated: true)
        attackSlider.setValue(Float(opatch.attack), animated: true)
        decaySlider.setValue(Float(opatch.decay), animated: true)
        sustainSlider.setValue(Float(opatch.sustain), animated: true)
        slevelSlider.setValue(Float(opatch.sLevel), animated: true)
        releaseSlider.setValue(Float(opatch.release), animated: true)
        sOffsetSlider.setValue(Float(opatch.sampleOffset), animated: true)
        
        for i in 1...8 //Find perc labels, get tag, load w/ proper data
        {
            let pkLabel = scrollView.viewWithTag(i)
            if let pkl = pkLabel as? UILabel{
                pkl.text = opatch.percLoox[i-1]
            }
        }
        //11/11 fill in sample label by tag...
        let sampLabel = scrollView.viewWithTag(9)
        if let sl = sampLabel as? UILabel{
            sl.text = opatch.name
        }

        let fdiv : Float = 1.0 / 255.0  //Huh? WTF? arent pans 0-255?
        pkSlider1.value = Float(opatch.percLooxPans[0]) * fdiv
        pkSlider2.value = Float(opatch.percLooxPans[1]) * fdiv
        pkSlider3.value = Float(opatch.percLooxPans[2]) * fdiv
        pkSlider4.value = Float(opatch.percLooxPans[3]) * fdiv
        pkSlider5.value = Float(opatch.percLooxPans[4]) * fdiv
        pkSlider6.value = Float(opatch.percLooxPans[5]) * fdiv
        pkSlider7.value = Float(opatch.percLooxPans[6]) * fdiv
        pkSlider8.value = Float(opatch.percLooxPans[7]) * fdiv
    } //end setFieldsFromPatch
    
    //=====PatchEditorVC===========================================
    func setupViewToggles()
    {
        var nextTop = firstTop
        for view in scrollView.subviews as [UIView] {
            if (view.tag >= 1000)
            {
                var vs = ViewSetup()
                vs.expanded = true
                // figure out expanded size...
                vs.setupComputedHeight(v: view)
                vs.view = view //Save view handle...
                viewz[view.tag] = vs
                nextTop = 5 + updateViewFrame(nextTop : nextTop ,v: view, vt: vs)
            }
        }
    } //end setupViewToggles
    
     
    //=====PatchEditorVC===========================================
    func toggleViewSize(btag:Int)
    {
        for view in scrollView.subviews as [UIView] {
            if view.tag == btag + 1000
            {
                if var vt = viewz[view.tag]
                {
                    vt.toggle()
                    viewz[view.tag] = vt
                    //handle anim here?
                    var ydel = vt.smallHeight-vt.bigHeight
                    if vt.expanded {ydel = -1 * ydel}
                    animateViewFrames(tag: view.tag,ydel: ydel)
                }
            } //end if view
        } //end for view
        updateViewFrames()
    } //end toggleViewSize
    
    //=====PatchEditorVC===========================================
    func updateViewsBasedOnPatchType()
    {
        let needWave   = (opatch.type == SYNTH_VOICE)
        let needADSR   = (opatch.type == SAMPLE_VOICE ||
                          opatch.type == SYNTH_VOICE)
        let needSample = (opatch.type == SAMPLE_VOICE ||
                          opatch.type == PERCUSSION_VOICE)
        let needPercLoox = (opatch.type == PERCKIT_VOICE)
        //handle wave:
        if var vz = viewz[waveViewTag]
        {
            vz.setCanExpand(flag: needWave)
            viewz[waveViewTag] = vz //store back in dictionary
        }
        //handle adsr:
        if var vz = viewz[adsrViewTag]
        {
            vz.setCanExpand(flag: needADSR)
            viewz[adsrViewTag] = vz //store back in dictionary
        }
        //handle sample:
        if var vz = viewz[sampleViewTag]
        {
            vz.setCanExpand(flag: needSample)
            viewz[sampleViewTag] = vz //store back in dictionary
        }
        //handle percloox:
        if var vz = viewz[perclooxViewTag]
        {
            vz.setCanExpand(flag: needPercLoox)
            viewz[perclooxViewTag] = vz //store back in dictionary
        }
        updateViewArrows()
        updateViewFrames()
        
        adsrToggle.isEnabled = needADSR
        adsrImage.isHidden   = !needADSR
    } //end updateViewsBasedOnPatchType
    
    //=====PatchEditorVC===========================================
    // Takes single expanded/shrunk frame, sets its height,
    //   updates next top position
    func updateViewFrame(nextTop : Int , v:UIView , vt: ViewSetup ) -> Int
    {
        if v.tag < 1000 {return nextTop}
        var f = v.frame
        
        if (vt.expanded)
        {
            f.size.height = CGFloat(vt.bigHeight)
        }
        else
        {
            f.size.height = CGFloat(vt.smallHeight)
        }
        f.origin.y = CGFloat(nextTop)
        v.frame = f
        return Int(f.origin.y + f.size.height)
    } //end updateViewFrame
    
    //=====PatchEditorVC===========================================
    // places views based on their expanded / shrunk size
    func updateViewFrames()
    {
        var nextTop = firstTop
        var c = 0
        var viewC = 0
        while (c < 1+viewz.count)
        {
            if let view = scrollView.viewWithTag(1100+viewC) //Get our next sizeable view...
            {
                if let vz = viewz[1100+viewC]
                {
                    nextTop = 10 +  updateViewFrame(nextTop: nextTop, v: view, vt: vz)
                }
                viewC = viewC + 1
            }
           c = c + 1
        }
        //Make sure scroller fits!
        scrollView.contentSize = CGSize(width: 410, height: nextTop)

    } //end updateViewFrames

    //=====PatchEditorVC===========================================
    // shrink/expand a view. but first, all views BELOW must move down!
    func animateViewFrames(tag : Int , ydel : Int)
    {
        //Ouch. first find END tag...
        for (ttag,vz) in viewz
        {
            var f = vz.view.frame
            var animateIt = false
            if ttag > tag // this view is below our target view? animate up/down
            {
                f.origin.y += CGFloat(ydel)
                animateIt = true
            }
            else if ttag == tag //target view? Change size
            {
                f.size.height += CGFloat(ydel)
                animateIt = true
            }
            if animateIt
            {
                animCount+=1
                UIView.animate(withDuration: animShiftTime, delay: 0.0, options: [], animations: {
                     vz.view.frame = f
                }, completion: { (finished: Bool) in
                    //print("shiftduh")
                    self.animCount-=1
                })
//                UIView.animate(withDuration: animShiftTime) {
//                    vz.view.frame = f
//                }
            }
        }
    }
    

    //=====PatchEditorVC===========================================
    func updateViewArrows()
    {
        var c = 0
        var viewC = 0
        while (c < 1+viewz.count)
        {
            if let view = scrollView.viewWithTag(1100+viewC) //Get our next sizeable view...
            {
                if let bv = view.viewWithTag(100+viewC)
                {
                    if let button = bv as? UIButton{
                        if let vz = viewz[1100+viewC]
                        {
                            rotate90(bb: button,clockwise: vz.expanded , dur: animRotTime1)
                        }
                    }
                }
                viewC = viewC + 1
            }
            c = c + 1  //get next view...
        } //end for view
    } //end updateViewArrows
    
    //=====PatchEditorVC===========================================
    // NOTE synth must be set up first!
    func playTestNote(midiNote : Int)
    {
        //print("play note \(midiNote)")
        setupSynthOrSample()
        var bptr = (sfx() as! soundFX).getWorkBuffer()
        (sfx() as! soundFX).setSynthGain(128)
        (sfx() as! soundFX).setSynthPan(128)
        var noteToPlay  = midiNote
        //some patches need octave changes
        let gMidiOffset = allP.getOffsetForGMPatch(name:opatch.name)
        //print("name \(opatch.name) offset \(gMidiOffset)")
        if (opatch.type == SAMPLE_VOICE)
        {
            (sfx() as! soundFX).setSynthSampOffset(Int32(opatch.sampleOffset))
            (sfx() as! soundFX).setSynthDetune(1);
        }
        else if (opatch.type == PERCUSSION_VOICE)
        {
            (sfx() as! soundFX).setSynthDetune(0); //11/17 no detune!
        }
        else if (opatch.type == PERCKIT_VOICE)
        {
            var octave = (midiNote - 20) / 12
            if (octave < 0 || octave > 7) {octave = 0}
            let pName = opatch.percLoox[octave]
            //Dont use work buffer, use built-in samples
            bptr  = (sfx() as! soundFX).getPercussionBuffer(pName.lowercased())
            noteToPlay = 64
            (sfx() as! soundFX).setSynthPan(Int32(opatch.percLooxPans[octave]))
            (sfx() as! soundFX).setSynthDetune(0);  //11/17 no detune???
        }
        //Apply octave offset, if any..
        noteToPlay = noteToPlay + gMidiOffset
        //print("final note to play \(noteToPlay)")
        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(opatch.type))
    } //end playTestNote

    //=====PatchEditorVC===========================================
    func playTestNote2(midiNote : Int)
    {
        print("play note \(midiNote) needadsr \(needToUseADSR)")
        setupSynthOrSample()
        var bptr = (sfx() as! soundFX).getWorkBuffer()
        (sfx() as! soundFX).setSynthGain(128)
        (sfx() as! soundFX).setSynthPan(128)
        var noteToPlay = midiNote
        
        //11/16 still need to add offsets for 11025HZ perc samples!
        var  gMidiOffset = 0
        (sfx() as! soundFX).setSynthDetune(1);  //11/17 detuneable!
        // 11/22 redid logic here, perc and sample both need gmidioffset for various reasons
        if (opatch.type == PERCUSSION_VOICE)
        {
            gMidiOffset = allP.getOffsetForGMPatch(name:opatch.name)
            (sfx() as! soundFX).setSynthDetune(0); //11/17 no detune!
        }
        else if (opatch.type == SAMPLE_VOICE)
        {
            gMidiOffset = allP.getOffsetForGMPatch(name:opatch.name)
            (sfx() as! soundFX).setSynthSampOffset(Int32(opatch.sampleOffset))
            (sfx() as! soundFX).setSynthDetune(1);
        }
        else if (opatch.type == PERCKIT_VOICE)
        {
            var octave = (midiNote - 20) / 12
            if (octave < 0 || octave > 7) {octave = 0}
            let pName = opatch.percLoox[octave]
            //11/22 perc kit is special, has a bunch of names!
            gMidiOffset = allP.getOffsetForGMPatch(name:pName)
            //Dont use work buffer, use built-in samples
            bptr  = (sfx() as! soundFX).getPercussionBuffer(pName.lowercased())
            noteToPlay = 64
            (sfx() as! soundFX).setSynthPan(Int32(opatch.percLooxPans[octave]))
            (sfx() as! soundFX).setSynthDetune(0);  //11/17 no detune???
        }
        noteToPlay = noteToPlay + gMidiOffset
        (sfx() as! soundFX).playNote(Int32(noteToPlay), Int32(bptr) ,Int32(opatch.type))
     } //end playTestNote
    
    //=====PatchEditorVC===========================================
    func setupTestLoop(choice : Int)
    {
        playMode = choice
        if playMode > 0
        {
            switch(playMode)
            {
                case 1: notesToLoopOver  = basicNotes
                case 2: notesToLoopOver  = scaleNotes
                case 3: notesToLoopOver  = octaveNotes
                default: notesToLoopOver = basicNotes
            }
            noteIndex = 0
            playTimer.invalidate()
            playTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.playNextLoopedNote), userInfo:  nil, repeats: true)
            playLooping = true
        }
        else
        {
            stopTestLoop()
        }
    }
    
    //=====PatchEditorVC===========================================
    func stopTestLoop()
    {
        playTimer.invalidate()
        playLooping = false
        playPicker.selectRow(0, inComponent: 0, animated:false)
        (sfx() as! soundFX).releaseAllNotes()
    }
    
    //=====PatchEditorVC===========================================
    // called by timer, plays automagically generated note,
    //  either from an array or randomized
    @objc func playNextLoopedNote()
    {
        var nextNote = 0
        if (playMode < 4) //Fixed array to loop over?
        {
            nextNote = notesToLoopOver[noteIndex]
            noteIndex = (noteIndex + 1) % notesToLoopOver.count
        }
        else
        {
            nextNote = Int(Double.random(in:20.0...100.0))
        }
        playTestNote(midiNote: nextNote)
    } //end playNextLoopedNote
    
    
    //=====PatchEditorVC===========================================
    func setTextParamByTag(textField: UITextField)
    {
        let tag  = textField.tag
        let name = textField.text!
        switch(tag)  //Tags are 20... for misc text fields
        {
        case 20: patchName   = name
        case 21: opatch.name = name
        default: return
        }
    }
    
    //=====PatchEditorVC===========================================
    // if patch file exists, prompts for action, saves otherwise
    func checkPatchAndSave()
    {
        //11/14 use allpatches test for exist
        if allP.patchExists(name:patchName) { replacePatchPrompt()  }
        else //New patches go to user area!! asdf
        {
            allNew = false //Indicate we have at least one replaced patch!
            allP.addNewUserPatch (p : opatch , n : patchName) // 11/17 update allpatches!
            patchInfo.category = "US" //This patch just became a user patch!
            packupAndSavePatch(pName:patchName)
        }
    } //end checkPatchAndSave
    
    //=====PatchEditorVC===========================================
    func replacePatchPrompt()
    {
        var msg = umsg //user message
        if let pi = allP.patchInfoDict[patchName] //Got info?
        {
            if pi.builtin { msg = bmsg}  //izzit builtin? set message
        }
        else
        {
            print("Err: looking up patch")
        }
        //FIX 11/14  if PatchieInfo
        let alert = UIAlertController(title: "Patch \(patchName) Exists, Replace?", message: msg,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Replace", style: .default, handler: { action in
            self.packupAndSavePatch(pName:self.patchName)
        }))
        alert.addAction(UIAlertAction(title: "Make Copy", style: .default, handler: { action in
            self.packupAndSaveCopyOfPatch()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }  //end deleteVoicePrompt

    //=====PatchEditorVC===========================================
    func resetScrollAndPromptForPatchName()
    {
        scrollView.setContentOffset(CGPoint(x: 0,y: 0), animated: false)
        nameText.text = ""
        nameText.becomeFirstResponder() //Put up KB for new name
    }
    
    //=====PatchEditorVC===========================================
    //Look at patchName, get fresh copy name from allpatches
    func packupAndSaveCopyOfPatch()
    {
        let nname = allP.getNewNameForCopy(n : patchName)
        packupAndSavePatch(pName: nname) //Save with our new name
    } //end packupAndSaveCopyOfPatch

    
    //=====PatchEditorVC===========================================
    // Assumes patch OK to save...
    func packupAndSavePatch(pName:String)
    {
        _ = opatch //debug
        //Samples with no ADSR, clear some fields
        if (opatch.type == SAMPLE_VOICE) && (!needToUseADSR)
        {
            opatch.attack  = 0
            opatch.decay   = 0
            opatch.sustain = 0
            opatch.sLevel  = 0
            opatch.release = 0
        }
        let ufolder = DataManager.getPatchDirectory() //user patch area...
        print("user folder \(ufolder)")

        //        patchInfo = getFreshPatchinfo()
        //get a folder destination...
        _ = patchInfo //for debugger
        _ = allP.getCategoryFolderName(n: patchInfo.category)
        //Note patchName is different from internal name
        opatch.saveItem(filename: pName , cat: patchInfo.category)
        //Add filename to our saved names array...
        if !newPatchNamez.contains(patchName) {newPatchNamez.append(pName)}
        delegate?.patchEditVCSavePatchNow(name: pName)
        // 11/13 mark change in allpatches...
        allP.changedAPatch (name:pName)
        showSavedPatchAlert()   //11/15

        //asdf
    } //end packupAndSavePatch

    //=====PatchEditorVC===========================================
    func showSavedPatchAlert()
    {
        let alert = UIAlertController(title: "Saved Patch \(patchName)", message: "",
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    
    //Work functions...
    //=====PatchEditorVC===========================================
    public func createADSRImage(frame:CGRect , vals : [Float]) -> UIImage {
        let colorz : [UIColor] = [.green,.red,.blue,.red]
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        //Fill bkgd
        context.setFillColor(UIColor.clear.cgColor);
        context.fill(frame);
        
        let step   = frame.size.width / CGFloat(vals.count)
        let yscale = frame.size.height
        //draw chart with tiny rects...
        
        var segment = 0
        var x = CGFloat(0.0)
        var oldval : Float = 0.0
        for val in vals
        {
            var nextval = val
            if val < 0 //next phase of envelope? switch color
            {
                nextval = oldval
                segment = Int(abs(val)) //We send segment back in the adsr output!
                segment = min(3,max(0,segment))
            }
            let yval = CGFloat(nextval)*yscale
            let r = CGRect(x: x, y: yscale-yval , width: step, height: yval)
            context.drawBoxGradient(in: r, startingWith: colorz[segment].cgColor, finishingWith: UIColor.black.cgColor)
            //context.fill(r);   //for solid fill
            x = x + step
            oldval = nextval
        }
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createADSRImage

    //=====PatchEditorVC===========================================
    func setupSynthOrSample()
    {
        let wbptr = (sfx() as! soundFX).getWorkBuffer()
        var bptr = 0
        //print("PE:setupSynthOrSample \(opatch.type)")
        if opatch.type == SYNTH_VOICE
        {
            (sfx() as! soundFX).setSynthAttack(Int32(opatch.attack));
            (sfx() as! soundFX).setSynthDecay(Int32(opatch.decay));
            (sfx() as! soundFX).setSynthSustain(Int32(opatch.sustain));
            (sfx() as! soundFX).setSynthSustainL(Int32(opatch.sLevel));
            (sfx() as! soundFX).setSynthRelease(Int32(opatch.release));
            (sfx() as! soundFX).setSynthDuty(Int32(opatch.duty));
            //print("build wave/env ADSR \(opatch.attack) :  \(opatch.decay) :  \(opatch.sustain) :  \(opatch.release)")
            (sfx() as! soundFX).buildaWaveTable(Int32(bptr),Int32(opatch.wave));  //args whichvoice,whichsynth
            //print("SYNTH Build Envelope \(opatch.name) bptr \(Int(bptr))")
            (sfx() as! soundFX).buildEnvelope(Int32(bptr),true); //arg whichvoice?
            envelopeChanged = true  //11/13
            //print("swave \(opatch.wave)")
        }
        else if (opatch.type == PERCKIT_VOICE)
        {
            //DHS 2/28 pull crap here
        }
        else if (opatch.type == PERCUSSION_VOICE)
        {
            //DHS 10/14 set up pointer to percussion sample...
            bptr = Int((sfx() as! soundFX).getPercussionBuffer(opatch.name))
        }
        else if (opatch.type == SAMPLE_VOICE)
        {
            let aaa = needToUseADSR ? opatch.attack  : 0
            let ddd = needToUseADSR ? opatch.decay   : 0
            let sss = needToUseADSR ? opatch.sustain : 0
            let rrr = needToUseADSR ? opatch.release : 0
            (sfx() as! soundFX).setSynthAttack(Int32(aaa)); //10/17 add ADSR
            (sfx() as! soundFX).setSynthDecay(Int32(ddd));
            (sfx() as! soundFX).setSynthSustain(Int32(sss));
            (sfx() as! soundFX).setSynthSustainL(Int32(opatch.sLevel));
            (sfx() as! soundFX).setSynthRelease(Int32(rrr));
            (sfx() as! soundFX).setSynthDuty(Int32(opatch.duty));

            //DHS 10/14 set up pointer to GM sample...
            bptr = Int((sfx() as! soundFX).getGMBuffer(opatch.name))
            if needToUseADSR
            {
                //print("Build Envelope \(opatch.name) bptr \(Int(bptr))")
                (sfx() as! soundFX).buildEnvelope(Int32(bptr),true); //arg whichvoice?
                envelopeChanged = true  //11/13
            }
        } //end else voice type
        if bufferChanged
            {(sfx() as! soundFX).copyBuffer(Int32(bptr),Int32(wbptr),needNewBuffer) //Don't need this every time?
                bufferChanged = false
                needNewBuffer = false
            }
        if envelopeChanged && (opatch.type == SYNTH_VOICE || opatch.type == SAMPLE_VOICE)
            {(sfx() as! soundFX).copyEnvelope(Int32(bptr),Int32(wbptr)) //Don't need this every time?
                //print("done did copy envelope \(bptr) -> \(wbptr)")
                envelopeChanged = false
                updateADSRDisplay()
            }
    } //end setupSynthOrSample

    
    //=======<UIPickerViewDelegate>===========================
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    //=======<UIPickerViewDelegate>===========================
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        let tag = pickerView.tag
        if (tag == 10) {return  typePickerValues.count}
        if (tag == 11) {return  wtypePickerValues.count}
        if (tag == 12) {return  playPickerValues.count}
        return 0
    }
    //=======<UIPickerViewDelegate>===========================
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let tag = pickerView.tag
        if (tag == 10) {return typePickerValues[row]}
        if (tag == 11) {return wtypePickerValues[row]}
        if (tag == 12) {return playPickerValues[row]}
        return ""
    }
    //=======<UIPickerViewDelegate>===========================
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let tag = pickerView.tag
        if (tag == 10) //Voice type
        {
            opatch.type = row //Need 2 validate !
            //Handle UI changes for type change!
            updateViewsBasedOnPatchType()
            needNewBuffer = true
            bufferChanged = true
        }
        if (tag == 11) //Wave Type
        {
            opatch.wave = row //Need 2 validate !
            bufferChanged = true
        }
        if (tag == 12) //Wave Type
        {
            setupTestLoop(choice: row)
        }
    } //end picker didSelectRow
    
   
    //---<UITextFieldDelegate>--------------------------------------
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        //print("start editing text \(textField.tag)")
        textField.text = "" //Clear shit out
        return true
    }
    
    //---<UITextFieldDelegate>--------------------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //print("return on text \(textField.tag)")
        textField.resignFirstResponder() //dismiss kb if up
        setTextParamByTag(textField: textField)
        updateForPatchInfo() //11/12 set factory button if needed
        return true
    }

    //---<UITextFieldDelegate>--------------------------------------
    @IBAction func textChanged(_ sender: Any) {
        let tf = sender as! UITextField
        //print("text field changed \(tf.tag)")
        //11/15 make sure name is updated
        setTextParamByTag(textField: tf)

    }

    func handleIncomingSampleName(name:String)
    {
        print("chose \(name)")
        let ss = name.split(separator: ".")
        var fname = name  //start assuming we just name...
        if ss.count == 2 //name consists of pair separated by a dot?
        {   fname = String(ss[0]).lowercased() }   //use first field
        
        //Choose a patch? Different from sample choosing!
        if sampleChooserTag == -1
        {
            print("loading patch \(name)...")
            patchName = name //Assumes file exists, was just chosen!
            opatch    = DataManager.loadPatch(url: DataManager.getPatchDirectory(), with: patchName, with: OogiePatch.self)
            setFieldsFromPatch()  //Redo UI
            playTestNote(midiNote: 64) //need to ping!
        }
        else //Sample / PercKit patch name? just store name
        {
            print("handle incoming sample name...")
            //button to get sample, tag 31...38?
            // matches label        tag  1... 8
            //set label!
            let index = sampleChooserTag-31  //Which field?
            if index < 8
            {
                opatch.percLoox[index] = fname
            }
            else if index == 8 //Sample name
            {
                opatch.name = fname
            }
            //Set matching text field in UI
            let pkLabel = scrollView.viewWithTag(index+1)
            if let pkl = pkLabel as? UILabel{
                pkl.text = fname
            }
            
        } //end else
        
    }

    
    
//    func newFolderContents(c: [String])
//    func choseFile(name: String)
//    func needToSaveFile(name: String)


    func loadPatchFromChooserAndUpdateUI (name : String)
    {
        opatch = allP.getPatchByName(name: name)
        allP.dumpBuiltinPatch(n: name)
        patchName = name
        //ADSR present? Use it! 11/13
        needToUseADSR = (opatch.attack  > 0)  || (opatch.decay   > 0) ||
                        (opatch.sustain > 0)  || (opatch.release > 0) ||
                        (opatch.sLevel  > 0)
        print("setupfor file \(name) adsr \(needToUseADSR)")

        DispatchQueue.main.async {   //UI stuff goes on main thread
            self.setFieldsFromPatch()
            self.updateForPatchInfo()  //ask allpatches if new patch info came in

            self.updateViewsBasedOnPatchType() //this changes subview sizes!
            self.playTestNote(midiNote: 64)
        }

    } //end loadPatchFromChooserAndUpdateUI
    

    //---<chooserDelegate>--------------------------------------
    func chooserCancelled()
    {
       print("chooser cancel")
    }

    //---<chooserDelegate>--------------------------------------
    //Delegate callback from Chooser... handles multiple
    //   filetypes
    func chooserChoseFile(name: String)
    {
        if chooserMode == "loadAllPatches"
        {
            if patchNamez.count > 0  //11/17
            {
                if let pn = patchNamez.index(of: name) //got a legit find?
                {
                    patchNum = pn
                }
            }
            loadPatchFromChooserAndUpdateUI(name: name)
        }
        else //sample name?
        {
            handleIncomingSampleName(name: name)
        }
       //patch load? Do we need to update EVERYTHING?
        //For sample reload
        needNewBuffer = true
        bufferChanged = true
    }

    //---<chooserDelegate>--------------------------------------
    func newFolderContents(c: [String])
    {
        patchNamez = c
        patchNum = 0

    }
    
    //allPatchNamesFromChooser
    //---<chooserDelegate>--------------------------------------
    //Delegate callback from Chooser...
    func needToSaveFile(name: String) {

    }

    
    
} //end class


extension CGContext {
  func drawBoxGradient(
    in rect: CGRect,
    startingWith startColor: CGColor,
    finishingWith endColor: CGColor
  ) {
    // 1
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 2
    let locations = [0.0, 1.0] as [CGFloat]

    // 3
    let colors = [startColor, endColor] as CFArray

    // 4
    guard let gradient = CGGradient(
      colorsSpace: colorSpace,
      colors: colors,
      locations: locations
    ) else {
      return
    }
      let startPoint = CGPoint(x: rect.midX, y: rect.minY)
      let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
          
      // 6
      saveGState()

      // 7
      addRect(rect)
      clip()
      drawLinearGradient(
        gradient,
        start: startPoint,
        end: endPoint,
        options: CGGradientDrawingOptions()
      )

      restoreGState()  }
    
}

