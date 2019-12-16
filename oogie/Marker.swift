//   __  __            _
//  |  \/  | __ _ _ __| | _____ _ __
//  | |\/| |/ _` | '__| |/ / _ \ '__|
//  | |  | | (_| | |  |   <  __/ |
//  |_|  |_|\__,_|_|  |_|\_\___|_|
//
//  Marker.swift
//  oogie
//
//  Created by Dave Scruton on 7/19/19.
//
//  9/3 add new marker model with complex textured stuff
//  9/6 add xparent sphere around entire marker for hittesting
//  9/30 add torus animate on highlight
//  10/11 add nameplates
//  10/27 add unHighlight
//  10/29 add updateTypeInt to support scene creation
//  11/17 move lat/lon rotation handles here
//  11/18 add updateRGBValues, separate data from display methods
//         data is updated in bkgd while UI is updated in foreground
//         
//  Try to animate torus on select / deselect:
//   https://developer.apple.com/documentation/scenekit/animation/animating_scenekit_content
import UIKit
import Foundation
import SceneKit

class Marker: SCNNode {
    
    var isize = CGSize(width: 256, height: 256) //overall petal image size
    var jsize = CGSize(width: 512, height: 32) //overall petal image size
    var petals : [SCNBox] = []
    var mainCone     = SCNCone()
    var hitSphere    = SCNSphere()
    var typeCube     = SCNBox()
    var cubeNode     = SCNNode()
    var hueIndicator = SCNNode()
    var cubeNodeRot  = 0.0
    var highlighted  = false
    var torus1       = SCNTorus()
    var torus2       = SCNTorus()
    var torusNode1   = SCNNode()
    var torusNode2   = SCNNode()
    var lonHandle    = SCNNode()   //11/17 from mainVC
    var latHandle    = SCNNode()
    var lat = 0.0 //11/25 store lat lon here too
    var lon = 0.0

    var uid = ""
    let showHueIndicator = false
    let boxSize : CGFloat =  0.02
    var boxPanel  = SCNBox()
    var panelNodes : [SCNNode] = []
    var zoomed = false

    let synthIcon   = UIImage(named: "synthIcon")
    let sampleIcon  = UIImage(named: "sampleIcon")
    let percIcon    = UIImage(named: "percIcon")
    let percKitIcon = UIImage(named: "percKitIcon")
    
    //11/18 make hls class vals
    var rr = 0
    var gg = 0
    var bb = 0
    var hh = 0
    var ll = 0
    var ss = 0
    var cc = 0
    var mm = 0
    var yy = 0
    var gotPlayed = false
    
    //-------(Marker)-------------------------------------
    override init() {
        super.init()
        //11/17 first add our rotational handles
        self.addChildNode(lonHandle)
        lonHandle.addChildNode(latHandle)
        let allShapes = createMarker()
        let theta = -pi/2.0 //Point bottom of cone marker at earth
        allShapes.rotation = SCNVector4Make(0, 0, 1, Float(theta))
        //DHS 11/17 back to cluge? Why no offset in createMarker?
        #if VERSION_2D
        allShapes.position = SCNVector3Make(1.1, 0, 0);
        #elseif VERSION_AR
        allShapes.position = SCNVector3Make(0.5, 0, 0);
        #endif
        latHandle.addChildNode(allShapes)
        uid = "marker_" + ProcessInfo.processInfo.globallyUniqueString
        allShapes.name = uid
        self.scale = SCNVector3(1,1,1) //Shrink down by half

    }
    
    //-------(Marker)-------------------------------------
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //-------(Marker)-------------------------------------
    func setColor (c:UIColor)
    {
        var fRed   : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue  : CGFloat = 0
        var fAlpha : CGFloat = 0
        if c.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha)
        {
            updateRGBData(rrr: Int(fRed*255.0), ggg: Int(fGreen*255.0), bbb: Int(fBlue*255.0))
        }
    } //end setColor
    
    //-------(Marker)-------------------------------------
    func updateRGBData ( rrr : Int ,ggg : Int ,bbb : Int )
    {
        //Copy to structure data first
        rr = rrr
        gg = ggg
        bb = bbb
        // fill out HSL data
        let hlsTuple = ColorTools.RGBtoHLS(R: rr, G: gg, B: bb)
        hh = hlsTuple.Hue
        ll = hlsTuple.Luminance
        ss = hlsTuple.Saturation
        let cmykTuple = ColorTools.RGBtoCMYK(R: rr, G: gg, B: bb)
        cc = cmykTuple.Cyan
        mm = cmykTuple.Magenta
        yy = cmykTuple.Yellow
    } //end updateRGBValues
    
    //-------(Marker)-------------------------------------
    //vals 0.0 to 1.0
    func updateMarkerPetalsAndColor ()
    {
        
        //yupdate our petals
        updatePetals(rval: rr, gval: gg, bval: bb,
                     cval: cc, mval: mm, yval: yy,
                     hval: hh, sval: ll, lval: ss)
        if showHueIndicator
        {
            //Update hue indicator rotation
            let hueRot = .pi * Double(hh)/255.0
            hueIndicator.rotation = SCNVector4Make(0, 1, 0, Float(hueRot))
        }
        //Always have to convert one way or another!
        let rf = CGFloat(rr)/255.0
        let gf = CGFloat(gg)/255.0
        let bf = CGFloat(bb)/255.0
        let tc = UIColor(red: rf, green: gf, blue: bf, alpha: 1)
        //set cone color
        mainCone.firstMaterial?.diffuse.contents  = tc
        mainCone.firstMaterial?.emission.contents  = tc
    } //end setColorRGB
    
    //-------(Marker)-------------------------------------
    // black bkgd, 4 graph lines, bkgd color and large centered label
    //   stick to 3 letters MAX.  cannot stretch label w/ rect. why?
    public func createPetalImage(label : String, value : Int, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        
        var rect = CGRect(origin: CGPoint.zero, size: isize)
        //Fill bkgd
        color.setFill()
        context.setFillColor(UIColor.black.cgColor);
        context.fill(rect);
        
        let ihit = isize.height
        let barhite = Int( CGFloat(value) * CGFloat(ihit) / 255.0)
        context.setFillColor(color.cgColor);
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
            textColor = UIColor.white
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createPetalImage
    
    //-------(Marker)-------------------------------------
    // black bkgd, long line of name text
    public func createNamePlateImage(label : String) -> UIImage {
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
            textColor = UIColor.white
        }
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createNamePlateImage


    
    //-------(Marker)-------------------------------------
    func toggleHighlight()
    {
        highlighted = !highlighted
        updateHighlight()
    }

    //-------(Marker)-------------------------------------
    func unHighlight()
    {
        highlighted = false
        updateHighlight()
    }

    //-------(Marker)-------------------------------------
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
    }
    
    //-------(Marker)-------------------------------------
    func updateLatLon (llat : Double,llon : Double)
    {
       lat = llat
       lon = llon
       lonHandle.eulerAngles = SCNVector3Make(0, Float(lon), 0)
       latHandle.eulerAngles = SCNVector3Make(0, 0, Float(lat))
    } //end updateMarkerPosition
    
    
    //-------(Marker)-------------------------------------
    func updatePetals( rval:Int, gval:Int, bval:Int,
                       cval:Int, mval:Int, yval:Int,
                       hval:Int, sval:Int, lval:Int )
    {
        //test add texture to petals
        
        let labz = ["R","G","B","C","M","Y","H","S","L"];
        let colz = [UIColor.red,UIColor.green,UIColor.blue,
                    UIColor.cyan,UIColor.magenta,UIColor.yellow,
                    UIColor.lightGray,UIColor.lightGray,UIColor.lightGray] //9/16 brighten
        for i in 0...8
        {
            var val = 0
            switch(i)
            {
            case 0: val=rval
            case 1: val=gval
            case 2: val=bval
            case 3: val=cval
            case 4: val=mval
            case 5: val=yval
            case 6: val=hval
            case 7: val=sval
            case 8: val=lval
            default:val=0
            }
            let ptex = createPetalImage(label: labz[i], value : val, color: colz[i])
            let ppet = petals[i]
            ppet.firstMaterial?.emission.contents = ptex //UIImage(named: "chex4x4")
        }
    } //end updatePetals

    
    
    //-------(Marker)-------------------------------------
    // Makes a complex shape with indicators and other items
    func createMarker() -> SCNNode
    {
        hitSphere = SCNSphere(radius: 0.2)
        
        hitSphere.firstMaterial?.diffuse.contents = UIColor.clear
        let sphereNode = SCNNode(geometry:hitSphere)
        //DHS 11/17 this doesnt work anymore. see cluge above WTF???
       // sphereNode.position = SCNVector3(0,0.1,0) //DHS 10/17 adjust cone so tip is truly at bottom

        mainCone = SCNCone(topRadius: 0.1, bottomRadius: 0.0, height: 0.2)
        let testColor = UIColor.white
        mainCone.firstMaterial?.diffuse.contents  = testColor
        mainCone.firstMaterial?.specular.contents = UIColor.white
        let coneNode = SCNNode(geometry:mainCone)
        sphereNode.addChildNode(coneNode)
        
        //Top of cone, large torus
        torus1 = SCNTorus(ringRadius: 0.1, pipeRadius: 0.01)
        torus1.firstMaterial?.diffuse.contents  = UIColor.black
        torusNode1 = SCNNode(geometry: torus1)
        torusNode1.position = SCNVector3(0,0.1,0)
        sphereNode.addChildNode(torusNode1)
        //Bottom, teeny torus
        torus2 = SCNTorus(ringRadius: 0.017, pipeRadius: 0.005)
        torus2.firstMaterial?.diffuse.contents  = UIColor.black
        torusNode2 = SCNNode(geometry: torus2)
        torusNode2.position = SCNVector3(0,-0.1,0)
        sphereNode.addChildNode(torusNode2)
        
        if (showHueIndicator)
        {
            //Textured spectrum info cylinder
            let infoCyl = SCNCylinder(radius: 0.1, height: 0.01)
            infoCyl.firstMaterial?.diffuse.contents  = UIImage(named: "rainbowRing")
            infoCyl.firstMaterial?.emission.contents = UIImage(named: "rainbowRing")
            let cylNode = SCNNode(geometry: infoCyl)
            sphereNode.addChildNode(cylNode)
            //black cylinder below this one
            let blackCyl = SCNCylinder(radius: 0.1, height: 0.005)
            blackCyl.firstMaterial?.diffuse.contents = UIColor.black
            let blackCylNode = SCNNode(geometry: blackCyl)
            blackCylNode.position = SCNVector3(0,-0.005,0)
            sphereNode.addChildNode(blackCylNode)
            //add indicator box, points to color
            let indicator = SCNBox(width: 0.005, height:0.01 , length: 0.25, chamferRadius: 0)
            indicator.firstMaterial?.diffuse.contents = UIImage(named: "chex4x4")
            hueIndicator = SCNNode(geometry: indicator)
            hueIndicator.position = SCNVector3(0,0.01,0)
            let hueRot = 0.0
            hueIndicator.rotation = SCNVector4Make(0, 1, 0, Float(hueRot))
            sphereNode.addChildNode(hueIndicator)
        }
        
        typeCube = SCNBox()
        typeCube.firstMaterial?.emission.contents = synthIcon
        typeCube.firstMaterial?.diffuse.contents = UIColor.black //DHS 10/10 looks better this way
        cubeNode = SCNNode(geometry: typeCube)
        cubeNode.position = SCNVector3(0, 0.17,0)
        cubeNode.scale    = SCNVector3(0.1,0.1,0.1)
        sphereNode.addChildNode(cubeNode)
        
        //more indicators (flower petals?)
        var angle = 0
        for i in 0...8
        {
            angle = -i * 40 //degrees
            let pRot = Double(angle) * .pi / 180.0
            let petal = SCNBox(width: 0.05, height:0.01 , length: 0.06, chamferRadius: 0)
            petal.firstMaterial?.diffuse.contents  = UIColor.black
            let pnode = SCNNode(geometry: petal)
            pnode.position = SCNVector3(0.0,0.1,0)
            pnode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0, 0.13) //was .15
            //    pnode.pivot = SCNMatrix4MakeTranslation(0.15, 0.0, 0.0)
            pnode.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            sphereNode.addChildNode(pnode)
            petals.append(petal)
            // The sizes are a little thinner, and stick out to
            //  mask the edge textures on each petal.
            //  Maybe they can be used for highlight?
            let pSides = SCNBox(width: 0.055, height:0.009 , length: 0.065, chamferRadius: 0)
            pSides.firstMaterial?.diffuse.contents  = UIColor.black
            let pnode2 = SCNNode(geometry: pSides)
            pnode2.position = SCNVector3(0.0,0.098,0)
            pnode2.pivot = SCNMatrix4MakeTranslation(0.0, 0.0 , 0.13)
            pnode2.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            sphereNode.addChildNode(pnode2)
        }
        //10/11 add box name panels, 4 around marker
        boxPanel = SCNBox(width: 2*boxSize, height:0.2*boxSize , length: 0.2*boxSize, chamferRadius: 0)
        let ii = createNamePlateImage(label: "...")
        boxPanel.firstMaterial?.diffuse.contents  = ii
        boxPanel.firstMaterial?.emission.contents = ii
        for i in 0...3
        {
            let boxNode = SCNNode(geometry: boxPanel)
            boxNode.position = SCNVector3(0,0,0)
            //pivot makes 4 boxes almost mate at corners, but there is enuf
            //  of a bevel on the corners to hide box ends
            boxNode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0 , Float(boxSize * 0.91))
            let pRot = Double(i) * .pi / 2.0
            boxNode.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            sphereNode.addChildNode(boxNode)
            panelNodes.append(boxNode)
        }
        return sphereNode
    }  //end createMarker
    
    
    //-------(Marker)-------------------------------------
    func updateActivity()
    {
        cubeNodeRot  =  cubeNodeRot + 0.03
        cubeNode.rotation = SCNVector4Make(0, 1, 0, Float(cubeNodeRot))
    }
    
    //-------(Marker)-------------------------------------
    func updatePanels(nameStr : String)
    {
        let ii = createNamePlateImage(label: nameStr)
        boxPanel.firstMaterial?.diffuse.contents = ii
        boxPanel.firstMaterial?.emission.contents = ii
    } //end updatePanels

    //-------(Marker)-------------------------------------
    // 10/29 look at voice type, setup icon on marker cube
    func updateTypeInt(newTypeInt : Int32)
    {
        var texture = UIImage(named: "synthIcon")
        switch newTypeInt
        {
        case SYNTH_VOICE:      texture = UIImage(named: "synthIcon")
        case SAMPLE_VOICE:     texture = UIImage(named: "sampleIcon")
        case PERCUSSION_VOICE: texture = UIImage(named: "percIcon")
        case PERCKIT_VOICE:    texture = UIImage(named: "percKitIcon")
        default:               texture = UIImage(named: "synthIcon")
        }
        typeCube.firstMaterial?.emission.contents = texture
    } //end updateTypeInt
    
    //-------(Marker)-------------------------------------
    // 10/29 redo, pass buck to updateTypeInt
    func updateTypeString(newType : String)
    {
        let slc  =  newType.lowercased()
        var tint : Int32 = 0
        switch slc
        {
        case "synth" : tint = SYNTH_VOICE
        case "sample" : tint = SAMPLE_VOICE
        case "percussion" : tint = PERCUSSION_VOICE
        case "perckit" : tint = PERCKIT_VOICE
        default: tint = SYNTH_VOICE
        }
        updateTypeInt(newTypeInt: tint)
    } //end updateTypeString
    
    //-------(Marker)-------------------------------------
    func animateSelectOut()
    {
        let scaleAction = SCNAction.scale(by: 2, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        let scaleAction2 = SCNAction.scale(by: 12.0, duration: 0.5)
        for i in 0...3 //10/11 add namepanels
        {
            panelNodes[i].runAction(scaleAction2)
        }
        zoomed = true
    }


    //-------(Marker)-------------------------------------
    func animateSelectIn()
    {
        let scaleAction = SCNAction.scale(by: 0.5, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        let scaleAction2 = SCNAction.scale(by: 1.0/12.0, duration: 0.5)
        for i in 0...3 //10/11 add namepanels
        {
            panelNodes[i].runAction(scaleAction2)
        }
        zoomed = false
    }
}
