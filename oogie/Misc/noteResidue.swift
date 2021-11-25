//
//  noteResidue.swift
//  noteResidue
//
//  Created by Dave Scruton on 10/26/21.
//

import Foundation
import UIKit


struct particule
{
    var x : Int = 0    //xy pos
    var y : Int = 0
    var xs : Int = 16   //xy size
    var ys : Int = 16
    var xv  : Int = 1   //xy vel
    var yv  : Int = 0
    var age : Int = 0
    var color : UIColor = .white
    var icon  = UIImage()
    //= UIImage.init(named: "fineGear")
}

class noteResidue {
    //This is supposed to be a singleton...
    //static let sharedInstance = noteResidue()
    var particules = [particule]()  //our array of particules
    var garbage    = [Int]() //stuff to clobber

    var output = UIImage()

    var animTimer = Timer()

    let MAX_AGE = 100
    let MIDI_MIN = 20
    let MIDI_MAX = 128
    
    let RES_XDIM = 512
    let RES_YDIM = 512
    
    let ICONXY = 10
    
    //=====(noteResidue)=============================================
    //This sets up particules
    init()
    {
        clear()
        startAnim()
    }
    
    //=====(noteResidue)=============================================
    func clear()
    {
        particules.removeAll()
        garbage.removeAll()
    }
    
    //=====(noteResidue)=============================================
    func startAnim()
    {
        let animTimerPeriod = 0.1

        animTimer = Timer.scheduledTimer(timeInterval: animTimerPeriod, target: self, selector: #selector(self.updateAnim), userInfo:  nil, repeats: true)
 
    }
    
    //=====(noteResidue)=============================================
    //  advance all particules, delete old ones...
    @objc func updateAnim()
    {
        garbage.removeAll()  //clear delete list
        for i in 0..<particules.count
        {
            var p = particules[i]
            p.x = p.x + p.xv  //advance motion...
            p.y = p.y + p.yv
            //print("p[\(i)] x \(p.x)")
            p.age = p.age + 1
            if p.age > MAX_AGE  //too old? kill it!
            {
                garbage.append(i) //mark for deletion...
            }
            else{
                particules[i] = p
            }
        } //end for i
        while garbage.count > 0 //delete any old items
        {
            if let i = garbage.popLast()
            {
                //print("remove particule \(i)")
                particules.remove(at: i)
            }
        }
        output = createResidueImage()
    } //end updateAnim
    
    //=====(noteResidue)=============================================
    // for now pan is 0/1 for L/R
    func addNote(midiNote:Int , color : UIColor , pan : Int , type : String)
    {
        var newp = particule()
  //      let margin = ICONXY / 2
        // get our midi note place, complex!
        let halfResYdim = RES_YDIM / 2
        //first fit midi inFloat(to half the) width of our bitmap...
        // later it gets flipped around or L/R display
        let midipos =  Int(  Float(halfResYdim) * (Float(midiNote - MIDI_MIN) / Float(MIDI_MAX-MIDI_MIN))  )
        
        if pan == 0
        {
            newp.x  = RES_YDIM - midipos //try for LH Side? low is at bottom
        }
        else
        {
            newp.x  =  midipos
        }
        // ok 0 ... midipos/2  is RH side,  bottom part of toob is low end of midi range!
        //try ?left
//        newp.x  = midipos / 4 //bottom RH
//        newp.x  = midipos / 2 + RES_YDIM / 2  //try for LH side
        
        newp.y  = RES_YDIM / 2
        newp.xs = ICONXY    //xy icon size
        newp.ys = ICONXY
        newp.xv = 0    //xy vel
        newp.yv = -15
        newp.age = 0
        newp.color = color
        newp.icon  = UIImage.init(named: "fineGear")!
        //print("add \(midiNote)")
        particules.append(newp)
    } //end addNote
    
    
    //=====(noteResidue)=============================================
    func createResidueImage( ) -> UIImage {
        let frame = CGRect.init(x: 0, y: 0, width: RES_XDIM, height: RES_YDIM)
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        guard let context = UIGraphicsGetCurrentContext() else {return UIImage()} //DHS 1/31
        context.setFillColor(UIColor.black.cgColor);
        context.fill(frame);
        
        //add GRID xy lines...
        var xi = CGFloat(0.0)
        var yi = CGFloat(0.0)
        var xs = CGFloat(0.0)
        var ys = CGFloat(0.0)

        context.setFillColor(UIColor.blue.cgColor);
        xi = 0.0
        yi = 0.0
        xs = 1.0
        ys = CGFloat(frame.size.height)
        let xg = 8
        for _ in 0...xg
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            xi  = xi + frame.size.width/CGFloat(xg)
        }
        context.setFillColor(UIColor.white.cgColor);
        xi = 0.0
        yi = 0.0
        xs = CGFloat(frame.size.width)
        ys = CGFloat(1.0)
        let yg = 8
        for _ in 0...yg-1
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            yi  = yi + frame.size.height/CGFloat(yg)
        }
        let ii = UIImage.init(named: "fineGear")
        
        for i in 0..<particules.count
        {
            let p = particules[i]
            let c = p.color
            let f = CGFloat(p.age) / CGFloat(MAX_AGE)
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            var a: CGFloat = 0.0
            c.getRed(&r, green: &g , blue: &b, alpha: &a)
            a = 1.0 - f //apply age to alpha in reverse
            let c2 = UIColor(red: r, green: g, blue: b, alpha: a)
            
            let ci = ii?.maskWithColor(color: c2)
            ci?.draw(in: CGRect.init(x: p.x, y: p.y, width: p.xs, height: p.ys))
        } //end for i
       //Pack up and return image!
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createResidueImage
}


extension UIImage{
    func maskWithColor(color:UIColor) -> UIImage?
    {
        let maskImage = cgImage!
        let width  = size.width
        let height = size.height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        if let context = CGContext(data:nil,width:Int(width),height:Int(height),bitsPerComponent: 8,bytesPerRow: 0,space:colorSpace,bitmapInfo: bitmapInfo.rawValue)
        {
            context.clip(to:bounds,mask:maskImage)
            context.setFillColor(color.cgColor)
            context.fill(bounds)
            if let cgImage = context.makeImage()
            {
                let coloredImage = UIImage(cgImage: cgImage)
                return coloredImage
            }
            else{
                return nil
            }
        }
        return nil
    }
    
    
    
}


