//   ____        _        __  __
//  |  _ \  __ _| |_ __ _|  \/  | __ _ _ __   __ _  __ _  ___ _ __
//  | | | |/ _` | __/ _` | |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '__|
//  | |_| | (_| | || (_| | |  | | (_| | | | | (_| | (_| |  __/ |
//  |____/ \__,_|\__\__,_|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|
//                                                 |___/
//
//  DataManger.swift
//  TodoApp
//
//  From Github 8/3/19
//
//  Note everything is static. This allows calls to these methods
//   without instantiating an object.
//  added subfolders for patch / voice / etc storage
//  8/15 added subfolders for patches / voices, retooled everything
//  8/24 added shapes / scenes subfolders
//  9/3  add texture cache subfolder, made all get*Directory funcs public
//  9/15 add dump
// 10/27 pull (most) fatals, replace w/ delegate callbacks
//         still have fatals on methods with dynamic types!
import Foundation



public class DataManager {

    //======(DataManager)=============================================
    // Must be called ONCE before any subfolders are accessed!
    static func createSubfolders()
    {
        let url   = getDocumentDirectory()
        let urlP  = url.appendingPathComponent("patches")
        let urlV  = url.appendingPathComponent("voices")
        let urlS  = url.appendingPathComponent("shapes")
        let urlZ  = url.appendingPathComponent("scenes")
        let curl  = getCacheDirectory()
        let curlT = curl.appendingPathComponent("textures")
        do
        {
            try FileManager.default.createDirectory(atPath: urlP.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: urlV.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: urlS.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: urlZ.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: curlT.path, withIntermediateDirectories: true, attributes: nil)
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
    } //end createSubfolders
  
    //======(DataManager)=============================================
    // get Document Directory
    static func getDocumentDirectory () -> URL {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url
        }else{
            self.gotDMError(msg: "Unable to access document directory")
            return URL(fileURLWithPath: "") //Empty for now?
        }
    }

    //======(DataManager)=============================================
    // get Cache Directory
    static func getCacheDirectory () -> URL {
        if let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return url
        }else{
            self.gotDMError(msg: "Unable to access cache directory")
            return URL(fileURLWithPath: "") //Empty for now?
        }
    }
    
    //======(DataManager)=============================================
    // get Patch Directory
    static func getPatchDirectory () -> URL {
        return getDocumentDirectory().appendingPathComponent("patches")
    }
    
    //======(DataManager)=============================================
    // get Scenes Directory
    static func getSceneDirectory () -> URL {
        return getDocumentDirectory().appendingPathComponent("scenes")
    }
    
    //======(DataManager)=============================================
    // get Patch Directory
    static func getShapeDirectory () -> URL {
        return getDocumentDirectory().appendingPathComponent("shapes")
    }
    
    //======(DataManager)=============================================
    // get Voice directory
    static func getVoiceDirectory () -> URL {
        return getDocumentDirectory().appendingPathComponent("voices")
    }

     //======(DataManager)=============================================
    static func getSceneDirectoryContents() -> [String]
    {
        do {
            let url = getSceneDirectory()
            let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return files
        }catch{
            fatalError("could not find scene directory")
        }
       // return []
    }

    //======(DataManager)=============================================
    static func savePatch <T:Encodable> (_ object:T, with fileName:String) {
        print("savePatch \(getPatchDirectory())/\(fileName))")
        save(object , with: getPatchDirectory(), with: fileName)
    }
    
    //======(DataManager)=============================================
    static func saveShape <T:Encodable> (_ object:T, with fileName:String) {
        save(object , with: getShapeDirectory(), with: fileName)
    }

    //======(DataManager)=============================================
    static func saveScene <T:Encodable> (_ object:T, with fileName:String) {
        print("saveScene \(getSceneDirectory())/\(fileName))")
        save(object , with: getSceneDirectory(), with: fileName)
    }


    //======(DataManager)=============================================
    static func saveVoice <T:Encodable> (_ object:T, with fileName:String) {
        save(object , with: getVoiceDirectory(), with: fileName)
    }
    
    //======(DataManager)=============================================
    // Save any kind of codable objects, need url and filename
    static func save <T:Encodable> (_ object:T, with url:URL , with fileName:String) {
        let url2 = url.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url2.path) {
                try FileManager.default.removeItem(at: url2)
            }
            FileManager.default.createFile(atPath: url2.path, contents: data, attributes: nil)
            
        }catch{
            self.gotDMError(msg: error.localizedDescription)
        }
    }
    
    //======(DataManager)=============================================
    // 9/15 new func, diagnostic dump to output log
    static func dump <T:Encodable> (_ object:T) {
        let encoder = JSONEncoder()
        do {
            //How do I get JSONSerialization.WritingOptions.prettyPrinted working?
            let jsonData = try encoder.encode(object)
            let dstring  = String(data: jsonData, encoding: String.Encoding.utf8)
            print(dstring!)
        }catch{
            self.gotDMError(msg: error.localizedDescription)
        }
    } //end dump

    //======(DataManager)=============================================
    // Save any kind of codable objects, just to docs folder
    static func saveToDocs <T:Encodable> (_ object:T, with fileName:String) {
        let url = getDocumentDirectory().appendingPathComponent(fileName, isDirectory: false)
        print("doc URL \(url)")
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
            
        }catch{
            self.gotDMError(msg: error.localizedDescription)
        }
        
    }

    //======(DataManager)=============================================
    //  patches may come from more than one folder, hence the url
    static func loadPatch <T:Decodable> ( url:URL , with fileName:String, with type:T.Type) -> T{
        return load( url ,  with: fileName,  with: type)
    }
    
    //======(DataManager)=============================================
    static func sceneExists( fileName:String) -> Bool
    {
        let url = getSceneDirectory().appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    //======(DataManager)=============================================
    static func loadScene <T:Decodable> (_ fileName:String, with type:T.Type) -> T{
        return load( getSceneDirectory(),  with: fileName,  with: type)
    }
    
    //======(DataManager)=============================================
    static func loadVoice <T:Decodable> (_ fileName:String, with type:T.Type) -> T{
        return load( getVoiceDirectory(),  with: fileName,  with: type)
    }
    
    //======(DataManager)=============================================
    // Load any kind of codable objects, needs URL
    // 10/27 OUCH! How do I return on an error w/o a fatal?
    static func load <T:Decodable> (_ url : URL , with fileName:String, with type:T.Type) -> T {
        let url2 = url.appendingPathComponent(fileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url2.path) {
            fatalError("File not found at path \(url2.path)")
        }
        if let data = FileManager.default.contents(atPath: url2.path) {
            do {
                let model = try JSONDecoder().decode(type, from: data)
                return model
            }catch{
                fatalError( error.localizedDescription)
            }
            
        }else{
            fatalError("Data unavailable at path \(url2.path)")
        }
        
    }
 
    //======(DataManager)=============================================
    // Load any kind of codable objects
    // 10/27 OUCH! How do I return on an error w/o a fatal?
    static func loadFromDocs <T:Decodable> (_ fileName:String, with type:T.Type) -> T {
        let url = getDocumentDirectory().appendingPathComponent(fileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            fatalError("File not found at path \(url.path)")
        }
        
        if let data = FileManager.default.contents(atPath: url.path) {
            do {
                let model = try JSONDecoder().decode(type, from: data)
                return model
            }catch{
                fatalError(error.localizedDescription)
            }
            
        }else{
            fatalError("Data unavailable at path \(url.path)")
        }
    }
    
    
    //======(DataManager)=============================================
    // Load data from a file
    static func loadData (_ fileName:String) -> Data? {
        let url = getDocumentDirectory().appendingPathComponent(fileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            self.gotDMError(msg: "File not found at path \(url.path)")
        }
        
        if let data = FileManager.default.contents(atPath: url.path) {
            return data
            
        }else{
             self.gotDMError(msg:"Data unavailable at path \(url.path)")
        }
        return nil
    }
    
    //======(DataManager)=============================================
    static func loadLocalSynthPatches <T:Decodable> (_ type:T.Type) -> [T] {
        let purl = Bundle.main.resourceURL!.appendingPathComponent("SynthPatches").path
        return loadAll( url: URL.init(fileURLWithPath: purl) , with:type)
    }
    
    //======(DataManager)=============================================
    static func loadLocalPercussionPatches <T:Decodable> (_ type:T.Type) -> [T] {
        let purl = Bundle.main.resourceURL!.appendingPathComponent("PercussionPatches").path
        return loadAll( url: URL.init(fileURLWithPath: purl) , with:type)
    }
    
    //======(DataManager)=============================================
    static func loadLocalPercKitPatches <T:Decodable> (_ type:T.Type) -> [T] {
        let purl = Bundle.main.resourceURL!.appendingPathComponent("PercKitPatches").path
        return loadAll( url: URL.init(fileURLWithPath: purl) , with:type)
    }
    
    //======(DataManager)=============================================
    static func loadLocalGMPatches <T:Decodable> (_ type:T.Type) -> [T] {
        let purl = Bundle.main.resourceURL!.appendingPathComponent("GMPatches").path
        return loadAll( url: URL.init(fileURLWithPath: purl) , with:type)
    }
    

    //======(DataManager)=============================================
    static func loadAllPatches <T:Decodable> (_ type:T.Type) -> [T] {
        return loadAll( url: getPatchDirectory() , with:type)
    }
    
    //======(DataManager)=============================================
    static func loadAllVoices <T:Decodable> (_ type:T.Type) -> [T] {
        return loadAll( url: getVoiceDirectory() , with:type)
    }
    

    //======(DataManager)=============================================
    // Load all files from a directory, needs URL
    static func loadAll <T:Decodable> ( url:URL , with type:T.Type) -> [T] {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
            
            var modelObjects = [T]()
            
            for fileName in files {
                modelObjects.append(loadPatch( url: url, with:fileName, with: type))
            }
            
            return modelObjects
            
            
        }catch{
            fatalError("could not load any files")
        }
    }
    
    
    //======(DataManager)=============================================
    // Delete a file
    static func delete (_ fileName:String) {
        let url = getDocumentDirectory().appendingPathComponent(fileName, isDirectory: false)
        
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            }catch{
                self.gotDMError(msg: error.localizedDescription)
            }
        }
    }
    
    //======(DataManager)=============================================
    // 10/27 shows error but only briefly!
    static func gotDMError(msg: String)
    {
        print("Data Manager Error: \(msg)")
        let alertController = UIAlertController(title: "DataManager Error", message: msg, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler: nil))

        let alertWindow = UIWindow(frame: UIScreen.main.bounds)
        alertWindow.rootViewController = UIViewController()
        alertWindow.windowLevel = UIWindowLevelAlert + 1;
        alertWindow.makeKeyAndVisible()
        alertWindow.rootViewController?.present(alertController, animated: false, completion: nil)
    } //end gotDMError
    
} //end DataManager
