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

import Foundation
import UIKit

class oogieBmp: NSObject {
    var image = UIImage()
    var wid = 0
    var hit = 0
    var xscale = 1.0
    var yscale = 1.0
    var xoff   = 0.0
    var yoff   = 0.0
    
    //-----------(oogieBmp)=============================================
    override init() {
        super.init()
    }
    
    //-----------(oogieBmp)=============================================
    func setupImage ( i: UIImage )
    {
        image = i //10/21
        wid = Int(i.size.width)
        hit = Int(i.size.height)
    }
    
    //-----------(oogieBmp)=============================================
    func setScaleAndOffsets(sx : Double, sy : Double , ox : Double, oy : Double)
    {
        xscale = sx
        yscale = sy
        xoff   = ox
        yoff   = oy
    }
    
    //-----------(oogieBmp)=============================================
    func getPixelColor(pos: CGPoint) -> UIColor {
        let pixelsWide = Int(image.size.width)
        let pixelsHigh = Int(image.size.height)
        guard let pixelData = image.cgImage?.dataProvider?.data else { return UIColor(red: 0, green: 0, blue: 0, alpha: 0)}
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        //11/2 apply texture XY offset before or after scaling?
        //print("posxy \(pos.x),\(pos.y)")
        //11/3 texture xyoffset must be in bmp w/h coordinate space!
        var xcoord : Double = Double(pos.x)
        var ycoord : Double = Double(pos.y)
        xcoord *= xscale
        ycoord *= yscale
        xcoord += Double(pixelsWide)*xoff
        ycoord += Double(pixelsHigh)*yoff
        let pixelInfo: Int = ((pixelsWide * (Int(ycoord)%hit)) + (Int(xcoord)%wid)) * 4
        if (pixelInfo < 0)  //9/15 saw krash here
        {
            print("Error in getPixelColor: negative index!")
            return UIColor.black
        }
        let color = UIColor(red: CGFloat(data[pixelInfo]) / 255.0,
                            green: CGFloat(data[pixelInfo + 1]) / 255.0,
                            blue: CGFloat(data[pixelInfo + 2]) / 255.0,
                            alpha: CGFloat(data[pixelInfo + 3]) / 255.0)
        //print("   gpc xy \(pos.x),\(pos.y) -> RGB \(color)")
        return color
    }

}
