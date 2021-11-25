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

    var textures : [UIImage] = []
    var texnames : [String]  = []
    
    var ieVC = imageEditVC()
    
    var selectedImageName = ""

    @IBOutlet weak var titleLabel: UILabel!
    
    //@IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    let tc = texCache.sharedInstance  
    var oldIndexPath : (IndexPath) = IndexPath.init()
    var selectedRow  = 0
    var defaultCount = 0
    
    var imagePicker = UIImagePickerController()
    

    //======(TextureVC)=================================================
    override func viewDidLoad() {
        loadImages()
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
        ieVC.delegate = self //11/15
    }
    
    //======(TextureVC)=================================================
    func functionsMenu(row:Int)
    {
        let fname = texnames[row]
        //        {
        let alert = UIAlertController(title: fname, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.view.tintColor = UIColor.black //2/6 black text
        alert.addAction(UIAlertAction(title: "Delete Texture", style: .default, handler: { action in
            self.deleteTexture(fname:fname)
        }))
        alert.addAction(UIAlertAction(title: "Edit Texture...", style: .default, handler: { action in
            self.editTexture(fname:fname)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
        }))
        self.present(alert, animated: true, completion: nil)
        
        //        }
    } //end functionsMenu
    
    
    //=====<oogie2D mainVC>====================================================
    // Texture Segue called just above... get textureVC handle here...
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.identifier == "imageEditVCSegue" {
            if let nextViewController = segue.destination as? imageEditVC {
                var ii = tc.defaultTexture
                if texnames[selectedRow] != "default" { ii = tc.texDict[texnames[selectedRow]] }
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
        texnames.remove(at: selectedRow)
        textures.remove(at: selectedRow)
        collectionView.reloadData()
    }

    //======(TextureVC)=================================================
    func editTexture(fname:String)
    {
        self.performSegue(withIdentifier: "imageEditVCSegue", sender: self) //10/24

    }

    //======(TextureVC)=================================================
    func loadImages()
    {
        //load builtins first
        //10/25 test pattern support
        if let ii = tc.defaultTexture  { textures.append(ii) } //11/15 add default to TC
        texnames.append("default")
        defaultCount = 1
        
        //Loop over texture cache
        for (name, texture) in tc.texDict
        {
            addImageToArrays(image: texture, name: name)
        }
        
    }
    
    //======(TextureVC)=================================================
    func addImageToArrays(image : UIImage , name : String)
    {
        textures.append(image)
        texnames.append(name)
    } //end addImageToArrays
    
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
        let tname = texnames[selectedRow]
        tc.deleteTextureCompletely(name:tname)
        //remove from local storage
        texnames.remove(at: selectedRow)
        textures.remove(at: selectedRow)
        collectionView.reloadData()
    }

    //======(TextureVC)=================================================
    @IBAction func dismissSelect(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        delegate?.cancelledTextures()

    }
    
    //====<UICollectionViewDelegate>===============================================
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return textures.count
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
        cell.texLabel.text  = texnames[row]
        cell.texImage.image = textures[row]
        
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
                    addImageToArrays(image: image, name: iname)
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
        let newName = texnames[selectedRow] + "0"
        tc.addImage(fileName: newName, image: i) //save new texture!
        addImageToArrays(image: i, name: newName)
        collectionView.reloadData()
        infoAlert(title:"Added new texture" , message : "edited and saved as:" + newName)
    } //end didEdit
 
} //end of TextureVC class


