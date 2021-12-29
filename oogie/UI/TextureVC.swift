//   _____         _                __     ______
//  |_   _|____  _| |_ _   _ _ __ __\ \   / / ___|
//    | |/ _ \ \/ / __| | | | '__/ _ \ \ / / |
//    | |  __/>  <| |_| |_| | | |  __/\ V /| |___
//    |_|\___/_/\_\\__|\__,_|_|  \___| \_/  \____|
//
//  TextureVC.swift
//  oogie2D
//
//  Created by Dave Scruton on 9/6/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//  2/6 use edited image from chooser, get auth early in plusSelect
//  11/13 redo look to match samplesVC
//  11/15 add textureDefault to texCache
//  12/15 add header, sort panel, sorting
//  12/17 hide edit button, what does it do?
import Foundation
import UIKit
import Photos

protocol TextureVCDelegate
{
    func gotTexture(name: String, tex: UIImage)
    func deletedTexture(name: String)
    func cancelledTextures()
}


class TextureVC: UIViewController,UICollectionViewDataSource,
    UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate , imageEditVCDelegate
{

    var delegate: TextureVCDelegate?
    
    var ieVC = imageEditVC()
    
    var selectedImageName = ""

    @IBOutlet weak var titleLabel: UILabel!
    
    //@IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var headerView: UIView!
    
    @IBOutlet weak var sortView: UIView!
    
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    
    @IBOutlet weak var sortNamButton: UIButton!
    @IBOutlet weak var sortDateButton: UIButton!
    @IBOutlet weak var sortDirButton: UIButton!
    
    let tc = texCache.sharedInstance  
    var oldIndexPath : (IndexPath) = IndexPath.init()
    var selectedRow  = 0
    var defaultCount = 0
    
    var sortMode = 0  // alpha date
    
    let upArrow = UIImage(named:"arrowUp")
    let dnArrow = UIImage(named:"arrowDown")
    
    var keysSortedByDate = [String]() //12/16 these come in presorted from cache
    var keysSortedByName = [String]()
    var keyCount = 0
    var sortDir = 0  //0 normal 1 reverse?
    var keysSortedProperly = [String]()
    let emptyImage = UIImage(named: "empty64")
    var imagePicker = UIImagePickerController()
    
    let deepPurple = UIColor(red: 0.0, green: 0, blue: 0.25, alpha: 1)

    //======(TextureVC)=================================================
    override func viewDidLoad() {
        //loadImages()
        

        //minusButton.isHidden = true
        let xmargin :CGFloat = 20.0
        let borderWid :CGFloat = 5.0
        let borderColor:UIColor = .white
        doneButton.layer.cornerRadius = xmargin*0.5  //11/13
        doneButton.layer.cornerRadius = xmargin;
        doneButton.clipsToBounds      = true;
        doneButton.layer.borderWidth  = borderWid;
        doneButton.layer.borderColor  = borderColor.cgColor;

        addButton.layer.cornerRadius = xmargin*0.5  //11/13
        addButton.layer.cornerRadius = xmargin;
        addButton.clipsToBounds      = true;
        addButton.layer.borderWidth  = borderWid;
        addButton.layer.borderColor  = borderColor.cgColor;

        editButton.layer.cornerRadius = xmargin*0.5  //11/13
        editButton.layer.cornerRadius = xmargin;
        editButton.clipsToBounds      = true;
        editButton.layer.borderWidth  = borderWid;
        editButton.layer.borderColor  = borderColor.cgColor;
        editButton.isHidden           = true;  //12/17 hide edit button, what does it do?

        sortDirButton.setTitle("", for: .normal) //WTF? why does this say button?
        
        ieVC.delegate = self //11/15
        
        getFreshlySortedKeys()
    }
    
    //======(TextureVC)=================================================
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //add color grad to header
        let g = CAGradientLayer()
        g.frame = headerView.bounds
        g.colors = [UIColor.black.cgColor,deepPurple.cgColor]  //top black, bottom purpledelete
        headerView.layer.insertSublayer(g, at: 0)

        sortView.backgroundColor = deepPurple //12/17
        
        updateSortButtonColors()
        updateSortDirButton()

    }

    //======(TextureVC)=================================================
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    //======(TextureVC)=================================================
    @IBAction func sortByNameSelect(_ sender: Any) {
        sortMode = 0
        updateSortButtonColors()
        collectionView.reloadData()
    }
    
    //======(TextureVC)=================================================
    @IBAction func sortByDateSelect(_ sender: Any) {
        sortMode = 1
        updateSortButtonColors()
        collectionView.reloadData()
    }
    
    //======(TextureVC)=================================================
    @IBAction func sortDirSelect(_ sender: Any) {
        if sortDir == 0 {sortDir = 1} //toggle
        else            {sortDir = 0}
        updateSortDirButton()
        collectionView.reloadData()
    }

    //======(TextureVC)=================================================
    func functionsMenu(row:Int)
    {
        let fname = keysSortedProperly[row]
        let alert = UIAlertController(title: fname, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        //12/19 test for dark mode    alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Texture", style: .default, handler: { action in
            self.deleteTexture(fname:fname)
        }))
        alert.addAction(UIAlertAction(title: "Edit Texture...", style: .default, handler: { action in
            self.editTexture(fname:fname)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    } //end functionsMenu
    
    
    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.identifier == "imageEditVCSegue" {
            if let nextViewController = segue.destination as? imageEditVC {
                var ii = tc.defaultTexture
                ii = tc.texDict[keysSortedProperly[selectedRow]]
                nextViewController.image2edit = ii;
                nextViewController.delegate   = self //11/15 just in case
            }
        }
    } //end prepareForSegue


    //======(TextureVC)=================================================
    func deleteTexture(fname:String)
    {
        if ["default","grads000"].contains(fname) //cant remove defaults
        {
            infoAlert(title:"Cannot delete default texture" , message : fname)
            return
        }
        tc.deleteTextureCompletely(name: fname)
        delegate?.deletedTexture(name: fname)        
        //clean up local storage, reload...
        getFreshlySortedKeys()
        collectionView.reloadData()
    }

    //======(TextureVC)=================================================
    func editTexture(fname:String)
    {
        self.performSegue(withIdentifier: "imageEditVCSegue", sender: self) //10/24

    }

    //======(TextureVC)=================================================
    @IBAction func plusSelect(_ sender: Any) {
        
        //2/6 try getting auth early...
        PHPhotoLibrary.requestAuthorization { status in
            //just do nothing...
        }
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.mediaTypes = ["public.image", "public.movie"]
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker,animated:false,completion:nil)
    }  //end plusSelect

    
    @IBAction func editSelect(_ sender: Any)
    {
        print("Brinb up ieditor")
        
    }
    
    //======(TextureVC)=================================================
    @IBAction func minusSelect(_ sender: Any) {
        let tname = keysSortedProperly[selectedRow]
        tc.deleteTextureCompletely(name:tname)
        getFreshlySortedKeys()
        collectionView.reloadData()
    }

    //======(TextureVC)=================================================
    @IBAction func dismissSelect(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        delegate?.cancelledTextures()
    }
    
    //======(TextureVC)=================================================
    func getFreshlySortedKeys()
    {
        keysSortedByDate = tc.keysSortedByDate()
        keysSortedByName = tc.keysSortedByAlpha()
        keyCount = keysSortedByName.count
        keysSortedProperly = keysSortedByName //this will change on refresh
    }

    //======(TextureVC)=================================================
    func updateSortDirButton()
    {
        var ii = dnArrow
        if sortDir == 1 {ii = upArrow}
        sortDirButton.setImage(ii, for: .normal)
    }
    
    //======(TextureVC)=================================================
    func updateSortButtonColors()
    {
        if sortMode == 1
        {
            sortNamButton.backgroundColor  = UIColor.darkGray
            sortDateButton.backgroundColor = UIColor.blue
        }
        else
        {
            sortNamButton.backgroundColor  = UIColor.blue
            sortDateButton.backgroundColor = UIColor.darkGray
        }
    } //end updateSortButtonColors
    
    //====<UICollectionViewDelegate>===============================================
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return keyCount //textures.count
    }
    
    //====<UICollectionViewDelegate>==================================
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //print("select \(indexPath)")
        selectedRow = indexPath.row
        //minusButton.isHidden = (selectedRow < defaultCount)
        //unhilight...
        var cell = collectionView.cellForItem(at: oldIndexPath)
        cell?.layer.borderWidth = 2.0
        cell?.layer.borderColor = UIColor.black.cgColor
        //hilight
        cell = collectionView.cellForItem(at: indexPath)
        cell?.layer.borderWidth = 6.0
        cell?.layer.borderColor = UIColor.black.cgColor
        oldIndexPath = indexPath
        
        functionsMenu(row:indexPath.row) //prompt for functions...
    }
    
    //====<UICollectionViewDelegate>==================================
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath as IndexPath) as! TextureCell
        let row = indexPath.row
        
        //12/16 handle sorting options...
        
        var texName = ""
        let rrow = max(0,keyCount - row - 1)
        if keyCount > 0
        {
            switch(sortMode)
            {
            case 0: //alpha
                if sortDir == 0 { texName = keysSortedByName[row] }
                else            { texName = keysSortedByName[rrow]}
            case 1: //date
                if sortDir == 0 { texName = keysSortedByDate[row] }
                else            { texName = keysSortedByDate[rrow]}
            default: texName = ""
            }
        } //end keycount
        //print("...row \(row) name \(texName)")
        keysSortedProperly[row] = texName //for picking stuff
        cell.texLabel.text = texName
        if let ii = tc.texDict[texName]
            {cell.texImage.image = ii}
        else
            {cell.texImage.image = emptyImage}

        cell.layer.borderWidth = 1
        cell.layer.cornerRadius = 8
        
        return cell
    }
    
  //====<UICollectionViewDelegateFlowLayout>=========================
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width: 96, height: 96)
    }
    
    
    //==========<UIImagePickerControllerDelegate>========================
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //==========<UIImagePickerControllerDelegate>========================
    // Problem? I want to add edited image:
    //          self->_photo = (UIImage *)[info objectForKey:UIImagePickerControllerEditedImage];
    // However this is making a local copy of the image (NOT edited!), WTF?
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage //2/6 test?
        {
            if let imageURL = info[UIImagePickerControllerReferenceURL] as? URL {
                let result = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                let asset = result.firstObject
                if let iname = asset?.value(forKey: "filename") as? String
                {
                    tc.addImage(fileName: iname, image: image)
                    //addImageToArrays(image: image, name: iname)
                    getFreshlySortedKeys()
                    self.collectionView.reloadData()
                    delegate?.gotTexture(name: iname, tex: image) //11/16 notify parent
                }
            }
        }
        else
        {
            print("there was an error choosing the image")
        }
        self.dismiss(animated: true, completion: nil)        
   } // end of didFinishPickingMediaWithInfo?? 10/7/21
    
    
    //=====<oogie2D mainVC>====================================================
    func infoAlert(title:String , message : String)
    {
        let alert = UIAlertController(title: title, message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    //---------<imageEditVCDelegate>------------------------------------------------
    // hmmm need different method name?
    func didEdit(_ i: UIImage!) {
        let newName = keysSortedProperly[selectedRow] + "0"
        tc.addImage(fileName: newName, image: i) //save new texture!
        getFreshlySortedKeys()
        collectionView.reloadData()
        infoAlert(title:"Added new texture" , message : "edited and saved as:" + newName)
    } //end didEdit
 
} //end of TextureVC class


