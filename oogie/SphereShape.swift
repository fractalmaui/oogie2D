//   ____        _                   ____  _
//  / ___| _ __ | |__   ___ _ __ ___/ ___|| |__   __ _ _ __   ___
//  \___ \| '_ \| '_ \ / _ \ '__/ _ \___ \| '_ \ / _` | '_ \ / _ \
//   ___) | |_) | | | |  __/ | |  __/___) | | | | (_| | |_) |  __/
//  |____/| .__/|_| |_|\___|_|  \___|____/|_| |_|\__,_| .__/ \___|
//        |_|                                         |_|
//
//
//  SphereShape.swift
//  oogie2D
//
//  Copyright © 2020 fractallonomy
//
//  10/27 add unHighlight
//  2/3   add 2nd row of test in createNamePlateImage
//  5/7   move shape rotation over to oogieShape
//  5/11  add createMTImage, need in common area w/ oogieShape though
//  10/26 remove VERSION_2D crap
//  11/11 add dice cube, redo init to add uid arg
// 11/13 add menu box, add createPetalImage
//  11/15 add default texture to texCache
//  11/28  in setTextureScaleTranslationAndWrap add wrapS/T support,
//           added getWrapModeFromInt
import SceneKit
 
class SphereShape: SCNNode {
    var rotSpeed: Double = 8.0
    var rotDate = Date()
    var highlighted = false
    var zoomed = false
    var uid = ""
    var key = "" //5/3
    let tc = texCache.sharedInstance //10/21 for loading textures...
    
    //10/11 add torii / box label panels
    var sphere       = SCNSphere()
    var torus1       = SCNTorus()
    var torus2       = SCNTorus()
    var shapeNode    = SCNNode()
    var torusNode1   = SCNNode()
    var torusNode2   = SCNNode()
    var diceCube     = SCNBox()   //11/11
    var diceNode     = SCNNode()
    var isize        = CGSize(width: 256, height: 256) //for menu image
    var menuCube     = SCNBox()   //11/13
    var menuNode     = SCNNode()
    var hueIndicator = SCNNode()

    // 10/26 remove VERSION_2D crap AR only
    let sphereRad    : CGFloat = 0.25
    let sphereCubeStep : CGFloat = 0.05
    let liilcuberad  : CGFloat = 0.04
    let boxSize      : CGFloat = 0.025
    let pipeRad      : CGFloat = 0.01
    //Info box around our shape
    var boxPanel     = SCNBox()
    var panelNodes   : [SCNNode] = [] //4 boxPanel nodes
    var infoLabelTexSize = CGSize(width: 512, height: 64) //overall description image size

    
    //-----------(SphereShape)=============================================
    init(newuid:String)
    {
        super.init()
        uid = newuid; //11/11
        // 10/11 redo to add sphere as child
        sphere = SCNSphere(radius: sphereRad)
        // 10/25
        sphere.firstMaterial?.diffuse.contents  = tc.defaultTexture  //11/15 add default to TC
        sphere.firstMaterial?.emission.contents = tc.defaultTexture  //11/15 add default to TC
        //10/22 try scaling
        if let fm = sphere.firstMaterial
        {
            fm.diffuse.wrapS = .repeat
            fm.diffuse.wrapT = .repeat
            fm.emission.wrapS = .repeat
            fm.emission.wrapT = .repeat
        }

        shapeNode = SCNNode(geometry:sphere)
        shapeNode.name = ""  //9/27 reset name as object gets added...
        self.addChildNode(shapeNode)
        rotDate = Date() //reset start date
        
        //let bs:CGFloat = 0.06
        let yellowM = createPetalImage(label : "M", value : 0, bgcolor: .yellow, fgcolor: .black)
        //11/13 add menu control
        menuCube = SCNBox() //11/3 add dice box on top asdf
        menuCube.firstMaterial?.emission.contents = yellowM
        menuCube.firstMaterial?.diffuse.contents  = yellowM
        menuNode = SCNNode(geometry: menuCube)
        menuNode.position = SCNVector3(0, sphereRad + sphereCubeStep,0)
        menuNode.scale    = SCNVector3(liilcuberad,liilcuberad,liilcuberad) //12/3
        menuNode.name = "menu_" + uid
        self.addChildNode(menuNode)
        
        //11/11 add dice control asdf
        diceCube = SCNBox() //11/3 add dice box on top
        diceCube.firstMaterial?.emission.contents = UIImage(named: "yellowdice")
        diceCube.firstMaterial?.diffuse.contents  = UIImage(named: "yellowdice")
        diceNode = SCNNode(geometry: diceCube)
        diceNode.position = SCNVector3(0, sphereRad + 2*sphereCubeStep,0)
        diceNode.scale    = SCNVector3(liilcuberad,liilcuberad,liilcuberad) //12/3
        diceNode.name = "dice_" + uid
        self.addChildNode(diceNode)

        
        //10/11 add torii to indicate select status
        torus1 = SCNTorus(ringRadius: sphereRad+0.1, pipeRadius: pipeRad)
        torus1.firstMaterial?.emission.contents  = UIColor.white
        torusNode1 = SCNNode(geometry: torus1)
        let torYoff = sphereRad - 0.1
        torusNode1.position = SCNVector3(0,torYoff,0)
        torusNode1.scale    = SCNVector3(0.1,0.1,0.1)
        self.addChildNode(torusNode1)
        torusNode2 = SCNNode(geometry: torus1)
        torusNode2.position = SCNVector3(0,-torYoff,0)
        torusNode2.scale    = SCNVector3(0.1,0.1,0.1)
        self.addChildNode(torusNode2)
        
        //10/11 add box name panels, 4 around marker
        boxPanel = SCNBox(width: 2*boxSize, height:0.2*boxSize , length: 0.001, chamferRadius: 0)
        let ii = createNamePlateImage(label: "..." , comm: "" )
        boxPanel.firstMaterial?.diffuse.contents  = ii
        boxPanel.firstMaterial?.emission.contents = ii

        
        //asdf
        for i in 0...3
        {
            let boxNode = SCNNode(geometry: boxPanel)
            boxNode.position = SCNVector3(0,0,0)
            boxNode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0 , Float(boxSize))
            let pRot = Double(i) * .pi / 2.0
            boxNode.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            self.addChildNode(boxNode)
            panelNodes.append(boxNode)
        }
    } //end init
    
    //-----------(SphereShape)=============================================
    // 9/26 new
    func getNewShapeKey() -> String
    {
       return "shape_" + ProcessInfo.processInfo.globallyUniqueString
    }

    //-----------(SphereShape)=============================================
    // sets angle of 3D shape to follow rotation from oogieShape
    func setAngle(a:Double)
    {
        shapeNode.eulerAngles = SCNVector3Make(0, Float(a), 0)
    }

    //-----------(SphereShape)=============================================
     // black bkgd, long line of name text
    public func createNamePlateImage(label : String , comm: String) -> UIImage {
         UIGraphicsBeginImageContextWithOptions(infoLabelTexSize, false, 1)
         let context = UIGraphicsGetCurrentContext()!
         
         let rect = CGRect(origin: CGPoint.zero, size: infoLabelTexSize)
         //Fill bkgd
         context.setFillColor(UIColor.black.cgColor);
         context.fill(rect);
         
         let thite = 30
         let h2    = infoLabelTexSize.height / 2
         let wid   = infoLabelTexSize.width
         let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(thite-3))!
         let textFont2 = UIFont(name: "Helvetica Bold", size: CGFloat(thite/2))!
         let text_style=NSMutableParagraphStyle()
         text_style.alignment=NSTextAlignment.center
         let text_style2=NSMutableParagraphStyle()
         text_style2.alignment=NSTextAlignment.left

         var xoff : CGFloat = 0
         var yoff : CGFloat = 0
         var textColor = UIColor.black
         let xmargin  : CGFloat = 300 //WTF why doesnt this stretch label?
         let xmargin2 : CGFloat = 40  //2nd row inset
         for _ in 0...1
         {
             var textFontAttributes = [
                 NSAttributedString.Key.font: textFont,
                 NSAttributedString.Key.foregroundColor: textColor,
                 NSAttributedString.Key.paragraphStyle: text_style
                 ] as [NSAttributedString.Key : Any]
             let trect =  CGRect(x: xoff - xmargin, y: yoff + h2-CGFloat(thite)/2.0,
                                 width: wid + 2*xmargin, height: CGFloat(thite))
             label.draw(in: trect, withAttributes: textFontAttributes) //Draw our shape name

             textFontAttributes = [  //2/3 add 2nd row for comment
                NSAttributedString.Key.font: textFont2,
                NSAttributedString.Key.foregroundColor: textColor,
                NSAttributedString.Key.paragraphStyle: text_style2
                ] as [NSAttributedString.Key : Any]
             let trect2 =  CGRect(x: xoff + xmargin2, y: yoff + h2-CGFloat(thite)/2.0 + CGFloat(thite)*0.75,
                                width: wid + 2*xmargin, height: CGFloat(thite))
             comm.draw(in: trect2, withAttributes: textFontAttributes) //add 2nd row, comment
             xoff = xoff - 8 //for top-level label, shifted up for shadow
             yoff = yoff - 8
             textColor = UIColor.white
         }
         
         let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
         UIGraphicsEndImageContext()
         return resultImage
     } //end createNamePlateImage

    
    //-----------(SphereShape)=============================================
    // 11/7 add thumb fallthru, cleanup 11/15, redo logic
    func setBitmap (s : String)
    {
        var tekture = UIImage()
        if s != "default" //non-default? try from cache!
        {
            if let ctek = tc.texDict[s]        {tekture = ctek}
            else if let ctek = tc.thumbDict[s] {tekture = ctek} //11/7 try thumb!
            else {tekture =  createMTImage(name:s)} //11 / 7 cleanup
        }
        else if let ii =  tc.defaultTexture //handle default texture
        {
            tekture = ii
        }
        setBitmapImage(i:tekture)
    }
    
    //=====<oogie2D mainVC>====================================================
    // just puts name in black bigd
    public func createMTImage(name : String) -> UIImage {
        let ww = 512
        let hh = 256
        let isize = CGSize(width: ww, height: hh) //overall image size
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        let rect = CGRect(origin: CGPoint.zero, size: isize)
        context.setFillColor(UIColor.black.cgColor);
        context.fill(rect);
        
        let label = name
        let thite = hh/6
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(thite))!
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
        
        let textColor = UIColor.white
        let xmargin : CGFloat = 300 //WTF why doesnt this stretch label?
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: text_style
            ] as [NSAttributedString.Key : Any]
        let trect =  CGRect(x: -xmargin, y:  CGFloat(hh/2) - CGFloat(thite)/2.0, width: CGFloat(ww) + 2*xmargin, height: CGFloat(thite))
        label.draw(in: trect, withAttributes: textFontAttributes)
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createMTImage


    
    //-----------(SphereShape)=============================================
    // 10/21 support image input
    func setBitmapImage (i : UIImage)
    {
        sphere.firstMaterial?.diffuse.contents  = i
        sphere.firstMaterial?.emission.contents = i
    }
    
    //-----------(SphereShape)=============================================
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    //-----------(SphereShape)=============================================
    func toggleHighlight()
    {
        highlighted = !highlighted
        updateHighlight()
    }
    
    //-----------(SphereShape)=============================================
    func unHighlight()
    {
        highlighted = false
        updateHighlight()
    }
        
    //-----------(SphereShape)=============================================
    // 10/27 support unHighlight, add zoomed double check
    func updateHighlight()
    {
        var tcolor = UIColor.black
        if highlighted
        {
            tcolor = UIColor.white
            if !zoomed {animateSelectOut()}
        }
        else
        {
            if zoomed {animateSelectIn()}
        }
        torus1.firstMaterial?.emission.contents  = tcolor
        torus2.firstMaterial?.emission.contents  = tcolor
    } //end updateHighlight
    
    
    //-----------(SphereShape)=============================================
    func animateSelectOut()
    {
        let scaleAction = SCNAction.scale(by: 10, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        let scaleAction2 = SCNAction.scale(by: 12.0, duration: 0.5)
        for i in 0...3 //10/11 add namepanels
        {
            panelNodes[i].runAction(scaleAction2)
        }
        zoomed = true
    }
    
    
    //-----------(SphereShape)=============================================
    func animateSelectIn()
    {
        let scaleAction = SCNAction.scale(by: 0.1, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        let scaleAction2 = SCNAction.scale(by: 1.0/12.0, duration: 0.5)
        for i in 0...3 //10/11 add namepanels
        {
            panelNodes[i].runAction(scaleAction2)
        }
        zoomed = false
    }

    //-----------(SphereShape)=============================================
    func updatePanels(nameStr : String , comm : String)
    {
        let ii = createNamePlateImage(label: nameStr  , comm: comm)
        boxPanel.firstMaterial?.diffuse.contents = ii
        boxPanel.firstMaterial?.emission.contents = ii
    } //end updatePanels
    
    //-----------(SphereShape)=============================================
    //11/28 new, converts from incoming int format to scene enum
    func getWrapModeFromInt( mode: Int) -> SCNWrapMode
    {
        var result : SCNWrapMode = .repeat
        switch(mode)
        {
        case 0: result = .clamp
        case 1: result = .repeat
        case 2: result = .clampToBorder
        case 3: result = .mirror
        default: result = .repeat
        }
        return result
    } //end getWrapModeFromInt

    //-----------(SphereShape)=============================================
    // incoming wraps are 0..3 , correspond to SCNWrapMode enums 1..4
    // 11/28 add wrap modes...
    func setTextureScaleTranslationAndWrap(xs : Float, ys : Float , xt : Float, yt : Float, ws : Int , wt : Int)
    {
        if let fm = sphere.firstMaterial
        {
            let scale       = SCNMatrix4MakeScale(xs, ys, 0)
            let translation = SCNMatrix4MakeTranslation(xt, yt, 0)
            let transform   = SCNMatrix4Mult(scale,translation)
            //11/16 MEMORY LEAK HERE TOO!!! OUCH!
            fm.diffuse.contentsTransform  = transform
            fm.emission.contentsTransform = transform
            //print("xys:\(xs),\(ys) wrapST:\(ws),\(wt)")
            let wrs : SCNWrapMode = getWrapModeFromInt(mode:ws)
            let wrt : SCNWrapMode = getWrapModeFromInt(mode:wt)
            fm.diffuse.wrapS  = wrs //11/28 add wrap S/T
            fm.emission.wrapS = wrs
            fm.diffuse.wrapT  = wrt
            fm.emission.wrapT = wrt
        }
    } //end setTextureScaleTranslationAndWrap
    
    //-----------(SphereShape)=============================================
    func spin(r : Double)
    {
        print("spin STUBBED \(r)")
//        let action = SCNAction.rotate(by: 360 * CGFloat(Double.pi / 180), around: SCNVector3(x:0, y:1, z:0), duration: r)
//        //now sphere only rotates...
//        let repeatAction = SCNAction.repeatForever(action)
//        shapeNode.runAction(repeatAction)
    }
    
    //-----------(ScalarShape)=============================================
    func animateDiceSelect()
    {
        animateBoxSelect(sn:diceNode)
    }
    
    //-----------(ScalarShape)=============================================
    // 11/13 new
    func animateMenuSelect()
    {
        animateBoxSelect(sn:menuNode)
    }
    
    //-----------(ScalarShape)=============================================
    // 11/13 rename
    func animateBoxSelect(sn:SCNNode)
    {
        var zoom = 2.0
        let scaleAction1 = SCNAction.scale(by: zoom, duration: 0.05)
        let scaleAction2 = SCNAction.scale(by: 1.0 / zoom, duration: 0.8)
        let sequence = SCNAction.sequence([scaleAction1, scaleAction2])
        sn.runAction(sequence, completionHandler:nil)

        zoom = zoom * 5.0  //bigger oom for torus
        let scaleAction11 = SCNAction.scale(by: zoom, duration: 0.05)
        let scaleAction12 = SCNAction.scale(by: 1.0 / zoom, duration: 0.8)
        let sequence2 = SCNAction.sequence([scaleAction11, scaleAction12])
        torusNode1.runAction(sequence2)
        torusNode2.runAction(sequence2)
    } //end animateBoxSelect

    
    //-------(Marker)-------------------------------------
    // 11/13 copy in from marker for menu box...
    public func createPetalImage(label : String, value : Int, bgcolor: UIColor, fgcolor: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        
        var rect = CGRect(origin: CGPoint.zero, size: isize)
        //Fill bkgd
        fgcolor.setFill()
        context.setFillColor(bgcolor.cgColor); //11/13
        context.fill(rect);
        
        let ihit = isize.height
        let barhite = Int( CGFloat(value) * CGFloat(ihit) / 255.0)
        context.setFillColor(fgcolor.cgColor);
        rect = CGRect(x: 0, y: Int(ihit)-barhite, width: Int(ihit), height: barhite)
        context.fill(rect);
        
        context.setFillColor(UIColor.white.cgColor);
        for y in 0...4
        {
            let yy = y * Int(ihit-4) / 4
            let lrect = CGRect(x: 0, y: yy, width: Int(ihit), height: 4)
            context.fill(lrect);
        }
        
        let thite = 160
        let h2    = isize.height / 2
        let wid   = isize.width
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(thite))!
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
        
        var xoff : CGFloat = 0
        var yoff : CGFloat = 0
        var textColor = UIColor.black
        let xmargin : CGFloat = 300 //WTF why doesnt this stretch label?
        for _ in 0...1
        {
            let textFontAttributes = [
                NSAttributedString.Key.font: textFont,
                NSAttributedString.Key.foregroundColor: textColor,
                NSAttributedString.Key.paragraphStyle: text_style
                ] as [NSAttributedString.Key : Any]
            let trect =  CGRect(x: xoff - xmargin, y: yoff + h2-CGFloat(thite)/2.0, width: wid + 2*xmargin, height: CGFloat(thite))
            label.draw(in: trect, withAttributes: textFontAttributes)
            xoff = xoff - 8 //for top-level label, shifted up for shadow
            yoff = yoff - 8
            textColor = fgcolor
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createPetalImage

    
}
