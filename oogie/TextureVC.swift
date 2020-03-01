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

import Foundation
import UIKit
import Photos

protocol TextureVCDelegate
{
    func gotTexture(name: String, tex: UIImage)
    func cancelled()
}


class TextureVC: UIViewController,UICollectionViewDataSource,
    UICollectionViewDelegate,UICollectionViewDelegateFlowLayout,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate
{

    var delegate: TextureVCDelegate?

    var textures : [UIImage] = []
    var texnames : [String]  = []

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    let tc = texCache.sharedInstance  
    var oldIndexPath : (IndexPath) = IndexPath.init()
    var selectedRow  = 0
    var defaultCount = 0
    
    var imagePicker = UIImagePickerController()
    

    //======(TextureVC)=================================================
    override func viewDidLoad() {
        loadImages()
        minusButton.isHidden = true
    }

    //======(TextureVC)=================================================
    func loadImages()
    {
        //load builtins first
        //10/25 test pattern support
        #if USE_TESTPATTERN
        let ifname = "tp"
        #else
        let ifname = "oog2-stripey00t"
        #endif
        textures.append(UIImage(named: ifname)!)
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
        delegate?.cancelled()

    }
    
    //====<UICollectionViewDelegate>===============================================
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return textures.count
    }
    
    //====<UICollectionViewDelegate>==================================
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //print("select \(indexPath)")
        selectedRow = indexPath.row
        minusButton.isHidden = (selectedRow < defaultCount)
        //unhilight...
        var cell = collectionView.cellForItem(at: oldIndexPath)
        cell?.layer.borderWidth = 2.0
        cell?.layer.borderColor = UIColor.black.cgColor
        //hilight
        cell = collectionView.cellForItem(at: indexPath)
        cell?.layer.borderWidth = 6.0
        cell?.layer.borderColor = UIColor.black.cgColor
        oldIndexPath = indexPath
        delegate?.gotTexture(name: texnames[selectedRow], tex: textures[selectedRow])
        dismiss(animated: true, completion: nil)
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
//        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage
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
                }
            }
        }
        else
        {
            print("there was an error choosing the image")
        }
        self.dismiss(animated: true, completion: nil)
        
    }
    
    
    
    
    
}


