//   ____  ____  ____  _                   _
//  / ___||  _ \/ ___|| |_ _ __ _   _  ___| |_
//  \___ \| |_) \___ \| __| '__| | | |/ __| __|
//   ___) |  __/ ___) | |_| |  | |_| | (__| |_
//  |____/|_|   |____/ \__|_|   \__,_|\___|\__|
//
//  SPStruct.swift
//  oogie2D
//
//  Created by Dave Scruton on 6/15/20
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//  SoundPack : this loads up an array of patches
import Foundation


struct SPStruct : Codable {
    var size       : Int  //# of patches herein..
    var name       : String
    var patchNames = [String]()
    var patches    = [OogiePatch]()
    var uid         : String //5/1
    
    //======(SPStruct)=============================================
    init()
    {
        size = 0
        name = "empty"
        uid  = "soundPack_" + ProcessInfo.processInfo.globallyUniqueString
    }
    
    //======(SPStruct)=============================================
    // 10/3 restruct
    mutating func clear()
    {
        size = 0
        name = "empty"
        patchNames.removeAll()
        patches.removeAll()
    }
    
    //======(SPStruct)=============================================
    mutating func addPatch ( name:String , patch : OogiePatch)
    {
        patchNames.append(name)
        patches.append(patch)
        size += 1
    }
    
    
}

