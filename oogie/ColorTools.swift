//    ____      _           _____           _
//   / ___|___ | | ___  _ _|_   _|__   ___ | |___
//  | |   / _ \| |/ _ \| '__|| |/ _ \ / _ \| / __|
//  | |__| (_) | | (_) | |   | | (_) | (_) | \__ \
//   \____\___/|_|\___/|_|   |_|\___/ \___/|_|___/
//
//  ColorTools.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/6/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//

import Foundation


let HLSMAX =  255   // H,L, and S vary over 0-HLSMAX
let RGBMAX =  255   // R,G, and B vary over 0-RGBMAX

public class ColorTools {

//-------(colorTools)-------------------------------------
static func RGBtoCMYK(R:Int,G:Int,B:Int) -> (Cyan:Int , Magenta:Int , Yellow:Int , Black:Int)
{
    var minCMY,lcc,lmm,lyy : Double
    // BLACK
    var CC = 0
    var MM = 0
    var YY = 0
    var KK = 0
    if R==0 && G==0 && B==0
    {
        KK = 1
        return (CC,MM,YY,KK)
    }
    lcc = 1.0 - (Double(R)/255.0)
    lmm = 1.0 - (Double(G)/255.0)
    lyy = 1.0 - (Double(B)/255.0)
    minCMY = lcc //get smallest of 3
    if minCMY > lmm {minCMY = lmm}
    if minCMY > lyy {minCMY = lyy}
    
    CC = Int(255.0 * (lcc-minCMY) / (1.0 - minCMY))
    MM = Int(255.0 * (lmm-minCMY) / (1.0 - minCMY))
    YY = Int(255.0 * (lyy-minCMY) / (1.0 - minCMY))
    KK = Int(255.0 * minCMY)
    return (CC,MM,YY,KK)
    
} //end  RGBtoCMYK


//-------(colorTools)-------------------------------------
static func RGBtoHLS(R:Int,G:Int,B:Int) -> (Hue:Int , Luminance:Int , Saturation:Int)
{
    /* calculate lightness */
    let cMax = max( max(R,G), B);
    let cMin = min( min(R,G), B);
    var Rdelta = 0
    var Gdelta = 0
    var Bdelta = 0
    var HHH : Int = 0
    var LLL : Int = 0
    var SSS : Int = 0
    LLL = ( ((cMax+cMin)*HLSMAX) + RGBMAX )/(2*RGBMAX)
    
    if (cMax == cMin) {            /* r=g=b --> achromatic case */
        SSS = 0                   /* saturation */
        HHH = 0                     /* hue */
        //NSLog(@"bad hue... RGB %d %d %d",R,G,B);
    }
    else {                        /* chromatic case */
        /* saturation */
        if LLL <= (HLSMAX/2)
        {
            SSS = ( ((cMax-cMin)*HLSMAX) + ((cMax+cMin)/2) ) / (cMax+cMin)
        }
        else
        {
            SSS = ( ((cMax-cMin)*HLSMAX) + ((2*RGBMAX-cMax-cMin)/2) )
                / (2*RGBMAX-cMax-cMin)
        }
        /* hue */
        Rdelta = ( ((cMax-R)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
        Gdelta = ( ((cMax-G)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
        Bdelta = ( ((cMax-B)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin)
        
        if (R == cMax)
        {
            HHH = Bdelta - Gdelta;
        }
        else if (G == cMax)
        {
            HHH = (HLSMAX/3) + Rdelta - Bdelta;
        }
        else /* B == cMax */
        {
            HHH = ((2*HLSMAX)/3) + Gdelta - Rdelta;
        }
        //make sure we are in range 0..255??? int modulo
        while (HHH < 0)
        {
            HHH += HLSMAX;
        }
        while (HHH > HLSMAX)
        {
            HHH -= HLSMAX;
        }
        //NSLog(@" hls %d %d %d",HH,LL,SS);
    } //end else
    return (HHH,LLL,SSS)
} //end RGBtoHLS

} //end class

