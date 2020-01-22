//
//  OogiePipe.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
//  12/1 add verbose, why doesnt it work?

import Foundation

//12/1 add params
let InputChanParams      : [Any]   = ["InputChannel", "string", "Red", "Green", "Blue", "Hue",
                                  "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow"]
let OutputParamParams    : [Any] = ["OutputParam", "string","mt"]
//Not confusing at all, huh? This is the param where the pipename is entered
let PipeNameParams       : [Any] = ["Name",      "text", "mt"]
let PipeLoRangeParams    : [Any] = ["LoRange",      "text", "mt"]
let PipeHiRangeParams    : [Any] = ["HiRange",      "text", "mt"]   //..12.9 wups
// This is an array of all parameter names...
let pipeParamNames : [String] = ["InputChannel", "OutputParam","Name","LoRange","HiRange"]

var pipeParamsDictionary = Dictionary<String, [Any]>()

struct OogiePipe {
    //User Params come from here...
    var name    : String
    var PS      : PipeStruct
    //Working variables...
    let pbSize  = 256
    var ibuffer : [Float] //input buffer
    var obuffer : [Float] //output buffer
    var bptr    = 0
    var multF   = 1.0
    var destination = ""
    var gotData = false //11/25
    var uid     = "nouid"
    var vvvvb   = false

    //======(OogiePipe)=============================================
    // Gotta have all 4 args b4 init!
    init() // fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
        name         = "pipe0000"
        ibuffer      = [] //set up our input/output data buffers
        obuffer      = []
        PS           = PipeStruct()
        uid          = "pipe_" + ProcessInfo.processInfo.globallyUniqueString //1/21 wups no uid!
        setupParams()
    }
    
    
    //-----------(OogiePipe)=============================================
    func setupParams()
    {
        // Load up params dictionary with string / array combos
        pipeParamsDictionary["00"] = InputChanParams
        pipeParamsDictionary["01"] = OutputParamParams
        pipeParamsDictionary["02"] = PipeNameParams
        pipeParamsDictionary["03"] = PipeLoRangeParams
        pipeParamsDictionary["04"] = PipeHiRangeParams
    } //end setupParams
    
    //-----------(OogiePipe)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= pipeParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return pipeParamsDictionary[key]!
    }
    
    //-----------(OogiePipe)=============================================
    func getParamCount() -> Int
    {
        return pipeParamNames.count
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
        gotData = true //11/25
        if vvvvb
        {
            print("pipe \(name): \(PS.fromChannel) = \(f)")
        }
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
    mutating func getFromOBuffer(clearFlags: Bool) -> Float{
        if clearFlags {gotData = false} //11/25
        if obuffer.count == 0 {return 0.0}
        return obuffer[getOlderPtr(offset: 1)]
    }
    
    //======(OogiePipe)=============================================
    // get older value from OUTPUT buffer
    mutating func getFromOBufferWithOffset(o : Int , clearFlags : Bool) -> Float{
        if clearFlags {gotData = false} //11/25
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
        if (lo > hi) || (hi-lo < 0.05) { return } //1/14 Wups need tighter check
        PS.loRange = lo
        PS.hiRange = hi
        multF = (hi-lo) / 256.0 // fit color channel into range
        //print("PIPE: setuprange lo/hi \(lo) /(hi) -> multf \(multF)")
    } //end setupRange
    
    //======(OogiePipe)=============================================
    // 12/1
    mutating func toggleVerbose()
    {
        vvvvb = true
    }
    
} //end OogiePipe struct

