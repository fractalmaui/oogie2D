//                    _      ____
//   ___   ___   __ _(_) ___| __ ) _ __ ___  _ __
//  / _ \ / _ \ / _` | |/ _ \  _ \| '_ ` _ \| '_ \
// | (_) | (_) | (_| | |  __/ |_) | | | | | | |_) |
//  \___/ \___/ \__, |_|\___|____/|_| |_| |_| .__/
//              |___/                       |_|
//
//  oogieBmp.swift
//  oogie2D
//
//  Created by Dave Scruton on 7/19/19.
//  10/21 modified setupImage
//  10/23 add scale/offsets
//  5/2   integrate pixelData.h/m, stores bitmap data ONCE and accesses an array
//  5/14  add cleanup for bmp data
// https://stackoverflow.com/questions/32297704/convert-uiimage-to-nsdata-and-convert-back-to-uiimage-in-swift

import Foundation
import UIKit

class oogieBmp: NSObject {
    var image = UIImage()
    var wid : Int32 = 0
    var hit : Int32 = 0
    var xscale = 1.0
    var yscale = 1.0
    var xoff   = 0.0
    var yoff   = 0.0
    var duh = 0
    var pd = pixelData()
    
    //-----------(oogieBmp)=============================================
    override init() {
        super.init()
        if let image = UIImage.init(named: "tp")
        {
            setupImage(i: image)
        }
    }
    
    //-----------(oogieBmp)=============================================
    //  5/14 new
    func cleanup()
    {
        pd.freeImageBitmap()
    }
    
    //-----------(oogieBmp)=============================================
    // incoming image gets its bitmap extracted to memory inside pd
    func setupImage ( i: UIImage )
    {
        image = i //10/21
        wid   = Int32(i.size.width)
        hit   = Int32(i.size.height)
        pd.setupImageBitmap(image)
    } //end setupImage
    
    //-----------(oogieBmp)=============================================
    func setScaleAndOffsets(sx : Double, sy : Double , ox : Double, oy : Double)
    {
        xscale = sx
        yscale = sy
        xoff   = ox
        yoff   = oy
    } //end setScaleAndOffsets
    
    //-----------(oogieBmp)=============================================
    // assumes pixelData struct (Objective C) loaded with data ...
    func getPixelColor(pos: CGPoint) -> UIColor {
        let pixelsWide = Int(image.size.width)
        let pixelsHigh = Int(image.size.height)
        let xcoord : Double = (Double(pos.x) * xscale) + Double(pixelsWide)*xoff
        let ycoord : Double = (Double(pos.y) * yscale) + Double(pixelsHigh)*yoff
        let xcint  : Int32 = Int32(xcoord) % hit
        let ycint  : Int32 = Int32(ycoord) % wid
        let color  = pd.getRGBAtPoint(xcint,ycint)
        //          print("XY \(xcoord),\(ycoord) c \(color) vs c2 \(c2)")
        if let finalColor = color {return finalColor}
        return UIColor.black
    } //end getPixelColor
    
    
    
    //-----------(oogieBmp)=============================================
    func getPixelColorOLD(pos: CGPoint) -> UIColor {
        let pixelsWide = Int(image.size.width)
        let pixelsHigh = Int(image.size.height)
        let xcoord : Double = (Double(pos.x) * xscale) + Double(pixelsWide)*xoff
        let ycoord : Double = (Double(pos.y) * yscale) + Double(pixelsHigh)*yoff
        guard let pixelData = image.cgImage?.dataProvider?.data else { return UIColor(red: 0, green: 0, blue: 0, alpha: 0)}
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let pixelInfo: Int  = ((pixelsWide * (Int(ycoord)%Int(hit))) + (Int(xcoord)%Int(wid))) * 4
        if (pixelInfo < 0)  //9/15 saw krash here
        {
           // print("Error in getPixelColor: negative index!")
            return UIColor.black
        }
        let color = UIColor(red:   CGFloat(data[pixelInfo])     / 255.0,
                            green: CGFloat(data[pixelInfo + 1]) / 255.0,
                            blue:  CGFloat(data[pixelInfo + 2]) / 255.0,
                            alpha: CGFloat(data[pixelInfo + 3]) / 255.0)
        
        let c2 = pd.getRGBAtPoint(Int32(Int(xcoord)),Int32(ycoord))
        print("XY \(xcoord),\(ycoord) c \(color) vs c2 \(c2)")
      
        return color
    } //end getPixelColor

}
