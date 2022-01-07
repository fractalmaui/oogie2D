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
//  2/6   add blinking torus on each note played
//  5/15  change blinkTick and updateActivity to make blinks clearer
//  10/28/21 REDO: instead of recreating textures for petals every time,
//            just make grid textures ONCE and use solid colored boxes for indicator bars
// 11/1   updateActivity clear gotplayed, prevent refires
// 11/2  invalidate timer b4 fire, change time period, reverser b/w color in torus
// 11/5  remove gotPlayed clear in updateActivity
// 11/11 add uid at init, need it to set up dice uid
// 11/13 add menu box, add args to createPetalImage
// 11/15  may be memory leak in updatePetals??? or updatePetalsAndColor?
// 11/19 updateActivity just shows crosshairs now, no color changing. called from mainVC FG once again
// 1/1   add noSolo box
//  Try to animate torus on select / deselect: change cone inieial color too
//   https://developer.apple.com/documentation/scenekit/animation/animating_scenekit_content
import UIKit
import Foundation
import SceneKit

class Marker: SCNNode {
    
    var isize = CGSize(width: 256, height: 256) //overall petal image size
    var jsize = CGSize(width: 512, height: 32) //overall petal image size
    var petals : [SCNBox] = []
    var petalGrids   : [UIImage] = []
    var petalIndicators : [SCNNode] = []
    var petalIndicatorYSwing : CGFloat = 0.0
    var mainCone     = SCNCone()
    var coneColor    = UIColor()
    var hitSphere    = SCNSphere()
    var typeCube     = SCNBox()
    var allShapes    = SCNNode() //9/27
    var cubeNode     = SCNNode()
    var diceCube     = SCNBox()   //11/11
    var diceNode     = SCNNode()
    var menuCube     = SCNBox()   //11/13
    var menuNode     = SCNNode()
    var noSoloCube   = SCNBox()   //11/11
    var noSoloNode   = SCNNode()
    var noSoloShown  = false
    var hueIndicator = SCNNode()
    var cubeNodeRot  = 0.0
    let cubeNodeRotStep = 0.1 //11/16/21 move this to settings?
    var highlighted  = false
    var torus1       = SCNTorus()
    var torus2       = SCNTorus()
    var torusNode1   = SCNNode()
    var torusNode2   = SCNNode()
    var lonHandle    = SCNNode()   //11/17 from mainVC
    var latHandle    = SCNNode()
    var boxletParent = SCNNode()
    var lat = 0.0 //11/25 store lat lon here too
    var lon = 0.0
    var oldrf : CGFloat = 0.0   //for liveMarkers
    var oldgf : CGFloat = 0.0
    var oldbf : CGFloat = 0.0

    //10/26 remove VERSION_2D crap
    let overallScale : CGFloat = 0.25

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
    
    let labz = ["R","G","B","C","M","Y","H","S","L"];
    let colz = [UIColor.red,UIColor.green,UIColor.blue,
                UIColor.cyan,UIColor.magenta,UIColor.yellow,
                UIColor.lightGray,UIColor.lightGray,UIColor.lightGray] //9/16 brighten

    
    var blinkTimer = Timer() //2/6

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
    init(newuid:String)
    {
        super.init()
        uid = newuid  //11/11 uid passed in at init time
        //11/17 first add our rotational handles
        createGridsForPetals()
        self.addChildNode(lonHandle)
        lonHandle.addChildNode(latHandle)
        allShapes = createMarker()
        let theta = -Double.pi/2.0 //Point bottom of cone marker at earth
        allShapes.rotation = SCNVector4Make(0, 0, 1, Float(theta))
        //1/12/20 marker is at right position, scale whole thing based on platform
        allShapes.position = SCNVector3Make(1.1, 0, 0);
        latHandle.addChildNode(allShapes)
        allShapes.name = ""
        self.scale = SCNVector3(overallScale,overallScale,overallScale) //Shrink down by half

    }
    
    
    //-------(Marker)-------------------------------------
    func createGridsForPetals()
    {
        for i in 0..<labz.count
        {
            let ii = createGridImage(label: labz[i])
            petalGrids.append(ii)
        }
    } //end createGridsForPetals
    
    
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
    
    let RGBDELTA : CGFloat = 0.03
    //-------(Marker)-------------------------------------
    //vals 0.0 to 1.0
    func updateMarkerPetalsAndColor (liveMarkers : Int)
    {
        //update our petals
        updatePetals(rval: rr, gval: gg, bval: bb,
                     cval: cc, mval: mm, yval: yy,
                     hval: hh, sval: ss, lval: ll) //1/17 wups s/l backwards
        if showHueIndicator
        {
            //Update hue indicator rotation
            let hueRot = .pi * Double(hh)/255.0
            hueIndicator.rotation = SCNVector4Make(0, 1, 0, Float(hueRot))
        }
        // it looks like every time a color is created a memory leak happens.
        //OUCH: memory leak here!!! loses a TON every second!
        if liveMarkers == 1 //11/29 added flag
        {
            let rf = CGFloat(rr)/255.0
            let gf = CGFloat(gg)/255.0
            let bf = CGFloat(bb)/255.0
            //print("lm rgb \(rf) \(gf) \(bf)")
            if (abs(oldrf-rf) > RGBDELTA || abs(oldgf-gf) > RGBDELTA || abs(oldbf-bf) > RGBDELTA) //got new color?
            {
                let tc = UIColor(red: rf, green: gf, blue: bf, alpha: 1)
                mainCone.firstMaterial?.diffuse.contents  = tc
                mainCone.firstMaterial?.emission.contents = tc
                oldrf = rf //save for next comparision
                oldgf = gf
                oldbf = bf
            }
        }
        
    } //end updateMarkerPetalsAndColor
    
    //-------(Marker)-------------------------------------
    // black bkgd, 4 graph lines, bkgd color and large centered label
    //   stick to 3 letters MAX.  cannot stretch label w/ rect. why?
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

    //-------(Marker)-------------------------------------
    // 10/28 create grid with label on it
    public func createGridImage(label : String) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(isize, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        let rect = CGRect(origin: CGPoint.zero, size: isize)
        //Fill bkgd
        context.setFillColor(UIColor.clear.cgColor);
        context.fill(rect);
        
        let ihit = isize.height
        
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
    } //end createGridImage

    
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
    func setNoSolo()
    {
        noSoloShown = true
        noSoloNode.isHidden = !noSoloShown
    }
    //-------(Marker)-------------------------------------
    func clearNoSolo()
    {
        noSoloShown = false
        noSoloNode.isHidden = !noSoloShown
    }

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
        //print("update hilite: set torus  \(tcolor) ")

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
            //10/28 this was very slow
//            let ptex = createPetalImage(label: labz[i], value : val, bgcolor: .black, fgcolor: colz[i])
//            let ppet = petals[i]
//            ppet.firstMaterial?.emission.contents = ptex //UIImage(named: "chex4x4")
            let zoff = petalIndicatorYSwing * (1.0 - (CGFloat(val) / 255.0))
            petalIndicators[i].position = SCNVector3(0.0,0.0,zoff)

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
        coneColor = UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1)  //11/16 change cone color //UIColor.white
        mainCone.firstMaterial?.diffuse.contents   = coneColor
        mainCone.firstMaterial?.emission.contents  = coneColor //11/16 typo?
        let coneNode = SCNNode(geometry:mainCone)
        sphereNode.addChildNode(coneNode)
        
        //Top of cone, large torus
        torus1 = SCNTorus(ringRadius: 0.1, pipeRadius: 0.01)
        torus1.firstMaterial?.diffuse.contents  = UIColor.black
        torusNode1 = SCNNode(geometry: torus1)
        torusNode1.position = SCNVector3(0,0.1,0)
        sphereNode.addChildNode(torusNode1)
        
        //11/16 add some boxes around torus as note activity indicators
        boxletParent.position = SCNVector3(0.0, 0.0 ,0.0)
        torusNode1.addChildNode(boxletParent)
        let boxlet = SCNBox()
        boxlet.firstMaterial?.emission.contents = UIColor.white
        boxlet.firstMaterial?.diffuse.contents  = UIColor.white
        for i in 0...3
        {
            let boxletNode = SCNNode(geometry: boxlet)
            boxletNode.scale    = SCNVector3(0.02,0.02,0.3)
            boxletNode.position = SCNVector3(0.0, 0.0 ,0.0)
            boxletNode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0, 0.1)
            boxletNode.eulerAngles = SCNVector3Make(0, Float(i) * .pi / 2, 0)
            boxletParent.addChildNode(boxletNode)
        }
        boxletParent.isHidden = true
        
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
        
        //1/1/22 add noSolo box
        noSoloCube = SCNBox() //1/1 add noSolo box AROUND cone
        noSoloCube.firstMaterial?.emission.contents = UIColor.darkGray
        noSoloCube.firstMaterial?.diffuse.contents  = UIColor.darkGray
        noSoloNode = SCNNode(geometry: menuCube)
        noSoloNode.position = SCNVector3(0, 0.0,0)
        noSoloNode.scale    = SCNVector3(0.35,0.21,0.35)
        noSoloNode.name = "noSolo_" + uid
        sphereNode.addChildNode(noSoloNode)
        noSoloNode.isHidden = true
        
        typeCube = SCNBox()
        typeCube.firstMaterial?.emission.contents = synthIcon
        typeCube.firstMaterial?.diffuse.contents = UIColor.black //DHS 10/10 looks better this way
        cubeNode = SCNNode(geometry: typeCube)
        cubeNode.position = SCNVector3(0, 0.17,0)
        cubeNode.scale    = SCNVector3(0.1,0.1,0.1)
        sphereNode.addChildNode(cubeNode)
        
        let yellowM = createPetalImage(label : "M", value : 0, bgcolor: .yellow, fgcolor: .black)
        //11/13 add menu control
        menuCube = SCNBox() //11/3 add dice box on top asdf
        menuCube.firstMaterial?.emission.contents = yellowM
        menuCube.firstMaterial?.diffuse.contents = yellowM
        menuNode = SCNNode(geometry: menuCube)
        menuNode.position = SCNVector3(0, 0.3,0)
        menuNode.scale    = SCNVector3(0.1,0.1,0.1)
        menuNode.name = "menu_" + uid
        sphereNode.addChildNode(menuNode)
        
        //11/11 add dice control
        diceCube = SCNBox() //11/3 add dice box on top
        diceCube.firstMaterial?.emission.contents = UIImage(named: "yellowdice")
        diceCube.firstMaterial?.diffuse.contents = UIImage(named: "yellowdice")
        diceNode = SCNNode(geometry: diceCube)
        diceNode.position = SCNVector3(0, 0.43,0)
        diceNode.scale    = SCNVector3(0.1,0.1,0.1)
        diceNode.name = "dice_" + uid
        sphereNode.addChildNode(diceNode)

 
        //more indicators (flower petals?)
        var angle = 0
        let pwid = 0.05
        let phit = 0.015
        let plen = 0.06
        for i in 0...8
        {
            angle = -i * 40 //degrees
            let pRot = Double(angle) * Double.pi / 180.0
            let petal = SCNBox(width: pwid, height:phit , length: plen, chamferRadius: 0)
            let ii = petalGrids[i]
            petal.firstMaterial?.diffuse.contents  = ii
            petal.firstMaterial?.emission.contents  = ii
            let pnode = SCNNode(geometry: petal)
            pnode.position = SCNVector3(0.0,0.08,0.0)
//          pnode.position = SCNVector3(0.0,0.1,0) //old
            pnode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0, 0.13)
            pnode.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            sphereNode.addChildNode(pnode)

            let lilbit = phit * 0.3
            //add bkgd and indicator...
            let pSides = SCNBox(width: pwid+lilbit, height:phit-lilbit , length: plen+lilbit, chamferRadius: 0)
            pSides.firstMaterial?.diffuse.contents  = UIColor.black
            let bkgdNode = SCNNode(geometry: pSides)
            bkgdNode.position = SCNVector3(0.0,0.0,0)
            pnode.addChildNode(bkgdNode)

            //add bkgd and indicator...
            let pIndicator = SCNBox(width: pwid, height:phit-lilbit*0.5 , length: plen, chamferRadius: 0)
            pIndicator.firstMaterial?.diffuse.contents   = colz[i]
            pIndicator.firstMaterial?.emission.contents  = colz[i]
            let pIndNode = SCNNode(geometry: pIndicator)
            petalIndicatorYSwing = plen //save for update time!
            pIndNode.position = SCNVector3(0.0,0.0,plen)
            petalIndicators.append(pIndNode) //save for later
            pnode.addChildNode(pIndNode)
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
    // called periodically by scene.updateAllMarkers
    func updateActivity()
    {
        //print("....... ..... ... .  . .ua \(cubeNodeRot)")
        cubeNodeRot  =  cubeNodeRot + cubeNodeRotStep
        cubeNode.rotation = SCNVector4Make(0, 1, 0, Float(cubeNodeRot))
        //2/6 black out torus briefly to indicate note played, timer restores color
        //torus1.firstMaterial?.emission.contents  = UIColor.white //11/2 try flip colors
        //torus2.firstMaterial?.emission.contents  = UIColor.white
        //print("set torus white \(cubeNodeRot) ") //asdf
        boxletParent.isHidden = false //11/16 flash boxlets
        // 5/15 change timer from .01 to .08
        //11/1/21 SAW CRASH HERE  exception TWICE!!!!
        blinkTimer.invalidate() //11/2 pull old timer!
        blinkTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.blinkTick), userInfo:  nil, repeats: false)
    } //end updateActivity
    
    
    //-------(Marker)-------------------------------------
    // 2/6 makes torus blink back on
    @objc func blinkTick()
    {
        // 11/5 redundant?  blinkTimer.invalidate()
        //torus1.firstMaterial?.emission.contents  = UIColor.black //11/2 try flip colors
        //torus2.firstMaterial?.emission.contents  = UIColor.black
        boxletParent.isHidden = true //11/16 flash boxlets
        gotPlayed = false //5/15 clear our played flag
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
    } //end animateDiceSelect

}
