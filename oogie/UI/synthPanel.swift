//                   _   _     ____                  _
//   ___ _   _ _ __ | |_| |__ |  _ \ __ _ _ __   ___| |
//  / __| | | | '_ \| __| '_ \| |_) / _` | '_ \ / _ \ |
//  \__ \ |_| | | | | |_| | | |  __/ (_| | | | |  __/ |
//  |___/\__, |_| |_|\__|_| |_|_|   \__,_|_| |_|\___|_|
//       |___/
//
//  synthPanel.swift
//  oogie2D
//
//  Created by Dave Scruton on 8/1/19.
//

import UIKit

class synthPanel: UIView {

    @IBOutlet weak var infoLabel: UILabel!
 
    @IBOutlet weak var dButton: UIButton!
    // @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var slSlider: UISlider!
    @IBOutlet weak var wSlider:  UISlider!
    @IBOutlet weak var duSlider: UISlider!
    @IBOutlet weak var aSlider:  UISlider!
    @IBOutlet weak var dSlider:  UISlider!
    @IBOutlet weak var sSlider:  UISlider!
    @IBOutlet weak var rSlider:  UISlider!
    var wave    = 1
    var attack  = 0.0
    var decay   = 0.0
    var sustain = 0.0
    var release = 0.0
    var sLevel  = 0.0
    var duty    = 0.0
    let sliderMult    = Float(100.0)
    let invSliderMult = Float(0.01)
    var sfx = soundFX.sharedInstance
    var OV = OogieVoice()

    
    //====<synthPanel>====================================
    func setup()
    {
        loadFieldsFromVoice()
        setSliders()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    func loadFieldsFromVoice()
    {
        attack  = OV.OOP.attack
        decay   = OV.OOP.decay
        sustain = OV.OOP.sustain
        release = OV.OOP.release
        sLevel  = OV.OOP.sLevel
        duty    = OV.OOP.duty
        wave    = OV.OOP.wave
    }
    
    //====<synthPanel>====================================
    func loadVoiceFromFields()
    {
        OV.OOP.attack  = attack
        OV.OOP.decay   = decay
        OV.OOP.sustain = sustain
        OV.OOP.release = release
        OV.OOP.sLevel  = sLevel
        OV.OOP.duty    = duty
        OV.OOP.wave    = wave
    }
    
    //====<synthPanel>====================================
    func setSliders()
    {
        aSlider.value  = invSliderMult * Float(attack)
        dSlider.value  = invSliderMult * Float(decay)
        sSlider.value  = invSliderMult * Float(sustain)
        rSlider.value  = invSliderMult * Float(release)
        slSlider.value = invSliderMult * Float(sLevel)
        duSlider.value = invSliderMult * Float(duty)
    }
    
    //====<synthPanel>====================================
    @IBAction func dismissSelect(_ sender: Any)
    {
        self.isHidden = true
    }
    


    //====<synthPanel>====================================
    @IBAction func b52Select(_ sender: Any) {
        loadVoiceFromFields()
        setupSynth()
        (sfx() as! soundFX).playNote(64,0,SYNTH_VOICE)
    }
    
    //====<synthPanel>====================================
    @IBAction func b64Select(_ sender: Any) {
        loadVoiceFromFields()
        setupSynth()
        (sfx() as! soundFX).playNote(76,0,SYNTH_VOICE)

    }
    
    //====<synthPanel>====================================
    @IBAction func b76Select(_ sender: Any) {
        loadVoiceFromFields()
        NSLog(" play note 76");
        setupSynth()
        (sfx() as! soundFX).playNote(88,0,SYNTH_VOICE)
    }
    
    //====<synthPanel>====================================
    @IBAction func wSliderChanged(_ sender: Any) {
        wave = Int(8.0 * wSlider.value)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func slSliderChanged(_ sender: Any) {
        sLevel = Double(slSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func duSliderChanged(_ sender: Any) {
        duty = Double(duSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func aSliderChanged(_ sender: Any) {
        attack = Double(aSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func dSliderChanged(_ sender: Any) {
        decay = Double(dSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func sSliderChanged(_ sender: Any) {
        sustain = Double(sSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    @IBAction func rSliderChanged(_ sender: Any) {
        release = Double(rSlider.value * sliderMult)
        loadVoiceFromFields()
        updateLabel()
    }
    
    //====<synthPanel>====================================
    func updateLabel()
    {
        let iia   = Int(attack )
        let iid   = Int(decay )
        let iis   = Int(sustain )
        let iir   = Int(release )
        let iisl  = Int(sLevel )
        let iidu  = Int(duty )
        var wname = ""
        
        switch (Int(wave))
        {
            case 0:wname  = "Ramp"
            case 1:wname  = "Sine"
            case 2:wname  = "Saw"
            case 3:wname  = "Square"
            case 4:wname  = "Noise"
            case 5:wname  = "SinxCosy"
            default:wname = "Ramp"
        }
        let lstr = "\(wname) ADSR \(iia),\(iid),\(iis),\(iir),SL/DU \(iisl),\(iidu),"
        infoLabel.text = lstr
    }
    
    //=====<oogie2D mainVC>====================================================
    func setupSynth()
    {
        (sfx() as! soundFX).setSynthAttack(Int32(OV.OOP.attack));
        (sfx() as! soundFX).setSynthDecay(Int32(OV.OOP.decay));
        (sfx() as! soundFX).setSynthSustain(Int32(OV.OOP.sustain));
        (sfx() as! soundFX).setSynthSustainL(Int32(OV.OOP.sLevel));
        (sfx() as! soundFX).setSynthRelease(Int32(OV.OOP.release));
        (sfx() as! soundFX).setSynthDuty(Int32(OV.OOP.duty));
        (sfx() as! soundFX).buildaWaveTable(0,Int32(OV.OOP.wave));  //args whichvoice,whichsynth
        (sfx() as! soundFX).buildEnvelope(0,false); //arg whichvoice?
    }

}
