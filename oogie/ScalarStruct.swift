//
//  ScalarStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/13/21
//  Copyright © 2019 fractallonomy. All rights reserved.
//  10/25 add xtraparams
//  12/17 add value, pull delay
import SceneKit
struct ScalarStruct : Codable {
    //These are all user-settable params for a Scalar...
    var key          : String    //4/30 stored in dictionary under this key
    var xPos         : Double
    var yPos         : Double
    var zPos         : Double
    var name         : String
    var comment      : String
    var toObject     : String    //  same format
    var toParam      : String
    var loRange      : Double    //hi/lo ranges convert incoming
    var hiRange      : Double    // channel data to desired output range
    var value        : Double    // 12/17 add value, 0.0 ... 1.0
    var invert       : Int       //9/28/21 add invert / op items
    var op           : String
    var uid          : String
    var xtraParams  : String //10/25. ADD NEW FIELD for audio 3D placement, whatever in the future...

    //======(ScalarStruct)=============================================
    init()
    {
        key         = ""
        name        = ""
        comment     = COMMENT_DEFAULT //2/3
        xtraParams = ""  //10/25/21
        toObject    = "nada"
        toParam     = "nada"
        loRange     = 0.0
        hiRange     = 1.0
        xPos        = 0.0
        yPos        = 0.0
        zPos        = 0.0
        value       = 0.0
        invert      = 0
        op          = ""
        uid         = "scalar_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(ScalarStruct)=============================================
    //Most likely called this way from mainVC menu choices
    //  note: no from object, etc with scalar...
    init( toObject:String , toParam:String)
    {
        key              = ""              //4/30
        name             = ""
        comment          = COMMENT_DEFAULT
        xtraParams       = ""  //10/25/21
        self.toObject    = toObject
        self.toParam     = toParam.lowercased()
        loRange          = 0.1
        hiRange          = 1.0
        xPos             = 0.0
        yPos             = 0.0
        zPos             = 0.0
        value            = 0.0
        invert           = 0
        op               = ""
        uid              = "scalar_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    
    //======(ScalarStruct)=============================================
    func getNewUID() -> String
    {
        return "scalar_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(ScalarStruct)=============================================
    func getPosition() ->SCNVector3
    {
        return SCNVector3(xPos,yPos,zPos)
    }


}

