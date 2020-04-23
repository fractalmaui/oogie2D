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
    var name         : String    //2/3 add comment
    var comment      : String    //2/3 add comment
    var fromObject   : String    //Format objtype : objname : "shape:shape001"
    var toObject     : String    //  same format
    var fromChannel  : String
    var toParam      : String
    var loRange      : Double    //hi/lo ranges convert incoming
    var hiRange      : Double    // channel data to desired output range
    var delay        : Int       //delay is in frames (30fps default)

    //======(OogiePipe)=============================================
    init()
    {
        name        = ""              //2/3 new fields
        comment     = COMMENT_DEFAULT //2/3
        fromObject  = "nada"
        toObject    = "nada"
        fromChannel = "nada"
        toParam     = "nada"
        loRange     = 0.0
        hiRange     = 1.0
        delay       = 0
    }
    
    //======(OogiePipe)=============================================
    //Most likely called this way from mainVC menu choices
    init( fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
        name             = ""              //2/3 new fields
        comment          = COMMENT_DEFAULT //2/3
        self.fromObject  = fromObject
        self.fromChannel = fromChannel.lowercased()
        self.toObject    = toObject
        self.toParam     = toParam.lowercased()
        loRange          = 0.0
        hiRange          = 1.0
        delay            = 0

    }
    
}

