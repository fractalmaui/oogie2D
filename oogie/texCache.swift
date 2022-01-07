//    _             ____           _
//   | |_ _____  __/ ___|__ _  ___| |__   ___
//   | __/ _ \ \/ / |   / _` |/ __| '_ \ / _ \
//   | ||  __/>  <| |__| (_| | (__| | | |  __/
//    \__\___/_/\_\\____\__,_|\___|_| |_|\___|
//
//  texCache.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/3/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//  https://stackoverflow.com/questions/40396110/convert-uiimage-to-base64-string-in-swift
//  Textures live in this folder:
//  /...appshit/Library/Caches/textures
//  BUG in deleteImageFile!!
//   {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
// 10/7/21 change cachesDirectory, use bundleID
//   toplevelfolders/appID/Library/Caches/com.frak.oogie2d/filesgohere
// 10/28 add thumbDict
// 11/7  add encode/decode for DB thunb support
// 11/9  add grads 000
// 11/11 add getRandomTextureName
// 11/15 add defaultTexture
// 12/15 add keysSortedByDate,Alpha
// 12/27 add fabric (maybe in its own folder?)

import Foundation

class texCache {
    //This is supposed to be a singleton...
    static let sharedInstance = texCache()

    var cachesDirectory : URL
    var cacheMasterURL  : URL
    var cacheMasterFile = ""
    var texDict         = Dictionary<String, UIImage>()
    var texAttrs        = Dictionary<String, Dictionary<FileAttributeKey,Any>>()
    var thumbDict       = Dictionary<String, UIImage>() //10/28
    var cacheSize       = 0
    var cacheNames      : [String] = []
    let defaultTexture  = UIImage(named:"spectrumOLD")
    var old80sDate      = Date()

    //=====(texCache)=============================================
    //This makes sure your singletons are truly unique and prevents
    //  outside objects from creating their own instances of your class t
    private init()
    {
        //print(" texCache isborn")
        let bundle =  Bundle.main.bundleIdentifier //assume this is always valid! force unwrap below
        cacheMasterFile = "cacheList.txt"
        cachesDirectory = DataManager.getCacheDirectory().appendingPathComponent(bundle!)
        cacheMasterURL  = cachesDirectory.appendingPathComponent(cacheMasterFile)
        //print(" cache URL \(cacheMasterURL)")
        
        //get olllld date for use in sorting builtin textures vs new ones
        var dco = DateComponents()
        dco.year  = 1980
        dco.month = 1
        dco.day   = 1
        let cal = Calendar(identifier: .gregorian)
        old80sDate = cal.date(from:dco)!
        
        
        loadMasterCacheFile()
        loadCache()
    }
    
    //=====(texCache)=============================================
    // delete internal AND file!
    func deleteTextureCompletely(name:String)
    {
        //delete from dictionary
        texDict.removeValue(forKey: name)
        //delete from cache names
        let index = cacheNames.index(of: name)
        if index != NSNotFound
        {
            cacheNames.remove(at: index!)
        }
        rewriteMasterCacheFile()
        deleteImageFile(fileName : name)
    } //end deleteItemByName
    
    //=====(texCache)=============================================
    // refreshes ENTIRE master cache file...
    func rewriteMasterCacheFile()
    {
        var joined = ""
        for name in cacheNames //assemble string for output
        {
            if name.count > 1 //avoid trivial strings
                {joined = joined + name + "\n"}
        }
        do {  //write text to file
            try joined.write(to: cacheMasterURL, atomically: false, encoding: .utf8)
        }
        catch {/* error handling here */}
    } //end rewriteMasterCacheFile
    
    //=====(texCache)=============================================
    func getRandomTextureName() -> String
    {
        let keys = Array(texDict.keys)
        let rint = Int.random(in: 0..<keys.count)
        return keys[rint]
    }
    
    //=====(texCache)=============================================
    // look in cache folder, get masterfile name...
    func loadMasterCacheFile()
    {
       do {
            let content =  try String(contentsOf:cacheMasterURL, encoding: .utf8)
            cacheNames = content.components(separatedBy: "\n")
        } catch _ as NSError {
            return
        }
        
    }

    //=====(texCache)=============================================
    // exists? update. create otherwise
    func updateMasterFile(latestFileName : String)
    {
        let stringToWrite = latestFileName + "\n"
        print("update textures \(cacheMasterURL.path)")
        if FileManager.default.fileExists(atPath: cacheMasterURL.path) //exists?
        {
            if let fileUpdater = try? FileHandle(forUpdating: cacheMasterURL) {
                // function which when called will cause all updates to start from end of the file
                fileUpdater.seekToEndOfFile()
                fileUpdater.write(stringToWrite.data(using: .utf8)!)
                //Close the file and that’s it!
                fileUpdater.closeFile()
            }
        }
        else //create?
        {
            do {  //write text to file 
                try stringToWrite.write(to: cacheMasterURL, atomically: false, encoding: .utf8)
            }
            catch {print("ERROR writing texture cache!")}
        }
    }
    
    
    //=====(texCache)=============================================
    // boilerplate from stackoverflow,
    private func loadCacheImage(fileName: String) -> UIImage? {
        
        let fileURL = cachesDirectory.appendingPathComponent(fileName)
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            print("Error loading image : \(error)")
        }
        return nil
    }
    
    //=====(texCache)=============================================
    // assumes textdict is EMPTY
    func loadCache()
    {
        //11/9 add canned grad(s)
        //11/20 multiple canned textures
        for tname in ["grads000","chex000","mondrian_composite",
                      "fabric01.jpg","fabric02.jpg","fabric03.jpg","fabric04.jpg","fabric05.jpg",
                      "samcham.jpg","earthclouds.jpg"
                     ]
        {
            print("load tex " + tname)
            if let texture = UIImage(named: tname) //11/20
            {
                texDict[tname]   = texture
                thumbDict[tname] = getThumbWith(image: texture)
            }
        }

        for nextFileName in cacheNames{
            //let nextURL = cachesDirectory.appendingPathComponent(nextPNG)
            if let nextImage = loadCacheImage(fileName: nextFileName)
            {
                texDict[nextFileName] = nextImage
                thumbDict[nextFileName] = getThumbWith(image: nextImage)  //10/28
                saveAttributesForFile(fname: nextFileName)
            }
        } //end for...
    } //end loadCache
    
    //=====(texCache)=============================================
    //  12/16 new
    func saveAttributesForFile (fname:String)
    {
        // get attrs...
        let fileURL = cachesDirectory.appendingPathComponent(fname)
        do{
            let fm = try FileManager.default.attributesOfItem(atPath: fileURL.path) //12/15 file attrs
            texAttrs[fname] = fm
        }
        catch{
        }
    } //end saveAttributesForFile
    
    //=====(texCache)=============================================
    // 12/15 for sorting cache items...
    func keysSortedByAlpha() -> [String]
    {
        return texDict.keys.sorted()
    } //end keysSortedByAlpha
    
    //=====(texCache)=============================================
    // 12/15 for sorting cache items...
    func keysSortedByDate() -> [String]
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd.HH.mm.ss"
        var workArray = [String]()
        print("degug: keysbydate")
        for key in texDict.keys  //loop over all keys
        {
            var cDate = old80sDate //start w ollld date
            if let attr = texAttrs[key]  //get attr if it exists
            {
                cDate = attr[FileAttributeKey.creationDate] as! Date
            }
            let s =  dateFormatter.string(from: cDate) + "%" + key
            print(s)
            workArray.append(s)
        }
        var results = [String]()
        for s in workArray.sorted()
        {
            let pair = s.split(separator:"%")
            if pair.count > 1
            {
                let skey = String(pair[1])
                results.append(skey)
                print("...result \(skey)")
            }
        }
        return results
    } //end keysSortedByDate
    
    //=====(texCache)=============================================
    // 9/28 moved from mainVC
    func loadNamesToArray() -> [String]
    {
        var a : [String] = []
        a.append("default")
        for (name, _) in texDict
            {
             a.append(name)
            }
        return a
    }

        
    //=====(texCache)=============================================
    // boilerplate from stackoverflow,
    func saveCacheImage(fileName : String , image: UIImage)  {
        let fileURL = cachesDirectory.appendingPathComponent(fileName)
        if let imageData = UIImageJPEGRepresentation(image, 1.0) {
            try? imageData.write(to: fileURL, options: .atomic)
            return  // ----> Save fileName
        }
        print("Error saving image")
        return
    }
    
    //=====(texCache)=============================================
    //Shrinkem
    func getThumbWith ( image : UIImage) -> UIImage
    {
        if let ii = image.scalingAndCropping(for: CGSize(width: 64, height: 64))
        {
            return ii
        }
        return UIImage()
    }
    
    
    //=====(texCache)=============================================
    func addImage(fileName : String , image: UIImage)
    {
        if texDict[fileName] != nil {return} //No dupes
        saveCacheImage(fileName: fileName, image: image)
        updateMasterFile(latestFileName: fileName)
        texDict[fileName] = image
        thumbDict[fileName] = getThumbWith(image: image)
        saveAttributesForFile(fname: fileName) //12/16
        cacheNames.append(fileName)
    }

    //=====(texCache)=============================================
    func deleteImageFile(fileName : String)
    {
        let fileURL = cachesDirectory.appendingPathComponent(fileName)
        do {  //delete file!
            print("  deleting \(fileURL.absoluteString)...")
            try FileManager.default.removeItem(atPath: fileURL.absoluteString)
        }
        catch let error {
            print("delete error: \(error)")
        }
    }
    
    //=====(texCache)=============================================
    public func createLilThumb(ii : UIImage) -> UIImage {
        let isize = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        //12/16 let context = UIGraphicsGetCurrentContext()!
        ii.draw(in: CGRect(origin: CGPoint.zero, size: isize))
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createGridImage
    
    //=====(texCache)=============================================
    // 11/7 new
    func encodeThumbForCloud (key : String) -> String
    {
        if let ii = texDict[key]
        {
            let lili = createLilThumb(ii: ii)
            return encodeImage(ii: lili)
        }
        return "error" //failure
    }
    
    //=====(texCache)=============================================
    // 11/7 new
    func encodeImage (ii : UIImage) -> String
    {
        let imageData = UIImagePNGRepresentation(ii)! as NSData
        let strBase64:String = imageData.base64EncodedString()
        //print("encoded to [\(strBase64)]")
        return strBase64
    }
    
    //=====(texCache)=============================================
    // 11/7 new
    func decodeImage (strBase64 : String) -> UIImage?
    {
        let decodedimage = UIImage()
        if let imageData = NSData(base64Encoded: strBase64, options: .ignoreUnknownCharacters)
        {
            if let ii3 = UIImage(data: imageData as Data) { return ii3 } //return image if OK
        }
        else {print("bogus data")}
        return decodedimage //return nil if not OK
    }

    //=====(texCache)=============================================
    // 11/7 new
    func decodeNewThumbFromCloud(name: String , strBase64 : String)
    {
        if let ii = decodeImage(strBase64: strBase64) //decode our image...
        {
            thumbDict[name] = ii  //...and save it!
            if texDict[name] == nil //no texture either? use thumb
                    { texDict[name] = ii  }
        }
    }

}
