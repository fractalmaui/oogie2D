//
//  chooserVC.swift
//  chooser
//
//  Created by Dave Scruton on 10/30/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//

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
    var chosenFile = ""
    var newName = ""

    //---(chooserVC)--------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        //get folder contents...
        filez = DataManager.getSceneDirectoryContents()
        saveButton.isHidden = true //NO NEED? (mode == "load")
        if mode == "load"
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

    }

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
        cell.textLabel?.text = filez[indexPath.row]
        return cell
    }
    
    //---<UITableViewDelegate>--------------------------------------
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chosenFile = filez[indexPath.row]
        if mode == "load"
        {
            delegate?.choseFile(name: chosenFile)
            dismiss(animated: true, completion: nil)
        }
        else if mode == "save"
        {
            handleSave(name: chosenFile)
        }
    }
    
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
