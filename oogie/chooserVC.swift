//
//  chooserVC.swift
//  chooser
//
//  Created by Dave Scruton on 10/30/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//  11/13 add GM instrument name to chooser rows

import UIKit
import Foundation

protocol chooserDelegate
{
    func choseFile(name: String)
    func needToSaveFile(name: String)
}



class chooserVC: UIViewController,UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var table: UITableView!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var saveButton: UIButton!

    var delegate: chooserDelegate?
    var mode = "load"
    
    var filez : [String] = []
    var typez : [Int] = []
    var chosenFile = ""
    var newName = ""
    var chooserFolder = "scenes" //Default to scenes
    var allP = AllPatches.sharedInstance
    //bunch o canned crap for cell content...
    let synthIcon    = UIImage.init(named: "synthIcon")
    let percIcon     = UIImage.init(named: "percIcon")
    let percKitIcon  = UIImage.init(named: "percKitIcon")
    let sampleIcon   = UIImage.init(named: "sampleIcon")
    let userIcon     = UIImage.init(named: "ProfileNOT")
    let synthColor   = UIColor.init(red: 1,    green: 0.94, blue: 0.94, alpha: 1)
    let percColor    = UIColor.init(red: 1,    green: 1,    blue: 0.94, alpha: 1)
    let percKitColor = UIColor.init(red: 0.94, green: 1,    blue: 0.94, alpha: 1)
    let sampleColor  = UIColor.init(red: 0.94, green: 0.94, blue: 1,    alpha: 1)
    let userColor    = UIColor.init(red: 1,    green: 1,    blue: 1,    alpha: 1)
    var carray : [UIColor] = [];
    var iarray : [UIImage] = [];

    
    //---(chooserVC)--------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        //get folder contents...
        //        static func getDirectoryContents(whichDir : String) -> [String]
        typez.removeAll()
        //OUCH! here we should show patch GM instrument name too!
        if mode == "loadAllPatches"   //show user/sunth/perc/perckit/sample folders
        {
            filez.removeAll()
            if allP.yuserPatchDictionary.count > 0  //do we have any user patches?
            {
                filez = Array(allP.yuserPatchDictionary.keys).sorted()
                for _ in 0...allP.yuserPatchDictionary.count-1 {typez.append(5)}
            }
            filez = filez + Array(allP.synthPatchDictionary.keys).sorted()
            for _ in 0...allP.synthPatchDictionary.count-1 {typez.append(1)}
            filez = filez + Array(allP.percussionPatchDictionary.keys).sorted()
            for _ in 0...allP.percussionPatchDictionary.count-1 {typez.append(2)}
            filez = filez + Array(allP.percKitPatchDictionary.keys).sorted()
            for _ in 0...allP.percKitPatchDictionary.count-1 {typez.append(3)}
            //Append GM instrument names
            var aab : [String] = []
            for s in Array(allP.GMPatchDictionary.keys).sorted()
              {
                aab.append(s + ":" + allP.getInstrumentNameFromGMFilename(fname:s))
              }
            filez = filez + aab
            for _ in 0...allP.GMPatchDictionary.count-1 {typez.append(4)}
        }
        else //Sample chooser modes? just get single folder
        {
            filez = DataManager.getDirectoryContents(whichDir: chooserFolder)
            for _ in 0...filez.count-1 {typez.append(4)} //11/13 add sample type
        }
        print("chooser folder \(chooserFolder)")
        saveButton.isHidden = true //NO NEED? (mode == "load")        
        if mode == "loadAllPatches"
        {
            titleLabel.text = "Load Patch..."
            nameText.isHidden = true
        }
        else if mode == "load"
        {
            titleLabel.text = "Load File..."
            nameText.isHidden = true
        }
        else if mode == "save"
        {
            titleLabel.text = "Save File..."
            nameText.becomeFirstResponder()
            nameText.isHidden = false
        }
        nameText.delegate = self
        //Set up bkgd color array for item types
        carray = [synthColor,synthColor,percColor,percKitColor,sampleColor,userColor]
        iarray = [synthIcon!,synthIcon!,percIcon!,percKitIcon!,sampleIcon!,userIcon!]
        
    } //end viewDidLoad

    //---(chooserVC)--------------------------------------
    @IBAction func cancelSelect(_ sender: Any) {
        cancelAndDismiss()
    }
    
    //---(chooserVC)--------------------------------------
    @IBAction func saveSelect(_ sender: Any) {
        //Not used?
    }

    //---(chooserVC)--------------------------------------
    func cancelAndDismiss()
    {
        chosenFile = ""
        dismiss(animated: true, completion: nil)
    }
    
    //---(chooserVC)--------------------------------------
    func promptForReplace()
    {
        print("Replace...")
        let alert = UIAlertController(title: "Replace Existing File?", message: nil, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.delegate?.needToSaveFile(name: self.newName)
            self.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            self.nameText.text = "" //Clear dupe name
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    //---(chooserVC)--------------------------------------
    func handleSave(name : String)
    {
        if (name == "")              //Bail on empty name
        {
            cancelAndDismiss()
        }
        else if filez.contains(name) //Exists? Prompt for replace
        {
            promptForReplace()
        }
        else{                        //New File? Just save
            delegate?.needToSaveFile(name: name)
            dismiss(animated: true, completion: nil)
        }

    } //end handleSave


    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filez.count
    }
 
    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "Cell")
        //print("cell \(indexPath.row) shit \(filez[indexPath.row])")
        cell.textLabel?.text = filez[indexPath.row]
        cell.textLabel?.textColor = .black
        if mode == "loadAllPatches"
        {
            let type = max(0,min(5,typez[indexPath.row]))
            cell.backgroundColor = carray[type] //Canned colors
            cell.imageView?.image = iarray[type] //and icons
        }
        return cell
    }
    
    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chosenFile = filez[indexPath.row]
        if mode == "loadAllPatches"
        {
            let ss = chosenFile.split(separator: ":")//11/13 Compound strings?
            if ss.count == 2  {chosenFile = String(ss[0])} // found one? Choose first part
            delegate?.choseFile(name: chosenFile)
            dismiss(animated: true, completion: nil)
        }
        else if mode == "load"
        {
            delegate?.choseFile(name: chosenFile)
            dismiss(animated: true, completion: nil)
        }
        else if mode == "save"
        {
            handleSave(name: chosenFile) //puts up chooser!
        }
    } //end didSelectRowAt
    
    //---<UITextFieldDelegate>--------------------------------------
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.text = "" //Clear shit out
        return true
    }
    
    //---<UITextFieldDelegate>--------------------------------------
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        newName = textField.text!
        textField.resignFirstResponder() //dismiss kb if up
        handleSave(name: newName)
        return true
    }
    //---<UITextFieldDelegate>--------------------------------------
    @IBAction func textChanged(_ sender: Any) {
        newName = nameText.text!
    }

}
