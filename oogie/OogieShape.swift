//    ___              _      ____  _
//   / _ \  ___   __ _(_) ___/ ___|| |__   __ _ _ __   ___
//  | | | |/ _ \ / _` | |/ _ \___ \| '_ \ / _` | '_ \ / _ \
//  | |_| | (_) | (_| | |  __/___) | | | | (_| | |_) |  __/
//   \___/ \___/ \__, |_|\___|____/|_| |_|\__,_| .__/ \___|
//               |___/                         |_|
//
//  OogieShape.swift
//  oogie2D
//
//  Created by Dave Scruton on 1/21/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//
//  4/22 add getParam func
//  4/23 add setParam
//  4/25 moved params in from OSStruct (was wrong!),add paramList
//  4/27 add dumpParams
//  5/6  move spinTimer and shape spin in from SphereShape
//  5/11 add createMTImage, need in common area w/ sphereShape though
//  5/14 add cleanup for bmp data
//  9/19 add oogieShapeParams
import Foundation


class OogieShape: NSObject {

    var OOS  = OSStruct()  // codable struct for i/o
    var OSP =  OogieShapeParams.sharedInstance //9/19/21 oogie voice params
    var inPipes = Set<String>()   //use insert and remove to manage...
    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()
    //5/3 move bmp from SphereShape
    var bmp = oogieBmp() //10/21 bmp used for color gathering
    let tc  = texCache.sharedInstance //10/21 for loading textures...

    //5/6 move shape rotation in from SphereShape
    var angle  : Double = 0.0 //Rotation angle
    var rotTime : Double = 1.0
    var spinTimer = Timer()
    var refAngle : Double = 0.0
    var refDate  = Date()
    var oldTInterval : Double = 0.0
    
    #if USE_TESTPATTERN
    let defaultTexture = "spectrumOLD" //"tp"  8/12 testd
    #else
    let defaultTexture = "oog2-stripey00t"
    #endif

    //-----------(oogieShape)=============================================
    override init() {
        super.init()
    }
    
    //-----------(oogieShape)=============================================
    //5/14 new
    func cleanup()
    {
        bmp.cleanup()
    }
  
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= OSP.shapeParamsDictionary.count {return []} //9/19/21
        let key =  String(format: "%02d", n)
        return OSP.shapeParamsDictionary[key]!
    }
    
    //======(OSStruct)=============================================
    func getParamCount() -> Int
    {
        return OSP.shapeParamNames.count   //9/19/21
    }

    
    //-----------(oogieShape)=============================================
    // 4/22/20 gets param named "whatever", returns tuple
    // 4/25    add isString	
    func getParam(named name : String) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = "empty"
        var isString = false
        switch (name)   //depending on param, set double or string
        {
        case "texture" :     sp = OOS.texture
                             isString = true
        case "rotation":     dp = OOS.rotSpeed
        case "rotationtype": dp = OOS.rotation
        case "xpos":         dp = OOS.xPos
        case "ypos":         dp = OOS.yPos
        case "zpos":         dp = OOS.zPos
        case "texxoffset":   dp = OOS.uCoord
        case "texyoffset":   dp = OOS.vCoord
        case "texxscale":    dp = OOS.uScale
        case "texyscale":    dp = OOS.vScale
        case "name":         sp = OOS.name
                             isString = true
        case "comment":      sp = OOS.comment
                             isString = true
        default:print("Error:Bad shape param in get")
        }
        if !isString  {sp = String(format: "%4.2f", dp)} //4/25 pack double as string
        return(name , dp , sp)  //pack up name,double,string
    } //end getParam

    //-----------(oogieShape)=============================================
    func dumpParams() -> String
    {
        var s = String(format: "[key:%@]\n",OOS.key)
        for pname in OSP.shapeParamNames  //9/19/21
        {
            let pTuple = getParam(named : pname.lowercased())
            s = s + String(format: "%@:%@\n",pname,pTuple.sParam)
        }
        s = s + String(format: "UID:%@\n",OOS.uid)
        return s
    }
    
    //-----------(oogieShape)=============================================
    func getParamList() -> [String]
    {
        if !paramListDirty {return paramList} //get old list if no new params
        paramList.removeAll()
        for pname in OSP.shapeParamNames  //9/19/21
        {
            let pTuple = getParam(named : pname.lowercased())
            paramList.append(pTuple.sParam)
        }
        paramListDirty = false
        return paramList
    } //end getParamList
    
    
    //-----------(oogieShape)=============================================
    // 9/18/21 new, returns dict with packed param arrays... asdf
    func getParamDict() -> Dictionary<String,Any>
    {
        var d = Dictionary<String, Any>()
        for pname in OSP.shapeParamNames //look at all params...9.19.21
        {
            print("pack shape param \(pname)")
            let plow = pname.lowercased()
            let pTuple = getParam(named : plow)
            let sv = pTuple.sParam
            var dv = pTuple.dParam as Double
            if let paramz = OSP.shapeParamsDictionary[plow]  //get param info...
            {
                var workArray = paramz  //copy
                if let ptype = paramz[1] as? String
                {
                    if ptype == "double"  //double type? do some conversion
                    {
                        let lolim  = paramz[6] as! Double
                        let lrange = paramz[5] as! Double
                        if lrange != 0.0 //9/16 DO not apply range shift to int params!
                        {
                            dv = (dv - lolim) / lrange
                        }
                        workArray.append(NSNumber(value:dv))
                    } //end double/int type
                    else if ptype == "int"     //9/16 int type? no conversion
                    {
                        workArray.append(NSNumber(value:dv))
                    }
                    else //string?
                    {
                        workArray.append(sv)
                    }
                }  //end let ptype
                d[plow] = workArray
            } //end let paramz
        } //end for pname
        return d
    } //end getParamList
    
 
    
    //-----------(oogieShape)=============================================
    func computeCurrentAngle() -> Double
    {
        let cDate = Date()
        //5/6 how long we be spinnin?
        let timeInterval : Double = cDate.timeIntervalSince(refDate)
        oldTInterval = timeInterval
        return refAngle + (2.0 * Double.pi)*(timeInterval/rotTime)
    } //end computeCurrentAngle
    
    //-----------(oogieShape)=============================================
    // 5/6 redo to use actual time between two Dates, the timer is assumed WRONG
    @objc func advanceRotation()
    {
        angle = computeCurrentAngle()
    } //end advanceRotation
    
    //-----------(oogieShape)=============================================
    func haltSpinTimer()
    {
        spinTimer.invalidate()
    }
    
    
    //-----------(oogieShape)=============================================
    func setRotationTypeAndSpeed()
    {
        var rspeed = 8.0
        var irot = Int(OOS.rotation)
        if irot > 0
        {
            if irot > 8 {irot = 8}
            rspeed = 60.0 / Double(OVtempo) //time for one beat
            //11/23 change rotation speed mapping
            rspeed = rspeed * 1.0 * Double(irot) //4/4 timing, apply rot type
        }
        OOS.rotSpeed = rspeed //ok set new speed now
        setTimerSpeed(rs:rspeed)
    } //end setRotationTypeForSelectedShape
    
    //-----------(oogieShape)=============================================
     func setTimerSpeed(rs : Double)
     {
         rotTime  = rs
         refAngle = angle    //5/6 reset reference angle and date
         refDate  = Date()
     }

    //-----------(oogieShape)=============================================
    func setupSpinTimer(rs : Double)
    {
        spinTimer.invalidate()
        setTimerSpeed(rs:rs)
        let tstep = 0.002   //5/6 try finer rotation step
        spinTimer = Timer.scheduledTimer(timeInterval: tstep, target: self, selector: #selector(self.advanceRotation), userInfo:  nil, repeats: true)
    }
    
    
    //-----------(oogieShape)=============================================
    // 9/2 add default support
    func setBitmap (s : String)
    {
        let tekture = UIImage(named: defaultTexture)
        if s != "default" //non-default? try from cache!
        {
            if let ctek = tc.texDict[s]
            {
                bmp.setupImage(i:ctek)
                return
            }
            else {
                bmp.setupImage(i:createMTImage(name:s))
                //print("error fetching texture \(s)")
                return
            }
        }
        bmp.setupImage(i:tekture!)
    } //end setBitmap

    //=====<oogie2D mainVC>====================================================
    // just puts name in black bigd
    public func createMTImage(name : String) -> UIImage {
        let ww = 512
        let hh = 256
        let isize = CGSize(width: ww, height: hh) //overall image size
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        let rect = CGRect(origin: CGPoint.zero, size: isize)
        context.setFillColor(UIColor.black.cgColor);
        context.fill(rect);
        
        let label = name
        let thite = hh/6
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(thite))!
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
        
        var textColor = UIColor.white
        let xmargin : CGFloat = 300 //WTF why doesnt this stretch label?
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: text_style
            ] as [NSAttributedString.Key : Any]
        let trect =  CGRect(x: -xmargin, y:  CGFloat(hh/2) - CGFloat(thite)/2.0, width: CGFloat(ww) + 2*xmargin, height: CGFloat(thite))
        label.draw(in: trect, withAttributes: textFontAttributes)
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createMTImage



    //-----------(oogieShape)=============================================
    // 4/23 sets param by name to either double or string depending on type
    //  NOTE: some fields need to be pre-processed before storing, that
    //   is the responsibility of the caller!
    func setParam(named name : String , toDouble dval: Double , toString sval: String)
    {
        switch (name)
        {
        case "texture"     : break  //4/27 no action here
        case "rotation"    : OOS.rotSpeed = dval
            setTimerSpeed(rs : OOS.rotSpeed)  //5/7 update spin timer
        case "rotationtype": OOS.rotation = floor(dval + 0.5) //4/27 fractions make no sense
              setRotationTypeAndSpeed() //5/7 set internal rot speed
        case "xpos"        : OOS.xPos     = dval
        case "ypos"        : OOS.yPos     = dval
        case "zpos"        : OOS.zPos     = dval
        case "texxoffset"  : OOS.uCoord   = dval
        case "texyoffset"  : OOS.vCoord   = dval
        case "texxscale"   : OOS.uScale   = dval
            print("set texxscale \(dval)")
        case "texyscale"   : OOS.vScale   = dval
            print("set texyscale \(dval)")
        case "name"        : OOS.name     = sval
        case "comment"     : OOS.comment  = sval
        default:print("Error:Bad shape param in set")
        }
        paramListDirty = true
    } //end setParam
    
}
