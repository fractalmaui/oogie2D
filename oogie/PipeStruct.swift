//
//  PipeStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/28/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//

import Foundation
struct PipeStruct : Codable {
    //These are all user-settable params for a pipe...
    var fromObject   : String    //Format objtype : objname : "shape:shape001"
    var toObject     : String    //  same format
    var fromChannel  : String
    var toParam      : String
    var loRange      : Double
    var hiRange      : Double
    
    //======(OogiePipe)=============================================
    init()
    {
        fromObject  = "nada"
        toObject    = "nada"
        fromChannel = "nada"
        toParam     = "nada"
        loRange     = 0.0
        hiRange     = 1.0
    }
}

