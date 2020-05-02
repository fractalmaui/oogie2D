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
//  Copyright © 2019 fractallonomy
//
//  Need to add timer reset every animation period!
//  10/21 support image input
//  10/24 add #if to set object size,adjust rot speed
//  10/27 add unHighlight
//  2/3   add 2nd row of test in createNamePlateImage
import SceneKit

class SphereShape: SCNNode {
    var rotSpeed: Double = 8.0
    var rotDate = Date()
    var highlighted = false
    var zoomed = false
    var uid = ""
    let tc = texCache.sharedInstance //10/21 for loading textures...

    
    #if USE_TESTPATTERN
    let defaultTexture = "tp"
    #else
    let defaultTexture = "oog2-stripey00t"
    #endif

    //10/25 first 2 vars come from scene ? global settings?
    var fps = 30
    var bpm = 135
    var angle  : Double = 0.0 //Rotation angle
    var dangle : Double = 0.0 //incremental angle
    var sTimer = Timer()

    //10/11 add torii / box label panels
    var sphere       = SCNSphere()
    var torus1       = SCNTorus()
    var torus2       = SCNTorus()
    var shapeNode    = SCNNode()
    var torusNode1   = SCNNode()
    var torusNode2   = SCNNode()
    //see this about setting compiler switches, also use in mainVC for marker placement
    //   and for use of startPosition in AR version
    #if VERSION_2D
    let sphereRad    : CGFloat = 1.0
    let boxSize      : CGFloat = 0.1
    let pipeRad      : CGFloat = 0.04
    #elseif VERSION_AR
    let sphereRad    : CGFloat = 0.25
    let boxSize      : CGFloat = 0.025
    let pipeRad      : CGFloat = 0.01
    #endif

    var boxPanel     = SCNBox()
    var panelNodes   : [SCNNode] = []
    var jsize = CGSize(width: 512, height: 32) //overall description image size
    var bmp = oogieBmp() //10/21 bmp used for color gathering

    
    //-----------(SphereShape)=============================================
    override init() {
        super.init()
        // 10/11 redo to add sphere as child
        sphere = SCNSphere(radius: sphereRad)
        // 10/25
        sphere.firstMaterial?.diffuse.contents  = UIImage(named: defaultTexture)
        sphere.firstMaterial?.emission.contents = UIImage(named: defaultTexture)
        //10/22 try scaling
        if let fm = sphere.firstMaterial
        {
            fm.diffuse.wrapS = .repeat
            fm.diffuse.wrapT = .repeat
            fm.emission.wrapS = .repeat
            fm.emission.wrapT = .repeat
        }

        shapeNode = SCNNode(geometry:sphere)
        //10/11 add name for touch ID
        uid = "shape_" + ProcessInfo.processInfo.globallyUniqueString
        shapeNode.name = uid

        self.addChildNode(shapeNode)
        rotDate = Date() //reset start date
        
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
        
        setupTimer(rs: rotSpeed)
    } //end init
    
    //-----------(SphereShape)=============================================
    // 10/25
    func setTimerSpeed(rs : Double)
    {
        rotSpeed = rs
        dangle = (2.0 * Double.pi) / (Double(fps) * rotSpeed)
    }
    
    //-----------(SphereShape)=============================================
    // 10/25
    func setupTimer(rs : Double)
    {
        //print("setup Timer Rate \(rs) for shape  \(uid)")
        sTimer.invalidate()
        setTimerSpeed(rs:rs)
        let tstep = 1.0 / Double(fps)
        sTimer = Timer.scheduledTimer(timeInterval: tstep, target: self, selector: #selector(self.advanceRotation), userInfo:  nil, repeats: true)
    }
    
    //-----------(SphereShape)=============================================
    @objc func advanceRotation()
    {
       // pLabel.fadeOut()
        angle += dangle
      //  print("rot: \(angle)")
        shapeNode.eulerAngles = SCNVector3Make(0, Float(angle), 0)

    }
    
    //-----------(SphereShape)=============================================
     // black bkgd, long line of name text
    public func createNamePlateImage(label : String , comm: String) -> UIImage {
         UIGraphicsBeginImageContextWithOptions(jsize, false, 1)
         let context = UIGraphicsGetCurrentContext()!
         
         let rect = CGRect(origin: CGPoint.zero, size: jsize)
         //Fill bkgd
         context.setFillColor(UIColor.black.cgColor);
         context.fill(rect);
         
         let thite = 30
         let h2    = jsize.height / 2
         let wid   = jsize.width
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
    // 9/2 add default support
    func setBitmap (s : String)
    {
        let tekture = UIImage(named: defaultTexture)
        if s != "default" //non-default? try from cache!
        {
            if let ctek = tc.texDict[s]
            {
                setBitmapImage(i:ctek)
                return
            }
            else {
                print("error fetching texture \(s)")
            }
        }
        setBitmapImage(i:tekture!)
    }
    
    //-----------(SphereShape)=============================================
    // 10/21 support image input
    func setBitmapImage (i : UIImage)
    {
        sphere.firstMaterial?.diffuse.contents  = i
        sphere.firstMaterial?.emission.contents = i
        bmp.setupImage(i: i) //also set up data gathering bitmap area
    }
    
    //-----------(SphereShape)=============================================
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //-----------(SphereShape)=============================================
    // May not be accurate...? assumes runAction produces a clock that is correct
    //  returns radian angle
    func getOLDAngle () -> Double
    {
//This just doesn't work, rotation axis changes at least 2X!
//        let rotation3 = self.eulerAngles
//        var yrot = Double(rotation3.y)
        let curDate = Date()
        let dd = curDate.timeIntervalSince(rotDate)
        //8 second rotational time performed by SCNAction, is it accurate?
        //  its likely it will wander, curDate needs to be synced periodically
        //  with the animation start!
        var yrot = (dd / rotSpeed) * 2.0 * Double.pi //Radians?
        yrot = yrot - Double.pi*0.5
        //let degrees = Int(yrot * 180.0 / Double.pi)
        //print(degrees % 36)
        return yrot
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
    func setTextureScaleAndTranslation(xs : Float, ys : Float , xt : Float, yt : Float)
    {
        if let fm = sphere.firstMaterial
        {
            let scale = SCNMatrix4MakeScale(xs, ys, 0)
            let translation = SCNMatrix4MakeTranslation(xt, yt, 0)
            let transform = SCNMatrix4Mult(scale,translation)
            fm.diffuse.contentsTransform  = transform
            fm.emission.contentsTransform = transform
        }

    }
    
    //-----------(SphereShape)=============================================
    func spin(r : Double)
    {
        print("spin STUBBED \(r)")
//        let action = SCNAction.rotate(by: 360 * CGFloat(Double.pi / 180), around: SCNVector3(x:0, y:1, z:0), duration: r)
//        //now sphere only rotates...
//        let repeatAction = SCNAction.repeatForever(action)
//        shapeNode.runAction(repeatAction)
    }
    
}
