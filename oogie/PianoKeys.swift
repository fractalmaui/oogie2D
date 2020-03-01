//
//   ____  _                   _  __
//  |  _ \(_) __ _ _ __   ___ | |/ /___ _   _ ___
//  | |_) | |/ _` | '_ \ / _ \| ' // _ \ | | / __|
//  |  __/| | (_| | | | | (_) | . \  __/ |_| \__ \
//  |_|   |_|\__,_|_| |_|\___/|_|\_\___|\__, |___/
//                                      |___/
//
//  PianoKeys.swift
//  oogie2D
//
//  Created by Dave Scruton on 2/27/20.
//  Copyright © 2020 fractallonomy All rights reserved.
//
//  2/29 integrate with oogie2D

import Foundation
import SceneKit

class PianoKeys: SCNNode {

    let octWid : CGFloat = 1.4
    let keyWid : CGFloat = 0.11666   //octWid / 12
    var bottomMidi       = 12     //C0
    var topMidi          = 108    //C8
    var lastNoteName     = ""
    private var centerMidi = 0
    let keysYoff         : CGFloat = -3.0
    var colorBarImage    = UIImage()
    //Array of colors, lined up with keyboard over bottom-top range
    var colorz256 : [UIColor] = []
    let noteNames : [String] = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

    
    let oneDiv255 = 1.0 / 255.0
    
    //-----------(PianoKeys)=============================================
    override init() {
        super.init()
        createKB(nMode:3)
    }

    //-----------(PianoKeys)=============================================
    func createKB(nMode:Int)
    {
        loadUpColorz(nMode: nMode) //3 = hue (default)
        colorBarImage = createColorBarImage(ll: 0.5, ss: 1.0)
        centerMidi      = (bottomMidi + topMidi) / 2
        let octave0     = (bottomMidi - 12) / 12
        let octave1     = (topMidi - 12) / 12
        var numOctaves  = octave1 - octave0
        if bottomMidi%12 != 0 || topMidi%12 != 0 {
            numOctaves = numOctaves + 1
        }
        let kb = createFlatKB(octaves: numOctaves)
        self.addChildNode(kb)

        let cb = createColorBoxWithLabels(bm:bottomMidi , tm:topMidi)
        self.addChildNode(cb)
        
        //Rotate about X axis so KB is parallel with "floor"
        self.eulerAngles = SCNVector3Make(-Float.pi / 2.0 , 0, 0)
        // shift down too...
        self.position    = SCNVector3(0,keysYoff,0)
        self.name        = "pianoKeys" //for touch recognition

   }
    
    //-----------(PianoKeys)=============================================
    // Takes incoming hitCoords in local space, determines key pressed
    public func getTouchedMidiNote( hitCoords : SCNVector3) -> Int
    {
        let kxd      = hitCoords.x
        let keyXoff  = kxd / Float(keyWid)  //should be a keycount now
        let mnote    = centerMidi + Int(keyXoff)
        lastNoteName = getNoteNameFromMidiNote(n: mnote) //for external use
        return mnote
    }
    
    
    //-----------(PianoKeys)=============================================
    private func getNoteNameFromMidiNote (n:Int) -> String
    {
        let scaleNote = n % 12
        let octave    = (n / 12) - 1
        return String(format: "%@%d", noteNames[scaleNote],octave)
    }
    
    //-----------(PianoKeys)=============================================
    //Takes midiNote input, produces bitmap with Chromatic key value
    public func createMidiNoteImage(midiNote : Int) -> UIImage {
        let bmpsize = 128
        let isize = CGSize(width: bmpsize, height: bmpsize) // Overall bmp size, canned
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        //Fill white bkgd
        context.setFillColor(UIColor.white.cgColor);
        context.fill(CGRect(origin: CGPoint.zero, size: isize));
        
        let thite = 70   //height of label
        let textColor = UIColor.black
        let textFont  = UIFont(name: "Helvetica Bold", size: CGFloat(thite))!
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: text_style
            ] as [NSAttributedString.Key : Any]
        
        let trect =  CGRect(x: 0, y: Int(Double(bmpsize)*0.2), width: bmpsize, height: Int(Double(bmpsize)*0.6))
        let label = getNoteNameFromMidiNote(n: midiNote)
        label.draw(in: trect, withAttributes: textFontAttributes)
       
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createMidiNoteImage

    //-----------(PianoKeys)=============================================
    // On voice change, delete old keys/colorbox, recreate...
    func resetForVoice( nMode : Int , bMidi : Int , tMidi : Int)
    {
        //print(" kb reset mode \(nMode) midi \(bMidi) to \(tMidi)")
        //Remove keys / colorbar
        self.enumerateChildNodes { (node, _) in
            if (node.name != nil) {node.removeFromParentNode()}
        }
        loadUpColorz(nMode: nMode)
        colorBarImage = createColorBarImage(ll: 0.5, ss: 1.0)
        bottomMidi    = bMidi
        topMidi       = tMidi
        createKB(nMode:nMode)
    }
    
    //-----------(PianoKeys)=============================================
     required init?(coder aDecoder: NSCoder) {
         super.init(coder: aDecoder)
     }


    //-----------(PianoKeys)=============================================
    private func createColorBarImage(ll:Float,ss:Float) -> UIImage {

         let isize = CGSize(width: 256, height: 256) // Overall bmp size, canned
         UIGraphicsBeginImageContextWithOptions(isize, false, 1)
         let context = UIGraphicsGetCurrentContext()!
         //Fill clear bkgd
         context.setFillColor(UIColor.clear.cgColor);
         context.fill(CGRect(origin: CGPoint.zero, size: isize));

         let numslices: Float  = 256.0
         let xstep : Float = 1.0

         for i in 0..<Int(numslices)
         {
             let cc = colorz256[i];
             context.setFillColor(cc.cgColor);
             let rr = CGRect(x: CGFloat(i)*CGFloat(xstep), y: 0,
                             width: CGFloat(xstep), height: CGFloat(numslices))
            
             context.fill(rr)
         }
         
         let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
         UIGraphicsEndImageContext()
         return resultImage
     } //end createColorBarImage

    //-----------(PianoKeys)=============================================
    private func loadUpColorz(nMode : Int)
    {
        colorz256.removeAll()
        if nMode == 3 //hue is special
        {
            for i in 0...255
            {
                let rgbtuple = hslToRgb(h: Float(i) * Float(oneDiv255), s: 0.5, l: 0.5)
                colorz256.append( UIColor.init(red: CGFloat(rgbtuple.r), green: CGFloat(rgbtuple.g), blue: CGFloat(rgbtuple.b), alpha: 1.0))
            }
        }
        else //linear color ranges...
        {
            var rmult :Float = 0.0
            var gmult :Float = 0.0
            var bmult :Float = 0.0
            switch(nMode)
            {
            case 0: rmult = 1.0 //red
            case 1: gmult = 1.0 //green
            case 2: bmult = 1.0 //blue
            case 6: gmult = 1.0 ; bmult = 1.0 //cyan
            case 7: rmult = 1.0 ; bmult = 1.0 //magenta
            case 8: rmult = 1.0 ; gmult = 1.0 //yellow
            default: // default, rgb greyscale
                    rmult = 1.0 ;gmult = 1.0;bmult = 1.0//red
            }
            for i in 0...255
            {
                let multrgb = Float(i) * Float(oneDiv255)
                colorz256.append( UIColor.init(red: CGFloat(rmult*multrgb),
                                               green: CGFloat(gmult*multrgb),
                                               blue: CGFloat(bmult*multrgb),
                                               alpha: 1.0))

            }

        }
        
    } //ebd loadUpColorz

    //-----------(PianoKeys)=============================================
    private func hue2rgb(p:Float,q:Float,t:Float) -> Float
    {
        var tt = t;
        if(tt < 0.0) {tt += 1.0}
        if(tt > 1.0) {tt -= 1.0}
        if(tt < 1.0/6.0) {return p + (q - p) * 6.0 * tt}
        if(tt < 1.0/2.0) {return q}
        if(tt < 2.0/3.0) {return p + (q - p) * (2.0/3.0 - tt) * 6.0}
        return p;
    } //end hue2rgb\\


    //-----------(PianoKeys)=============================================
    private func hslToRgb(h:Float, s:Float, l:Float) -> (r:Float , g:Float , b:Float)
    {
        var r:Float = 0.0
        var g:Float = 0.0
        var b:Float = 0.0

        if s == 0
        {
            r = l
            g = l
            b = l
        }
        else{
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            let p = 2 * l - q;
            r = hue2rgb(p: p, q: q, t: h + 1/3);
            g = hue2rgb(p: p, q: q, t: h);
            b = hue2rgb(p: p, q: q, t: h - 1/3);
        }

        return (r,g,b);
    } //end hslToRgb


    //--flatkeys-----------------------------------------------
    // Hmm needs to line up w keyboard, just use top/bottom midi?
    func createColorBoxWithLabels(bm:Int , tm:Int) -> SCNNode
    {
        let parent = SCNNode()
        let cbox = SCNBox(width: 1.0, height: octWid*0.3, length: octWid*0.1, chamferRadius: 0)
        cbox.firstMaterial?.diffuse.contents  =  colorBarImage
        cbox.firstMaterial?.emission.contents =  colorBarImage
        // # notes between outer bottomMidi <--> topMidi range and nearest octave
        let bmidi = bm
        let tmidi = tm
        let lhOffset = bmidi%12
        var rhOffset = tmidi%12
        if rhOffset != 0 {rhOffset = 12-rhOffset}
        let boxWid   = keyWid*CGFloat(tm-bm);
        let xoff     = CGFloat(lhOffset-rhOffset) * (keyWid/2);
        let cnode    = SCNNode(geometry: cbox)
        cnode.scale  = SCNVector3(boxWid,1,1)
        parent.addChildNode(cnode)
        //print ("bm \(bm)  tm \(tm) kw \(keyWid) xoff \(xoff) boxWid \(boxWid) , boxoff \(xoff/boxWid)")
        parent.position = SCNVector3(xoff,octWid * 1,0)

        //Box on LH side with bMidi label
        let boxlwh = octWid*0.3
        let nxoff  = boxWid*0.5 + 0.5 * boxlwh
        let ltex = createMidiNoteImage(midiNote: bm)
        let lbox = SCNBox(width: boxlwh, height: boxlwh, length: boxlwh, chamferRadius: 0)
        lbox.firstMaterial?.diffuse.contents  =  ltex
        lbox.firstMaterial?.emission.contents =  ltex
        let lnode = SCNNode(geometry: lbox)
        lnode.position = SCNVector3(-nxoff,0,0)
        parent.addChildNode(lnode)

        //Box on RH side with tMidi label
        let rtex = createMidiNoteImage(midiNote: tm)
        let rbox = SCNBox(width: boxlwh, height: boxlwh, length: boxlwh, chamferRadius: 0)
        rbox.firstMaterial?.diffuse.contents  =  rtex
        rbox.firstMaterial?.emission.contents =  rtex
        let rnode = SCNNode(geometry: rbox)
        rnode.position = SCNVector3(nxoff,0,0)
        parent.addChildNode(rnode)
        return parent
    } //end createColorBoxWithLabels


    //-----------(PianoKeys)=============================================
    private func createFlatKB(octaves : Int) -> SCNNode
    {
        let parent = SCNNode()
        // Create long flat tape-like shape. width varies on #octaves
        let xbox = SCNBox(width: octWid * CGFloat(octaves), height: octWid*0.7, length: 0.03, chamferRadius: 0)
        xbox.firstMaterial?.diffuse.contents  =  UIImage(named: "oneOctave")
        xbox.firstMaterial?.emission.contents =  UIImage(named: "oneOctave")
        // Scale texture to suit # octaves
        let scale = SCNMatrix4MakeScale(Float(octaves), 1, 1)
        xbox.firstMaterial?.diffuse.contentsTransform  = scale
        xbox.firstMaterial?.emission.contentsTransform = scale
        xbox.firstMaterial?.diffuse.wrapS  = .repeat
        xbox.firstMaterial?.emission.wrapS = .repeat
        let kbNode = SCNNode(geometry: xbox)
        kbNode.name        = "pianoKeys" //for touch recognition
        parent.addChildNode(kbNode)
        parent.position = SCNVector3(0,octWid * 0.4,0)
        return parent
    } //end createFlatKB
    
} //end PianoKeys
