//
//         _            ___        __
//   _ __ (_)_ __   ___|_ _|_ __  / _| ___
//  | '_ \| | '_ \ / _ \| || '_ \| |_ / _ \
//  | |_) | | |_) |  __/| || | | |  _| (_) |
//  | .__/|_| .__/ \___|___|_| |_|_|  \___/
//  |_|     |_|
//
//  pipeInfo.swift
//  oogie2D
//
//  Created by Dave Scruton on 10/6/21.
//  Copyright © 2021 fractallonomy. All rights reserved.
//
//  convenience struct for accessing pipe buffer info

struct pipeInfo {
    var pbSize  = 256
    var bptr    = 0
    var wrapped = false
    var buffer : [Float]
    
    init() // fromObject:String , fromChannel:String , toObject:String , toParam:String)
    {
        buffer  = [] //set up our input/output data buffers
        bptr    = 0
        wrapped = false
        pbSize  = 256
    }

}
