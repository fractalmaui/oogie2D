//
//  OogiePipe.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
//  12/1 add verbose, why doesnt it work?
//  4/22 add param func
//  4/23 add setParam
//  4/25 add paramList
//  4/27 add dumpParams

import Foundation
import SceneKit

//12/1 add params
let InputChanParams      : [Any]   = ["InputChannel", "string", "Red", "Green", "Blue", "Hue",
                                  "Luminosity", "Saturation", "Cyan", "Magenta", "Yellow"]
let OutputParamParams    : [Any] = ["OutputParam",  "string","mt"]
//Not confusing at all, huh? This is the param where the pipename is entered
let PipeLoRangeParams    : [Any] = ["LoRange",      "text", "mt"]
let PipeHiRangeParams    : [Any] = ["HiRange",      "text", "mt"]   //..12.9 wups
let PipeNameParams       : [Any] = ["Name",         "text", "mt"]
let PipeCommParams       : [Any] = ["Comment",      "text", "mt"]
// This is an array of all parameter names...
let pipeParamNames : [String] = ["InputChannel", "OutputParam","LoRange","HiRange","Name","Comment"]

var pipeParamsDictionary = Dictionary<String, [Any]>()

struct OogiePipe {
    //User Params come from here...
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

    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()

    //======(OogiePipe)=============================================
    // Gotta have all 4 args b4 init!
    init() // fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
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
        pipeParamsDictionary["02"] = PipeLoRangeParams
        pipeParamsDictionary["03"] = PipeHiRangeParams
        pipeParamsDictionary["04"] = PipeNameParams
        pipeParamsDictionary["05"] = PipeCommParams
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
            print("pipe \(PS.name): \(PS.fromChannel) = \(f)")
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
    func dumpParams() -> String
    {
        var s = String(format: "[key:%@]\n",PS.key)
        for pname in pipeParamNames
        {
            let pTuple = getParam(named : pname.lowercased())
            s = s + String(format: "%@:%@\n",pname,pTuple.sParam)
        }
        s = s + String(format: "fromObject:%@\n",PS.fromObject)
        s = s + String(format: "toObject  :%@\n",PS.toObject)
        s = s + String(format: "UID:%@\n",PS.uid)
        return s
    }
    

    //======(OogiePipe)=============================================
    mutating func getParamList() -> [String]
     {
         if !paramListDirty {return paramList} //get old list if no new params
         paramList.removeAll()
         for pname in pipeParamNames
         {
             let pTuple = getParam(named : pname.lowercased())
             paramList.append(pTuple.sParam)
         }
         paramListDirty = false
         return paramList
     } //end getParamList

    //======(OogiePipe)=============================================
    // 4/22/20 gets param named "whatever", returns tuple
    func getParam(named name : String) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = "empty"
        switch (name)  //depending on param, set double or string
        {
        case "inputchannel":
            sp = PS.fromChannel
        case "outputparam":
            sp = PS.toParam
        case "lorange" : // 12/9 add lo/hi range as strings
            dp = PS.loRange
            let lorg = PS.loRange
            sp = String(lorg)
        case "hirange" :
            dp = PS.hiRange
            let horg = PS.hiRange
            sp = String(horg)
        case "name"    :
            sp = PS.name
        case "comment"    :
            sp = PS.comment
        default:print("Error:Bad pipe param in get")
        }
        return(name , dp , sp)  //pack up name,double,string
    } //end getParam

    //======(OogiePipe)=============================================
    // 4/23 sets param by name to either double or string depending on type
    //  NOTE: some fields need to be pre-processed before storing, that
    //   is the responsibility of the caller!
    mutating func setParam(named name : String , toDouble dval: Double , toString sval: String)
    {
        switch (name)
        {
        case "inputchannel" : PS.fromChannel = sval
        case "outputparam"  :  PS.toParam    = sval
        case "lorange"      : PS.loRange     = dval
        case "hirange"      : PS.hiRange     = dval
        case "name"         : PS.name        = sval
        case "comment"      : PS.comment     = sval
        default:print("Error:Bad pipe param in set")
        }
        paramListDirty = true
    } //end setParam

    
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

