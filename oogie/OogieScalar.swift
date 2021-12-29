//
//    ___              _      ____            _
//   / _ \  ___   __ _(_) ___/ ___|  ___ __ _| | __ _ _ __
//  | | | |/ _ \ / _` | |/ _ \___ \ / __/ _` | |/ _` | '__|
//  | |_| | (_) | (_| | |  __/___) | (_| (_| | | (_| | |
//   \___/ \___/ \__, |_|\___|____/ \___\__,_|_|\__,_|_|
//               |___/
//
//  OogieScalar.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/13/21
//  Copyright © 2019 fractallonomy. All rights reserved.
//  very similar to oogiePipe but w/o input channel
//  12/17 add scalar value
//  12/25 make scalars snap to grid
import Foundation
import SceneKit

struct OogieScalar {
    //User Params come from here...
    var SS      : ScalarStruct
    var OSP     =  OogieScalarParams.sharedInstance //9/18/21 oogie voice params
    //Working variables...
    var multF   = 1.0
    var destination = ""
    var gotData = false //11/25
    var uid     = "nouid"
    var value   = 0.0
    var dValue = 0.0 //12/19 display value
    
    let SCALAR_GRID_SNAP = 0.2 //12/25 make scalars snap to grid

    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()
    
    //======(OogieScalar)=============================================
    // Gotta have all 4 args b4 init!
    init()
    {
        SS  = ScalarStruct()
        uid = "scalar_" + ProcessInfo.processInfo.globallyUniqueString //1/21 wups no uid!
    }
    
    //-----------(OogieScalar)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= OSP.scalarParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return OSP.scalarParamsDictionary[key]!
    }
    
    //-----------(OogieScalar)=============================================
    func getParamCount() -> Int
    {
        return OSP.scalarParamNames.count
    }
    
    //======(OogieScalar)=============================================
    // should this accept integer input?
    // 9/22/21 NOTE this converts data to range 0.0 ... 1.0
    func convertData (f : Float) -> Float
    {
        return Float(SS.loRange) + (f * Float(multF))
    }
    
    //======(OogieScalar)=============================================
    // breaks out toObject substrings, returns as tuple
    func getTO() ->  (otype:String , oname:String )
    {
        let ss = SS.toObject.split(separator: ":")
        if ss.count < 2 {return ("","")}
        return(String(ss[0]),String(ss[1]))
    } //end getTO
    
    
    //======(OogieScalar)=============================================
    func dumpParams() -> String
    {
        var s = String(format: "[key:%@]\n",SS.key)
        for pname in OSP.scalarParamNames //9/19/21
        {
            let pTuple = getParam(named : pname.lowercased())
            s = s + String(format: "%@:%@\n",pname,pTuple.sParam)
        }
        s = s + String(format: "toObject  :%@\n",SS.toObject)
        s = s + String(format: "UID:%@\n",SS.uid)
        return s
    }
    
    
    //======(OogieScalar)=============================================
    mutating func getParamList() -> [String]
    {
        if !paramListDirty {return paramList} //get old list if no new params
        paramList.removeAll()
        for pname in OSP.scalarParamNames //9/19/21
        {
            let pTuple = getParam(named : pname.lowercased())
            paramList.append(pTuple.sParam)
        }
        paramListDirty = false
        return paramList
    } //end getParamList
    
    
    //======(OogieScalar)=============================================
    // returns dict with packed param arrays... asdf
    func getParamDict() -> Dictionary<String,Any>
    {
        var d = Dictionary<String, Any>()
        for pname in OSP.scalarParamNames //look at all params...
        {
            //print("pack pipe param \(pname)")
            let plow = pname.lowercased()
            let pTuple = getParam(named : plow)
            let sv = pTuple.sParam
            var dv = pTuple.dParam as Double
            if let paramz = OSP.scalarParamsDictionary[plow]  //get param info...
            {
                var workArray = paramz  //copy
                if let ptype = paramz[1] as? String
                {
                    if ptype == "double"  //double type? do some conversion
                    {
                        if let lolim  = paramz[6] as? Double
                        {
                            if let lrange = paramz[5] as? Double
                            {
                                if lrange != 0.0 //9/16 DO not apply range shift to int params!
                                {
                                    dv = (dv - lolim) / lrange
                                }  //one million ifs beneath the sea...
                            }
                        }
                        workArray.append(NSNumber(value:dv))
                    } //end if ptype double 
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
    
    
    //======(OogieScalar)=============================================
    // gets param named "whatever", returns tuple
    func getParam(named name : String) -> (name:String , dParam:Double , sParam:String )
    {
        var dp = 0.0
        var sp = "empty"
        switch (name)  //depending on param, set double or string
        {
        case "outputparam":
            sp = SS.toParam.lowercased() //9/19/21
        case "lorange" : // 12/9 add lo/hi range as strings
            dp = SS.loRange
            let lorg = SS.loRange
            sp = String(lorg)
        case "hirange" :
            dp = SS.hiRange
            let horg = SS.hiRange
            sp = String(horg)
        case "value"    : //12/17 add value
            dp = SS.value
        case "invert"    :
            dp = Double(SS.invert) //10/5
        case "xpos": dp = SS.xPos
        case "ypos": dp = SS.yPos
        case "zpos": dp = SS.zPos
        case "name"    :
            sp = SS.name
        case "comment"    :
            sp = SS.comment
        default:print("Error:Bad pipe param in get")
        }
        return(name , dp , sp)  //pack up name,double,string
    } //end getParam
    
    
    //======(OogieScalar)=============================================
    //we need to handle this the latest /prev touch points t2 / t1 to stay independent of any UI
    // empty for now, maybe at AR time?
    mutating func handleTouch (t1:CGPoint , t2:CGPoint)
    {
        //        if let scalar = OVScene.sceneScalars
                
                //        let t1 = startTouch.location(in: sceneView)
        //        let t2 = latestTouch.location(in:  sceneView)
//                let dx = t1.x - t2.x
//                let dy = t1.y - t2.y
                //print("scalar handleTouch: moved delta \(dx), \(dy)")
    } //end handleTouch
    
    //======(OogieScalar)=============================================
    //  sets param by name to either double or string depending on type
    //  NOTE: some fields need to be pre-processed before storing, that
    //   is the responsibility of the caller!
    mutating func setParam(named name : String , toDouble dval: Double , toString sval: String)
    {
        switch (name)
        {
        case "outputparam"  : SS.toParam     = sval
        case "lorange"      : SS.loRange     = dval ; setupRange(lo: SS.loRange,hi: SS.hiRange)  //5/2
        case "hirange"      : SS.hiRange     = dval ; setupRange(lo: SS.loRange,hi: SS.hiRange)  //5/2
        case "value"        : SS.value       = dval   //12/17 add value
        case "invert"       : SS.invert      = Int(dval) //10/5 invert
        case "xpos"         : SS.xPos        = snapToGrid(dxyz: dval)
        case "ypos"         : SS.yPos        = snapToGrid(dxyz: dval)
        case "zpos"         : SS.zPos        = snapToGrid(dxyz: dval)
        case "name"         : SS.name        = sval
        case "comment"      : SS.comment     = sval
        default:print("Error:Bad pipe param in set")
        }
        paramListDirty = true
    } //end setParam
    
    //======(OogieScalar)=============================================
    func snapToGrid ( dxyz : Double) -> Double
    {
        let dint = Int(dxyz / SCALAR_GRID_SNAP)
        return Double(dint) * SCALAR_GRID_SNAP
    }
    
    //======(OogieScalar)=============================================
    mutating func setupRange(lo:Double , hi:Double)
    {
        //illegal input? Just bail for now
        if (lo > hi) || (hi-lo < 0.05) { return } //1/14 Wups need tighter check
        SS.loRange = lo
        SS.hiRange = hi
        multF = (hi-lo) / 256.0 // fit color channel into range
        //print("PIPE: setuprange lo/hi \(lo) /(hi) -> multf \(multF)")
    } //end setupRange

} //end OogieScalar struct

