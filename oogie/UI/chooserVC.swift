//        _                             __     ______
//    ___| |__   ___   ___  ___  ___ _ _\ \   / / ___|
//   / __| '_ \ / _ \ / _ \/ __|/ _ \ '__\ \ / / |
//  | (__| | | | (_) | (_) \__ \  __/ |   \ V /| |___
//   \___|_| |_|\___/ \___/|___/\___|_|    \_/  \____|
//
//  chooserVC.swift
//  Oogie2D
//
//  Created by Dave Scruton on 10/30/19.
//  Copyright © 2020 fractallonomy. All rights reserved.
//  9/18/21 complete redo
//  9/28    fix saveas file display

import UIKit
import Foundation

protocol chooserDelegate
{
    func newFolderContents(c: [String])
    func chooserChoseFile(name: String)
    func chooserCancelled()
    func needToSaveFile(name: String)
}



class chooserVC: UIViewController,UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var table: UITableView!
    @IBOutlet weak var table2: UITableView!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var saveButton: UIButton!

    var delegate: chooserDelegate?
    let chooserLoadSceneMode   = "loadScene"
    // 9/28 NOTE saveScene is unneeded, chooser never comes up in that mode
    let chooserSaveSceneMode   = "saveScene"
    let chooserSaveSceneAsMode = "saveSceneAs"
    let chooserLoadPatchMode   = "loadPatch"
    let chooserSavePatchMode   = "savePatch"
    let chooserSavePatchAsMode = "savePatchAs"

    var mode = ""
    let cellHeight = 40 //should be large enuf for one line of text
    
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
        table.delegate    = self
        table.dataSource  = self
        table2.delegate   = self
        table2.dataSource = self
        typez.removeAll()
        //print("viewDidLoad: chooser  mode \(mode)")
        saveButton.isHidden = true //NO NEED? (mode == "load")
        if mode == chooserLoadPatchMode
        {
            titleLabel.text = "Load Patch..."
            nameText.isHidden = true
        }
        else if mode == chooserLoadSceneMode
        {
            titleLabel.text = "Load Scene..."
            nameText.isHidden = true
        }
        else if mode == chooserSaveSceneAsMode
        {
            titleLabel.text = "Save Scene As..."
            nameText.isHidden = false
        }
        else if mode == chooserSavePatchAsMode
        {
            titleLabel.text = "Save Patch As..."
            nameText.isHidden = false
        }
        nameText.delegate = self
        //Set up bkgd color array for item types
        carray = [synthColor,synthColor,percColor,percKitColor,sampleColor,userColor]
        iarray = [synthIcon!,synthIcon!,percIcon!,percKitIcon!,sampleIcon!,userIcon!]
        
        //make tables light green / blue
        table.backgroundColor  = UIColor(red: 0.85, green: 1.0, blue: 0.9, alpha: 1)
        table2.backgroundColor = UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1)

        let twoColumns  = (filez.count > 20)
        table.isHidden  = false
        table2.isHidden = !twoColumns
        //11/28 add 2nd table2 for large folders, scrolled 1/2 way down
        if twoColumns
        {
            let ip     = IndexPath(item: filez.count/2, section: 0)
            //12/27 arg1 sets position, arg2 is where in screen row goes
            table2.scrollToRow(at: ip ,  at: .middle, animated: false)
        }
    } //end viewDidLoad
    
    //---(chooserVC)--------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //print("chooserwillappear, mode \(mode)")
        getFolderContents()
        configureView()
    }

    //---(chooserVC)--------------------------------------
    @IBAction func cancelSelect(_ sender: Any) {
        //pass list of patches to delegate
        self.delegate?.newFolderContents(c: filez)
        cancelAndDismiss()
    }
    
    //---(chooserVC)--------------------------------------
    @IBAction func saveSelect(_ sender: Any) {
        //Not used?
    }

    //---(chooserVC)--------------------------------------
    // 9/28 update for whatever mode we are in
    func configureView()
    {
        saveButton.isHidden = true //NO NEED? (mode == "load")
        if mode == chooserLoadPatchMode
        {
            titleLabel.text = "Load Patch..."
            nameText.isHidden = true
        }
        else if mode == chooserLoadSceneMode
        {
            titleLabel.text = "Load Scene..."
            nameText.isHidden = true
        }
        else if mode == chooserSaveSceneAsMode
        {
            titleLabel.text = "Save Scene As..."
            nameText.isHidden = false
        }
        else if mode == chooserSavePatchAsMode
        {
            titleLabel.text = "Save Patch As..."
            nameText.isHidden = false
        }

    }
    

    //---(chooserVC)--------------------------------------
    func cancelAndDismiss()
    {
        chosenFile = ""
        delegate?.chooserCancelled()
        dismiss(animated: true, completion: nil)
    }
    
    //---(chooserVC)--------------------------------------
    // 10/18 KRASH here if scenes folder is missing! WTF?
    func getFolderContents()
    {
        if mode == chooserLoadSceneMode || mode == chooserSaveSceneAsMode
        {
            filez = DataManager.getDirectoryContents(whichDir: "scenes")
        }
        if mode == chooserLoadPatchMode || mode == chooserSavePatchAsMode
        {
            filez = DataManager.getDirectoryContents(whichDir: "patches")
        }
        //20/21 duh sort it or what
        filez = filez.sorted()
        //print("chooser filez  \(filez)")

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
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(cellHeight)
    }
 
    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "Cell")
        //print("cell \(indexPath.row) txt \(filez[indexPath.row])")
        cell.textLabel?.text = filez[indexPath.row]
        if mode == "loadAllPatches"
        {
            let type = max(0,min(5,typez[indexPath.row]))
            cell.backgroundColor = .clear  //11/28 wtf cell shows up gray udderwise!
            cell.imageView?.image = iarray[type] //and icons
        }
        else
        {
            cell.backgroundColor = .clear
        }
        return cell
    } //end cellForRowAt...
    
    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chosenFile = filez[indexPath.row]
        if mode == chooserLoadPatchMode
        {
            let ss = chosenFile.split(separator: ":")//11/13 Compound strings?
            if ss.count == 2  {chosenFile = String(ss[0])} // found one? Choose first part
            delegate?.chooserChoseFile(name: chosenFile)
            dismiss(animated: true, completion: nil)
        }
        else if mode == chooserLoadSceneMode
        {
            delegate?.chooserChoseFile(name: chosenFile)
            dismiss(animated: true, completion: nil)
        }
        else if mode == chooserSaveSceneAsMode
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
