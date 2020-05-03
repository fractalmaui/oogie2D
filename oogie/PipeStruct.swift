//   ____  _            ____  _                   _
//  |  _ \(_)_ __   ___/ ___|| |_ _ __ _   _  ___| |_
//  | |_) | | '_ \ / _ \___ \| __| '__| | | |/ __| __|
//  |  __/| | |_) |  __/___) | |_| |  | |_| | (__| |_
//  |_|   |_| .__/ \___|____/ \__|_|   \__,_|\___|\__|
//          |_|
//
//  PipeStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
// 2/3 add name,comment field
// 4/22 add getParam func
import Foundation
struct PipeStruct : Codable {
    //These are all user-settable params for a pipe...
    var key          : String    //4/30 stored in dictionary under this key
    var name         : String    //2/3 add comment
    var comment      : String    //2/3 add comment
    var fromObject   : String    //Format objtype : objname : "shape:shape001"
    var toObject     : String    //  same format
    var fromChannel  : String
    var toParam      : String
    var loRange      : Double    //hi/lo ranges convert incoming
    var hiRange      : Double    // channel data to desired output range
    var delay        : Int       //delay is in frames (30fps default)
    var uid          : String

    //======(OogiePipe)=============================================
    init()
    {
        key         = ""
        name        = ""
        comment     = COMMENT_DEFAULT //2/3
        fromObject  = "nada"
        toObject    = "nada"
        fromChannel = "nada"
        toParam     = "nada"
        loRange     = 0.0
        hiRange     = 1.0
        delay       = 0
        //5/1 uid
        uid         = "pipe_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(OogiePipe)=============================================
    //Most likely called this way from mainVC menu choices
    init( fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
        key              = ""              //4/30
        name             = ""              //2/3 new fields
        comment          = COMMENT_DEFAULT //2/3
        self.fromObject  = fromObject
        self.fromChannel = fromChannel.lowercased()
        self.toObject    = toObject
        self.toParam     = toParam.lowercased()
        loRange          = 0.1
        hiRange          = 1.0
        delay            = 0
        uid              = "pipe_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    
    //======(OSStruct)=============================================
    func getNewUID() -> String
    {
        return "pipe_" + ProcessInfo.processInfo.globallyUniqueString
    }

}

