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
//
//  BUG in deleteImageFile!!
//   {Error Domain=NSPOSIXErrorDomain Code=2 "No such file or directory"}}
import Foundation

class texCache {
    
    
    //This is supposed to be a singleton...
    static let sharedInstance = texCache()

    var cachesDirectory : URL
    var cacheMasterURL  : URL
    var cacheMasterFile = ""
    var texDict         = Dictionary<String, UIImage>()
    var cacheSize       = 0
    var cacheNames      : [String] = []

    //=====(texCache)=============================================
    //This makes sure your singletons are truly unique and prevents
    //  outside objects from creating their own instances of your class t
    private init()
    {
        //print(" texCache isborn")
        cacheMasterFile = "cacheList.txt"
        cachesDirectory = DataManager.getCacheDirectory().appendingPathComponent("textures")
        cacheMasterURL  = cachesDirectory.appendingPathComponent(cacheMasterFile)
        print(" cache URL \(cacheMasterURL)")
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
            catch {/* error handling here */}
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
    func loadCache()
    {
        for nextFileName in cacheNames{
            //let nextURL = cachesDirectory.appendingPathComponent(nextPNG)
            if let nextImage = loadCacheImage(fileName: nextFileName)
            {
                texDict[nextFileName] = nextImage
            }
        } //end for...
    } //end loadCache
        
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
    func addImage(fileName : String , image: UIImage)
    {
        if texDict[fileName] != nil {return} //No dupes
        saveCacheImage(fileName: fileName, image: image)
        updateMasterFile(latestFileName: fileName)
        texDict[fileName] = image
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
    
}
