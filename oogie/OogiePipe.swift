//
//  OogiePipe.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//

import Foundation

struct OogiePipe {
    //User Params come from here...
    var PS     : PipeStruct
    //Working variables...
    let pbSize = 256
    var ibuffer : [Float] //input buffer
    var obuffer : [Float] //output buffer
    var bptr   = 0
    var multF  = 1.0
    
    //======(OogiePipe)=============================================
    // Gotta have all 4 args b4 init!
    init( fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
        ibuffer      = [] //set up our input/output data buffers
        obuffer      = []
        PS           = PipeStruct(fromObject: fromObject , fromChannel: fromChannel ,
                                    toObject: toObject   ,     toParam: toParam) //11/22 setup dat pipe!
    }
    
    //======(OogiePipe)=============================================
    // add channel data to buffer, wrap around at pbSize
    mutating func addToBuffer (f : Float)
    {
        let cf = convertData(f : f)
        if ibuffer.count < pbSize
        {
            ibuffer.append(f)
            obuffer.append(cf)
        }
        else{
            ibuffer[bptr] = f
            obuffer[bptr] = cf
        }
        bptr = bptr + 1
        if bptr >= pbSize {bptr = 0}
    } //end addToBuffer
    
    //======(OogiePipe)=============================================
    // should this accept integer input?
    func convertData (f : Float) -> Float
    {
        return Float(PS.loRange) + (f * Float(multF))
    }
    
    //======(OogiePipe)=============================================
    func getOlderPtr(offset:Int) -> Int
    {
        var p = bptr - offset
        while p < 0 {p = p + ibuffer.count} //make sure we are legal
        return p
    } //end getOlderPtr
    
    //======(OogiePipe)=============================================
    // get value just written to INPUT buffer
    func getFromIBuffer() -> Float{
        if ibuffer.count == 0 {return 0.0}
        return ibuffer[getOlderPtr(offset: 1)]
    }
    
    //======(OogiePipe)=============================================
    // get older value from INPUT buffer
    func getFromIBufferWithOffset(o : Int) -> Float{
        if ibuffer.count == 0 {return 0.0}
        return ibuffer[getOlderPtr(offset: o)]
    }

    //======(OogiePipe)=============================================
    // get value just written to OUTPUT buffer
    func getFromOBuffer() -> Float{
        if obuffer.count == 0 {return 0.0}
        return obuffer[getOlderPtr(offset: 1)]
    }
    
    //======(OogiePipe)=============================================
    // get older value from OUTPUT buffer
    func getFromOBufferWithOffset(o : Int) -> Float{
        if obuffer.count == 0 {return 0.0}
        return obuffer[getOlderPtr(offset: o)]
    }

    //======(OogiePipe)=============================================
    // breaks out fromObject substrings, returns as tuple
    func getFO() ->  (otype:String , oname:String )
    {
        let ss = PS.fromObject.split(separator: ":")
        if ss.count < 2 {return ("","")}
        return(String(ss[0]),String(ss[1]))
    } //end getFO
    
    //======(OogiePipe)=============================================
    // breaks out toObject substrings, returns as tuple
    func getTO() ->  (otype:String , oname:String )
    {
        let ss = PS.toObject.split(separator: ":")
        if ss.count < 2 {return ("","")}
        return(String(ss[0]),String(ss[1]))
    } //end getTO
    
    //======(OogiePipe)=============================================
    mutating func setupRange(lo:Double , hi:Double)
    {
        //illegal input? Just bail for now
        if (lo > hi) || (hi-lo < 2) { return }
        PS.loRange = lo
        PS.hiRange = hi
        multF = (hi-lo) / 256.0 // fit color channel into range
    } //end setupRange
    
} //end OogiePipe struct

