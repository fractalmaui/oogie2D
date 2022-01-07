//
//   _        __     _____         _
//  (_)_ __  / _| __|_   _|____  _| |_
//  | | '_ \| |_ / _ \| |/ _ \ \/ / __|
//  | | | | |  _| (_) | |  __/>  <| |_
//  |_|_| |_|_|  \___/|_|\___/_/\_\\__|
//
//  infoText.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
//  10/5 add showWarnings flag
//  10/21 fix typo in types
//  2/3   add multiple lines / variable font size for comments
//  9/11  fix possible krash in updateit
// CLUGE???????
//  9/19  For now, lets assume integer fields are choosers ALWAYS and require a string output...
//  11/29 add special case for midi fields, truncate nueric output
//          pull min/max err checks too
import UIKit
import Foundation
let TINT_TTYPE    = 1 //10/21 wups
let TFLOAT_TTYPE  = 2
let TSTRING_TTYPE = 3
class infoText: UIView {
    
    var infoView = UIView()
    
    var minVal      = -90.0
    var maxVal      = 90.0
    var paramName   = ""
    var fadeInTime      = 0.5
    var fadeOutTime     = 3.0
    var fadeOutWaitTime = 4.0
    var HIFrame    = CGRect()
    var titleLabel = UILabel()
    var TLlabel    = UILabel()
    var TRlabel    = UILabel()
    var TLWarning  = UILabel()
    var TRWarning  = UILabel()
    var barFGColor : UIColor = .red
    var barBGColor : UIColor = .blue
    var HIImageView = UIImageView()
    var numTics = 6
    var items : [String] = []
    var fadingIn = false
    var fadingOut = false
    var showWarnings = false

    let TLArrow = "<--"
    let TRArrow = "-->"

    var framHit:Int = 70
    var framWid:Int = 414
    var fieldType = TSTRING_TTYPE
    var fadeTimer = Timer() //11/4

    let bigfonthit = 28   //1/3/22 shrink again for more content

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        createAllSubviews()
    }
    //------<infoText>-----------------------------------------
    // This initializer hides init(frame:) from subclasses
//    init() {
//        super.init(frame: CGRect.zero)
//        createAllSubviews()
//    }
    
    //------<infoText>-----------------------------------------
    // This attribute hides `init(coder:)` from subclasses
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    //------<infoText>-----------------------------------------
    func createAllSubviews()
    {
        self.backgroundColor = .clear
        infoView = UIView()
        
        framHit = Int(frame.size.height)
        framWid = Int(frame.size.width)
        let tinyinset = 10
        HIFrame = CGRect(x: tinyinset, y: 20, width: framWid-2*tinyinset, height: 15)
        HIImageView = UIImageView()
        HIImageView.frame = HIFrame
        HIImageView.backgroundColor = .red
        infoView.addSubview(HIImageView)

        //Create bottom view around everything...
        infoView.frame = CGRect(origin: CGPoint(x: 0,y: 0), size: self.frame.size)
        //Custom dark blue bkgd for our control
        infoView.backgroundColor = UIColor(red: 0.2, green: 0.0, blue: 0.4, alpha: 0.6)
        self.addSubview(infoView)
        
        // UILabel: Multiple-function info label at top of screen...
        //   shows label, X-axis param range indicator, prev/next choices ...
        // 2/5 make label a bit taller...
        let fontmargin = 12
        titleLabel = UILabel()
        //  1/3 scale to initial frame
        titleLabel.frame = CGRect(x: 0, y: 0,
                                  width: framWid, height: framHit)
//        titleLabel.frame = CGRect(x: 0, y: framHit - bigfonthit - fontmargin,
//                                  width: framWid, height: bigfonthit+2*fontmargin)
        titleLabel.text = "Item"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left  // 1/3 amatueurish?  center
        titleLabel.font = titleLabel.font.withSize(CGFloat(bigfonthit))
        titleLabel.backgroundColor = .clear
        infoView.addSubview(titleLabel)
        
        //Add small low/hi limit labels above...
        let tinyfonthit = 20
        let sidewid = 150
        TLlabel = UILabel()
        TLlabel.frame = CGRect(x: tinyinset, y: 0, width: sidewid, height: tinyfonthit)
        TLlabel.text = "Prev Item"
        TLlabel.textColor = .white
        TLlabel.textAlignment = .left
        TLlabel.font = TLlabel.font.withSize(CGFloat(tinyfonthit))
        TLlabel.backgroundColor = .clear
        infoView.addSubview(TLlabel)
        
        TRlabel = UILabel()
        TRlabel.frame = CGRect(x: framWid - sidewid - tinyinset, y: 0, width: sidewid, height: tinyfonthit)
        TRlabel.text = "Next Item"
        TRlabel.textColor = .white
        TRlabel.textAlignment = .right
        TRlabel.font = TRlabel.font.withSize(CGFloat(tinyfonthit))
        TRlabel.backgroundColor = .clear
        infoView.addSubview(TRlabel)
        
        TLWarning = UILabel()
        TLWarning.frame = CGRect(x: tinyinset, y: 20, width: 30, height: 30)
        TLWarning.text = "!"
        TLWarning.textColor = .white
        TLWarning.textAlignment = .center
        TLWarning.font = TLWarning.font.withSize(CGFloat(30))
        TLWarning.backgroundColor = UIColor(red: 0.9, green: 0.7, blue: 0, alpha: 0.8)
        infoView.addSubview(TLWarning)
        TLWarning.isHidden = true
        
        TRWarning = UILabel()
        TRWarning.frame = CGRect(x: framWid-tinyinset - 30, y: 20, width: 30, height: 30)
        TRWarning.text = "!"
        TRWarning.textColor = .white
        TRWarning.textAlignment = .center
        TRWarning.font = TLWarning.font.withSize(CGFloat(30))
        TRWarning.backgroundColor = UIColor(red: 0.9, green: 0.7, blue: 0, alpha: 0.8)
        infoView.addSubview(TRWarning)
        TRWarning.isHidden = true
        
    }
    
    //=======>ARKit MainVC===================================
    @objc func fadeOutTick()
    {
        fadeOut()
    }

    
    //------<infoText>-----------------------------------------
    func fadeIn()
    {
        //print("top fadein inout flags \(fadingIn) \(fadingOut) alpha \(infoView.alpha)")
        if fadingIn || infoView.alpha == 1 {return} //avoid redundant calls
        self.layer.removeAllAnimations() //Cancel any fadeouts!
        //print("fadein, cancel fadeout")
        fadingIn = true
        UIView.animate(withDuration: fadeInTime, animations: {
            self.infoView.alpha = 1
        }, completion: { finished in
            self.fadingIn = false
            self.fadeTimer.invalidate() //Get rid of any older timer
            //If knob is inactive for 4 seconds fadeout info
            self.fadeTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(self.fadeOutTick), userInfo:  nil, repeats: false)

            //print("fadein DONE : clear fadein flag")
        })
    }
    
    //------<infoText>-----------------------------------------
    func fadeOut()
    {
        if fadingOut || infoView.alpha == 0 {return} //avoid redundant calls
        //print(">>>>>fadeout")
        fadingOut = true
        UIView.animate(withDuration: fadeOutTime, animations: {
            self.infoView.alpha = 0
        }, completion: { finished in
            //print(">>>>>fadeout DONE : clear fadeout flag")
            self.fadingOut = false
        })
    }
    
    //------<infoText>-----------------------------------------
    public func updateHImage(value : Double) -> UIImage {
        let isize = CGSize(width: HIFrame.size.width, height: 15)
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        
        let imageRect = CGRect(x: 0, y: 0, width: HIFrame.size.width, height: HIFrame.size.height)
        //OUCH: 10/4 what about zero max/min range?
        var fraction : Float = 0.0
        if maxVal-minVal != 0 { fraction =  Float(value-minVal) / Float(maxVal-minVal) }
        let fracwid = Int(fraction * Float(imageRect.size.width))
        let fir = CGRect(x: 0, y: 0, width: fracwid, height: Int(HIFrame.size.height))
        
        context.setFillColor(barBGColor.cgColor);
        context.fill(imageRect);
        context.setFillColor(barFGColor.cgColor);
        context.fill(fir);
        
        context.setFillColor(UIColor.black.cgColor)
        let tstep = HIFrame.size.width / CGFloat(numTics)
        if numTics > 1 //10/9 keep it legal!
        {   for i in 0...numTics-1 //add LH -> ticmarks
        {
            let rr = CGRect(x: Int(tstep)*i, y: 0, width: 2, height: 20)
            context.fill(rr);
            }
        }
        let rr = CGRect(x: HIFrame.size.width-2, y: 0, width: 2, height: 20)
        context.fill(rr); //Add RH end ticmark
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end updateHImage
    
    //------<infoText>-----------------------------------------
    // 2/3/20 update for long labels
    func updateLabelOnly(lStr:String)
    {
        fadeIn() //11/4 checked for redundancy, OK here now
        TLWarning.isHidden   = true
        TRWarning.isHidden   = true
        TLlabel.isHidden     = true
        TRlabel.isHidden     = true
        HIImageView.isHidden = true
        
        var bfhg = bigfonthit  //2/3 redo string hite...
        let stc  = lStr.count
        //2/3 this may get a long string. scale font to make things fit!
        if stc > 24  //what should cutoff be? 16 is too little
        {
            bfhg = max(8,1200 / (stc + 12))            //2/3 Fudged:good font size?
            titleLabel.numberOfLines = 0              //2/3 variable # lines
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.textAlignment = .left
            titleLabel.lineBreakMode = .byCharWrapping //for long comment fields
        }
        titleLabel.font = titleLabel.font.withSize(CGFloat(bfhg))
        titleLabel.text = lStr
    } //end updateLabelOnly
    
    //------<infoText>-----------------------------------------
    func updateit(value:Double)
    {
        fadeIn() //11/4 checked for redundancy, OK here now
        var workVal = value
        TLlabel.isHidden     = false
        TRlabel.isHidden     = false
        HIImageView.isHidden = false

        //9/19/21 For now, lets assume integer fields are choosers ALWAYS and require a string output...
        if  fieldType == TSTRING_TTYPE || fieldType == TINT_TTYPE
        {
            //9/11 is there something to display?
            if  items.count > 0
            {
                let intItem : Int = Int(workVal)
                if intItem < 0 {return} //10/19 prevent krash
                if intItem > 0
                {
                    TLlabel.text = TLArrow + items[intItem-1]
                }
                else {TLlabel.text = ""}
                if intItem < items.count-1
                {
                    TRlabel.text = items[intItem+1] + TRArrow
                }
                else {TRlabel.text = ""}
                titleLabel.text = paramName + " = " + items[intItem]
            }
            else //9/20 no items? just put up param name
            {
                titleLabel.text = "change " + paramName
            }
        }
//        else if  fieldType == TINT_TTYPE
//        {
//            TLlabel.text = String(Int(minVal))
//            TRlabel.text = String(Int(maxVal))
//            titleLabel.text = paramName + " = "  + String(Int(workVal))
//        }
        else if  fieldType == TFLOAT_TTYPE
        {
            TLlabel.text = String(minVal)
            TRlabel.text = String(maxVal)
            var t = ""
            //11/29 special cases: midi needs to be shown as a string!
            if paramName == "bottommidi" || paramName == "topmidi"
            {
                t = getMidiNoteString(noteval: Int(workVal))
            }
            else if paramName == "latitude" || paramName == "longitude" //11/29 special lat/lon
            {
                let angleVal = Int(workVal * 180.0 / .pi)
                t = String(angleVal)
            }
            //11/29 most shape params need floating point output
            else if ["xpos","ypos","zpos","texxoffset","texyoffset","texxscale","texyscale"].contains( paramName )
            {
                t = String(format:"%4.2f", workVal)
            }
            else //most controls: just show integer param value
            {
                t =  String(Int(workVal)) //11/29 trunc output
            }
            titleLabel.text = paramName + " = " + t
        }
        if fieldType != TFLOAT_TTYPE
        {
            workVal = Double(Int(workVal))
        }
        HIImageView.image = updateHImage(value :  workVal)
    } //end updateit

    func getMidiNoteString (noteval : Int) -> String
    {
        let na = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let whichnote = noteval % 12
        let whichoct  = noteval / 12
        let nout = na[whichnote] + String(whichoct)
        return nout
    }

    
    
    //------<infoText>-----------------------------------------
    // Set up fields and limits...  what about # ticmarks?
    func setupForParam( pname : String , ptype : Int ,
                        pmin : Double , pmax : Double ,
                        choiceStrings : [String])
    {
        paramName = pname
        fieldType = ptype
        items.removeAll()
        
//        print("setupForParam: pname \(pname) :  ptype \(ptype) :   pmin \(pmin) :  pmax \(pmax) :  choices \(choiceStrings) :")
//        print("     types 1,2,3 = int,float,string")
        
        if  fieldType == TSTRING_TTYPE
        {
            minVal = 0
            maxVal = Double(choiceStrings.count-1)
            for string in choiceStrings { items.append(string) }
            numTics = choiceStrings.count - 1  //autoset tic count for string choices
        }
        else{
            minVal    = pmin
            maxVal    = pmax
            numTics   = 10
        }
    } //end setupForParam
    
    
}
