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
import Foundation

let TexParams   : [Any] = ["Texture", "texture", "mt"]
let RotParams   : [Any] = ["Rotation" , "double", 0.0  , 100.0   , 10.0, 1.0, 0.0 ]
let RotTypeParams  : [Any] = ["RotationType", "string" , "Manual", "BPMX1", "BPMX2", "BPMX3", "BPMX4", "BPMX5", "BPMX6", "BPMX7", "BPMX8" ]
let XParams     : [Any] = ["XPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let YParams     : [Any] = ["YPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let ZParams     : [Any] = ["ZPos" , "double", -maxMeters , maxMeters , 0.0, 1.0, 0.0 ]
let UParams     : [Any] = ["TexXoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
let VParams     : [Any] = ["TexYoffset" , "double", 0.0 , 1.0 , 0.0, 1.0, 0.0 ]
let USParams    : [Any] = ["TexXscale" , "double", 0.1 , 10.0 , 1.0, 1.0, 0.0 ]
let VSParams    : [Any] = ["TexYscale" , "double", 0.1 , 10.0 , 1.0, 1.0, 0.0 ]
let SNameParams : [Any] = ["Name",      "text", "mt"]
let SCommParams : [Any] = ["Comment",   "text", "mt"]

let shapeParamNames : [String] = ["Texture", "Rotation","RotationType",
"XPos","YPos","ZPos","TexXoffset","TexYoffset","TexXscale","TexYscale","Name","Comment"]
let shapeParamNamesOKForPipe : [String] = ["Rotation","RotationType","TexXoffset",
                                           "TexYoffset","TexXscale","TexYscale"]

var shapeParamsDictionary = Dictionary<String, [Any]>()

class OogieShape: NSObject {

    var OOS  = OSStruct()  // codable struct for i/o
    var inPipes = Set<String>()   //use insert and remove to manage...
    var paramListDirty = true //4/25 add paramList for display purposes
    var paramList  = [String]()

    //-----------(oogieShape)=============================================
    override init() {
        super.init()
        setupShapeParams()
    }
    
    //-----------(oogieVoice)=============================================
    func setupShapeParams()
    {
        // Load up params dictionary with string / array combos
        shapeParamsDictionary["00"] = TexParams
        shapeParamsDictionary["01"] = RotParams
        shapeParamsDictionary["02"] = RotTypeParams
        shapeParamsDictionary["03"] = XParams
        shapeParamsDictionary["04"] = YParams
        shapeParamsDictionary["05"] = ZParams
        shapeParamsDictionary["06"] = UParams
        shapeParamsDictionary["07"] = VParams
        shapeParamsDictionary["08"] = USParams
        shapeParamsDictionary["09"] = VSParams
        shapeParamsDictionary["10"] = SNameParams //2/4
        shapeParamsDictionary["11"] = SCommParams //2/4
    } //end setupShapeParams
        
    
  
    //-----------(oogieVoice)=============================================
    func getNthParams(n : Int) -> [Any]
    {
        if n < 0 || n >= shapeParamsDictionary.count {return []}
        let key =  String(format: "%02d", n)
        return shapeParamsDictionary[key]!
    }
    
    //======(OSStruct)=============================================
    func getParamCount() -> Int
    {
        return shapeParamNames.count
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
        for pname in shapeParamNames
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
        for pname in shapeParamNames
        {
            let pTuple = getParam(named : pname.lowercased())
            paramList.append(pTuple.sParam)
        }
        paramListDirty = false
        return paramList
    } //end getParamList

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
        case "rotationtype": OOS.rotation = floor(dval + 0.5) //4/27 fractions make no sense
        case "xpos"        : OOS.xPos     = dval
        case "ypos"        : OOS.yPos     = dval
        case "zpos"        : OOS.zPos     = dval
        case "texxoffset"  : OOS.uCoord   = dval
        case "texyoffset"  : OOS.vCoord   = dval
        case "texxscale"   : OOS.uScale   = dval
        case "texyscale"   : OOS.vScale   = dval
        case "name"        : OOS.name     = sval
        case "comment"     : OOS.comment  = sval
        default:print("Error:Bad shape param in set")
        }
        paramListDirty = true
    } //end setParam
    
}
