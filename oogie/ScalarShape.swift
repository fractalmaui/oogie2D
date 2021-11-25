//
//   ____            _            ____  _
//  / ___|  ___ __ _| | __ _ _ __/ ___|| |__   __ _ _ __   ___
//  \___ \ / __/ _` | |/ _` | '__\___ \| '_ \ / _` | '_ \ / _ \
//   ___) | (_| (_| | | (_| | |   ___) | | | | (_| | |_) |  __/
//  |____/ \___\__,_|_|\__,_|_|  |____/|_| |_|\__,_| .__/ \___|
//                                                 |_|
//
//  ScalarShape.swift
//  oogie2D
//
//  Copyright © 2020 fractallonomy
//  Created Oct 9 2021
//
//  Scalar is a single-value parameter controller for oogie2D/AR
//  10/15 complex! added pipe mech, similar to pipe but not enuf to resuse code!
//  10/20 make pipe orange, add animation on scalar change
//  10/26 remove VERSION_2D crap
//  11/3  add dice shape for randomizer
import SceneKit
 
class ScalarShape: SCNNode {
    var highlighted = false
    var zoomed = false
    var uid = ""
    var key = "" //5/3
    
    var pedestalBox   = SCNBox()
    var indicatorBox  = SCNBox()
    var pedestalNode  = SCNNode()
    var indicatorNode = SCNNode()
    var cylNode       = SCNNode()
    var cylBasePos    =  SCNVector3()
    var mainPipeParent = SCNNode()
    //piping
    var ballz : [SCNNode] = []
    var cylz  : [SCNNode] = []
    var ballGeomz     : [SCNSphere] = []
    var cylGeometries : [SCNGeometry] = []
    var cylHeights : [Float] = []


    //10/11 add torii / box label panels
    var torus1       = SCNTorus() //used for top/bottom torus
    var scalarNode   = SCNNode()
    var torusNode1   = SCNNode()
    var torusNode2   = SCNNode()
    var diceCube     = SCNBox()
    var diceNode     = SCNNode()
    //see this about setting compiler switches, also use in mainVC for marker placement
    //   and for use of startPosition in AR version
    
    // 10/26 remove VERSION_2D crap
    var floory  = Float(-0.3)
    let shapeYoff = Float(0.3)
    //Generally AR should be 1/4 size of 2D
    let overallScale : CGFloat = 0.025
    let torusRad     : CGFloat = 0.022
    let pipeRad      : CGFloat = 0.005
    let markerHit    : Double  = 0.05  //1/13
    let shapeRad     : Double  = 0.25
    let bwid : CGFloat =  0.05 //info box size
    let bhit : CGFloat =  0.005
    let crad : CGFloat = 0.02 // main cyl rad
    let chit : CGFloat = 0.2  //main cyl hite
    let phit : CGFloat = 0.02  //main cyl pedestal

    var pipeColor = UIColor.yellow

    var boxPanel     = SCNBox()
    var panelNodes   : [SCNNode] = []
    var jsize = CGSize(width: 512, height: 32) //overall description image size

    var fadeTimer = Timer()
    var fadeCount : Int = 0
    
    //-----------(ScalarShape)=============================================
    // NOTE this basically functions as the init, returned node is added
    //   as a child of this object...
    func create3DScalar(uid: String ,  sPos00  : SCNVector3 ,
                        tlat : Double , tlon : Double , sPos01  : SCNVector3 ,
                        isShape: Bool, newNode : Bool ) -> SCNNode
    {
        
        if newNode
        {
            self.uid        = uid //incoming uid
            pipeColor =  UIColor(red: 0.4, green: 0.4, blue: 0.2, alpha: 1) //10/20 new dorabge color
            scalarNode = createControlShape(sPos00:sPos00)
            scalarNode.name = ""  //9/27 reset name as object gets added...
        }
        else
        {
            print("edit scalar node")
        }
        
        //Get xz positioning for child nodes...
//        let xpos = Float(sPos00.x)
//        let zpos = Float(sPos00.z)
        //start pipe from heart of scalar to target object...
        // spos00 is scalar new location as passed in...
        mainPipeParent = create3DPipe(  sPos00  : sPos00 ,
                                        tlat : tlat , tlon : tlon , sPos01  : sPos01 ,
                                        isShape: isShape, newNode : newNode)
        if newNode //10/20 adding for first time?
        {
            scalarNode.addChildNode(mainPipeParent)
            
            //10/11 add torii to indicate select status
            torus1 = SCNTorus(ringRadius: torusRad, pipeRadius: 3*pipeRad) //10/20 fatten torii
            torus1.firstMaterial?.emission.contents  = UIColor.white
            torusNode1 = SCNNode(geometry: torus1)
            // var torYoff = Float(phit) //bottom torus
            var torusPos = cylBasePos  //3d location, bottom of cylinder
            torusNode1.position = torusPos; //SCNVector3(xpos,torYoff,zpos)
            torusNode1.scale    = SCNVector3(0.1,0.1,0.1)
            scalarNode.addChildNode(torusNode1)
            torusNode2 = SCNNode(geometry: torus1)
            torusPos.y = torusPos.y + Float(chit) //2nd torus, top of cylinder
            torusNode2.position = torusPos
            torusNode2.scale    = SCNVector3(0.1,0.1,0.1)
            scalarNode.addChildNode(torusNode2)
        }
        
        return scalarNode
    }

    
    //-----------(ScalarShape)=============================================
    func addBoxPanel(fillColor:UIColor,sPos00  : SCNVector3) -> (bparent : SCNNode , bpanel:SCNBox)
    {
        //var xpos = sPos00.x
        //var zpos = sPos00.z
        let bparent = SCNNode()
        bparent.position = sPos00
        //add filler box
        let inset = bhit * 0.2
        let fillerBox = SCNBox(width: 2*bwid-inset, height:bhit+inset , length: 2*bwid-inset, chamferRadius: 0)
        fillerBox.firstMaterial?.diffuse.contents  = fillColor
        fillerBox.firstMaterial?.emission.contents = fillColor
        let fboxNode = SCNNode(geometry: fillerBox)
        fboxNode.position = SCNVector3(0,0,0)
        bparent.addChildNode(fboxNode)
        
        //10/11 add box name panels, 4 around marker
        boxPanel = SCNBox(width: 2*bwid-inset, height:bhit , length: bhit, chamferRadius: 0)
        let ii = createTALLLabelImage(label: "...",frame:CGRect(x: 0, y: 0, width: 400, height: 32))
        boxPanel.firstMaterial?.diffuse.contents  = ii
        boxPanel.firstMaterial?.emission.contents = ii
        for i in 0...3
        {
            let boxNode = SCNNode(geometry: boxPanel)
            boxNode.position = SCNVector3(0,0,0)
            //pivot makes 4 boxes almost mate at corners, but there is enuf
            //  of a bevel on the corners to hide box ends
            boxNode.pivot = SCNMatrix4MakeTranslation(0.0, 0.0 , Float(bwid * 0.91))
            let pRot = Double(i) * .pi / 2.0
            boxNode.rotation = SCNVector4Make(0, 1, 0, Float(pRot))
            bparent.addChildNode(boxNode)
        }
        bparent.name = "boxPanel"
        return (bparent,boxPanel)
    } //end addBoxPanel

    //-----------(ScalarShape)=============================================
    func createTexCylinder(pos : SCNVector3 , hite : CGFloat, rad : CGFloat , ii : UIImage) -> SCNNode
    {
        let cylgeometry = SCNCylinder(radius: rad,
                                      height: hite)
        cylgeometry.firstMaterial?.diffuse.contents  = ii //UIColor.cyan
        cylgeometry.firstMaterial?.emission.contents  = ii //UIColor.cyan
        //        cylgeometry.firstMaterial?.specular.contents = ii //UIColor.white
        cylNode = SCNNode(geometry:cylgeometry)
        cylNode.position = pos
        cylNode.name = "texCylinder"
        return cylNode
    }  //end createCylinder
    

    //-----------(ScalarShape)=============================================
    // make tex cylinder, add indicator boxes
    func createControlShape(sPos00 : SCNVector3) -> SCNNode
    {
        let xpos = sPos00.x
        let zpos = sPos00.z

        let mainNode = SCNNode()  // ok heres our pipe parent
        
        let f = CGRect(x: 0, y: 0, width: 128, height: 128)
        let t = createGridImage(frame:f , bg:.clear , fg:.white , xg : 16 , yg : 20 )
//        let t = createGridImage(frame:f , bg:.white , fg:.black , xg : 16 , yg : 20 )

        //starting point for cylinder and its children
//        let s0 = SCNVector3(Float(xpos),Float(phit + chit/2.0),Float(zpos))
        
        //wow this is a kluge
        let s0 = SCNVector3(Float(xpos),floory + Float(chit * 0.5) + 0.15,Float(zpos)) //keep control near pipes
        cylBasePos   = s0                       //get mutable copy...
        cylBasePos.y = cylBasePos.y - 0.5*Float(chit) //  and save bottom of cylinder for later
        let cylNode = createTexCylinder(pos: s0,hite: chit , rad: crad, ii:t)
        mainNode.addChildNode(cylNode)
        
        diceCube = SCNBox() //11/3 add dice box on top
        diceCube.firstMaterial?.emission.contents = UIImage(named: "bluedice")
        diceCube.firstMaterial?.diffuse.contents = UIImage(named: "bluedice")
        diceNode = SCNNode(geometry: diceCube)
        diceNode.position = SCNVector3(s0.x, s0.y + Float(0.8*chit) ,s0.z)
        diceNode.scale    = SCNVector3(0.06,0.06,0.06)
        diceNode.name = "dice_" + uid
        mainNode.addChildNode(diceNode)

        
        // add some box panels, one will move up and down, one is fixed...
        // NOTE : cylBasePos is computed in createTclinder!! move it out?
        let ptuple = addBoxPanel(fillColor:UIColor.clear, sPos00:cylBasePos) //sPos00)
        pedestalNode = ptuple.bparent //main parent node
        pedestalBox  = ptuple.bpanel //handle to where labels go
        mainNode.addChildNode(pedestalNode)
        
        let ituple = addBoxPanel(fillColor:UIColor.red, sPos00:cylBasePos)  //sPos00)
        indicatorNode = ituple.bparent //main parent node
        indicatorBox  = ituple.bpanel //handle to where labels go
        mainNode.addChildNode(indicatorNode)
        return mainNode
    } //end createControlShape

    
    //-----------(ScalarShape)=============================================
    // 9/26 new
    func getNewScalarKey() -> String
    {
       return "scalar_" + ProcessInfo.processInfo.globallyUniqueString
    }
 
    //-----------(ScalarShape)=============================================
    func createGridImage(frame:CGRect , bg:UIColor , fg:UIColor , xg : Int , yg : Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        guard let context = UIGraphicsGetCurrentContext() else {return UIImage()} //DHS 1/31
        context.setFillColor(bg.cgColor);
        context.fill(frame);
        
        var xi = CGFloat(0.0)
        var yi = CGFloat(0.0)
        var xs = CGFloat(0.0)
        var ys = CGFloat(0.0)

        //fill in wave now vertically
        xi = 0.0
        yi = 0.0
        xs = CGFloat(frame.size.width)
        ys = 1.0
        for i in 0...Int(frame.size.height-1) //step along whole length if vals..
        {
            var iii = i
            while iii < 0 {iii = iii + 256}
            context.setFillColor(bg.cgColor);
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            yi = yi + 1.0
        }
        //add gray? GRID xy lines...
        context.setFillColor(fg.cgColor);
        xi = 0.0
        yi = 0.0
        xs = 2.0
        ys = CGFloat(frame.size.height)
        for _ in 0...xg-1
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            xi  = xi + frame.size.width/CGFloat(xg)
        }
        xi = 0.0
        yi = 0.0
        xs = CGFloat(frame.size.width)
        ys = CGFloat(1.0)
        for _ in 0...yg-1
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            yi  = yi + frame.size.height/CGFloat(yg)
        }
        //Pack up and return image!
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createGridImage

    //-----------(ScalarShape)=============================================
    public func createTALLLabelImage(label: String , frame:CGRect)  -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor);
        context.fill(frame);
        //First draw pipe label...
        let xi = CGFloat(0.0)
        let yi = CGFloat(0.0)
        let xs = frame.size.width
        let ys = frame.size.height
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(ys*1.3))! //10/20 make xtra big
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.paragraphStyle: text_style
        ] as [NSAttributedString.Key : Any]
        let trect =  CGRect(x: xi, y: yi, width: xs, height: ys)
        label.draw(in: trect, withAttributes: textFontAttributes)
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createTALLLabelImage
 
    //-----------(oogieScalar)=============================================
    // 10/15 simpler than regular pipe, always goes from scaler base
    //    to target, so there is no from lat/lon
    func create3DPipe( sPos00  : SCNVector3 ,
                       tlat : Double , tlon : Double , sPos01  : SCNVector3 ,
                       isShape: Bool, newNode : Bool
     ) -> SCNNode
     {
         //print("SCALAR: create3DPipe: uid \(uid) ballz \(ballz.count)")

         var cIndex = 0 //local pointer to cylinder nodes during update
         var bIndex = 0 //local pointer to ball nodes during update
         //10/19   BUT we got no ballz after init? wtf?
         if !newNode && ballz.count == 0 {return SCNNode()} //wups! no pipe to update yet!
         if newNode
         {
             mainPipeParent = SCNNode()
         }

         if newNode
         {
             //Keep track of our pipe geometries, for texturing
             cylGeometries.removeAll()
             cylHeights.removeAll()
             cylz.removeAll()
             ballz.removeAll()
         }
         let ty0 =  sPos00.y - shapeYoff
         floory = min(floory,ty0)
         let ty1 =  sPos01.y - shapeYoff
         floory = min(floory,ty1)

         //Get cylinder from our scalar pos to floor
         let p0  = cylBasePos // sPos00   //try our new lower base position
         var floorPos0 = cylBasePos // sPos00
         floorPos0.y = floory //set floor point, will use down below
        
         //get 1st floor point... add ball..
         if (newNode)   //2/1
         {
            addBall(parent: mainPipeParent,p:floorPos0)
         }
         else if bIndex < ballz.count //update? just change position
         {
           ballz[bIndex].position = floorPos0
           bIndex += 1
         }
         let tuple2 = makePipeCyl(from: p0, to: floorPos0, newNode : newNode)
         tuple2.n.name = uid //11/29 add uid to vertical pipe (for select)
         if newNode
         {
             //Add our pipe cylinder... starting at tuple2 for this one!!!
             mainPipeParent.addChildNode(tuple2.n)
             cylz.append(tuple2.n)
             cylGeometries.append(tuple2.g)
             cylHeights.append(tuple2.h)
         }
         else if !newNode  //update? just send resulting transforms to cylz array
         {
             cylz[cIndex].transform = tuple2.t
             cylz[cIndex].geometry  = tuple2.g
             cylGeometries[cIndex]  = tuple2.g
            cIndex+=1
         }
         // geometry vars ... used in math to get lat/lon point for voice marker
         var nx : Double = 0.0
         var ny : Double = 0.0
         var nz : Double = 0.0
         var enx: Double = 0.0
         var eny: Double = 0.0
         var enz: Double = 0.0
         var pfx: Float = 0.0
         var pfy: Float = 0.0
         var pfz: Float = 0.0
         var epfx: Float = 0.0
         //var epfy: Float = 0.0
         var epfz: Float = 0.0
         var enlen: Double = 1.0

         if (!isShape) // route pipe to marker, has lots of elbows
         {
             //Second half of pipe, same but for  sPos01 pos, lat lon
             nx =  cos( tlon) * cos( tlat) //1/14 wups need to incorporate cosine!
             nz = -sin( tlon) * cos( tlat) //10/22 was sin(tlat)???
             ny =  sin( tlat)

             enx = cos( tlon)
             enz = -sin( tlon)
             eny = 0.0
             enlen = sqrt(enx*enx + eny*eny + enz*enz)
             enx = enx / enlen
             eny = eny / enlen
             enz = enz / enlen
             // get 2 higher orbits for marker and pipe connect point
             let markerRad  = Float(shapeRad + markerHit)
             let markerRad2 = Float(shapeRad + 2*markerHit)

             pfx = sPos01.x + markerRad * Float(nx)
             pfy = sPos01.y + markerRad * Float(ny)
             pfz = sPos01.z + markerRad * Float(nz)
             //Compute pos at top of marker...
             // netaget pfy, big ball goes from TR to BL
             //negate pfz, y goes from -1 to 1, z from 1 to -1
             let p2 = SCNVector3(pfx,pfy,pfz)
             
             //Compute equatorial position (zero lat)
             epfx =  sPos01.x + markerRad2 * Float(enx)
             epfz =  sPos01.z + markerRad2 * Float(enz)
             let p3 = SCNVector3(epfx,pfy,epfz) //first junction point
             //Draw sphere at first cylinder end junction, 2nd shape
             if (newNode)   //2/1
             {
                 print("add last link ball...")
                 addBall(parent: mainPipeParent,p:p2 )
                 addBall(parent: mainPipeParent,p:p3 )
             }
             else if bIndex < ballz.count //update? just change position
             {
                ballz[bIndex].position = p2
                bIndex += 1
                ballz[bIndex].position = p3
                bIndex += 1
            }
             // make cylinder from marker to equator point
             let tuple5 = makePipeCyl(from: p3, to: p2, newNode : newNode)
             //get 2nd floor point...
             let floorPos1 = SCNVector3(epfx,floory,epfz)
             if (newNode)  //2/1
             {
                addBall(parent: mainPipeParent,p:floorPos1)
             }
             else if bIndex < ballz.count //update? just change position
             {
               ballz[bIndex].position = floorPos1
               bIndex += 1
             }
             //BUG on ar it looks like p3 is way above sphere, WTF?
             let tuple4 = makePipeCyl(from: p3, to: floorPos1, newNode : newNode)
             tuple4.n.name = uid //11/29 (for select)

             //Finally, join two floor points...
             let tuple3 = makePipeCyl(from: floorPos1, to: floorPos0, newNode : newNode)
             tuple3.n.name = uid

             if newNode
             {
                 mainPipeParent.addChildNode(tuple3.n)
                 cylz.append(tuple3.n)
                 mainPipeParent.addChildNode(tuple4.n)
                 cylz.append(tuple4.n)
                 mainPipeParent.addChildNode(tuple5.n)
                 cylz.append(tuple5.n)
                 cylGeometries.append(tuple3.g)
                 cylHeights.append(tuple3.h)
                 cylGeometries.append(tuple4.g)
                 cylHeights.append(tuple4.h)
                 cylGeometries.append(tuple5.g)
                 cylHeights.append(tuple5.h)
             }
             else if !newNode  //update? just send resulting transforms to cylz array
             {
                 cylz[cIndex].transform = tuple3.t
                 cylz[cIndex].geometry  = tuple3.g
                 cylGeometries[cIndex]  = tuple3.g
                 cIndex+=1
                 cylz[cIndex].transform = tuple4.t
                 cylz[cIndex].geometry  = tuple4.g
                 cylGeometries[cIndex]  = tuple4.g
                 cIndex+=1
                 cylz[cIndex].transform = tuple5.t
                 cylz[cIndex].geometry  = tuple5.g
                 cylGeometries[cIndex]  = tuple5.g
                 cIndex+=1
             }
         }
         else //trivial pipe to shape?
         {
             //print("pipe2shape")
             let floorPos1 = SCNVector3( sPos01.x,floory, sPos01.z) //floor below shape
             if (newNode)  //2/1
             {
                addBall(parent: mainPipeParent,p:floorPos1)
             }
             else if bIndex < ballz.count //update? just change position
             {
               ballz[bIndex].position = floorPos1
               bIndex += 1
             }

             //join at floor s this out of order?
             let tuple4 = makePipeCyl(from: floorPos1, to: floorPos0, newNode : newNode)
             tuple4.n.name = uid   //11/29 (for select)

             var cp4 = sPos01 //try a point a little above our shape center
             //10/16 WHY the fuckdo i have to do this?
             // cp4 should be the center of the shape, but the cylinder
             //  never draws from the floor to that point.
             // instead i copy it to cp4 and then jiggle cp4s xyz a bit and voila! the cylinder is there.
             
             cp4.x = cp4.x + 0.01 //jiggle around a bit
             cp4.y = cp4.y + 0.01  //10/27 wyps
             cp4.z = cp4.z + 0.01
             let tuple3 = makePipeCyl(from:  floorPos1, to: cp4, newNode : newNode)
             tuple3.n.name = uid

             
//             //add some krap
//             for _ in 0...4
//             {
//                 cp3.x = cp3.x - 0.5
//                 cp3.y = cp3.y - 0.5
//                 cp3.z = cp3.z - 0.5
//                 cp4.x = cp4.x + 0.5
//                 cp4.y = cp4.y - 0.5
//                 cp4.z = cp4.z + 0.5
//                 let tuplexx = makePipeCyl(from: cp3, to: cp4, newNode : newNode)
//                 mainPipeParent.addChildNode(tuplexx.n)
//             }
             
             if newNode
             {
                 mainPipeParent.addChildNode(tuple4.n)
                 cylz.append(tuple4.n)
                 mainPipeParent.addChildNode(tuple3.n)
                 cylz.append(tuple3.n)
                 cylGeometries.append(tuple4.g) //are these in correct order?
                 cylHeights.append(tuple4.h)
                 cylGeometries.append(tuple3.g)
                 cylHeights.append(tuple3.h)
             }
             else if !newNode   //update? just send resulting transforms to cylz array
             {
                 cylz[cIndex].transform = tuple4.t
                 cylz[cIndex].geometry  = tuple4.g
                 cylGeometries[cIndex]  = tuple4.g
                 cIndex+=1
                 cylz[cIndex].transform = tuple3.t
                 cylz[cIndex].geometry  = tuple3.g
                 cylGeometries[cIndex]  = tuple3.g
                 cIndex+=1
             }
         } //end else
         
         //print("--->SCALAR: ENDOFcreate3DPipe: uid \(uid) ballz \(ballz.count)")

         return mainPipeParent
     } //end create3DPipe

    //-----------(oogiePipe)=============================================
    func makeCornerSphere(pos : SCNVector3) -> (g:SCNSphere , n:SCNNode)
    {
        // TEST 5.2 is reslly 1.2
        let sphere = SCNSphere(radius: 1.2 * pipeRad) //10/18 add elbows just for shit
        sphere.firstMaterial?.diffuse.contents   = pipeColor
        sphere.firstMaterial?.emission.contents  = pipeColor
        let sphereNode = SCNNode(geometry:sphere)
        sphereNode.position = pos
        return (sphere,sphereNode)
    }  //end makeCornerSphere

    //-----------(oogieScalar)=============================================
    func makePipeCyl(from: SCNVector3 , to: SCNVector3, newNode : Bool) ->
        (g: SCNGeometry , n:SCNNode, h:Float, t : SCNMatrix4 )
    {
        return makeCylinder(from:from , to:to , radius: pipeRad , color : pipeColor, newNode : newNode)
    }

    //-----------(oogieScalar)=============================================
    func makeCylinder(from: SCNVector3, to: SCNVector3, radius: CGFloat , color : UIColor, newNode:Bool) ->
        (g: SCNGeometry , n:SCNNode,h : Float, t : SCNMatrix4)
    {
        let lookAt = to - from
        //print("makecyl to \(to) from \(from) lookat \(lookAt)")
        let height = lookAt.length()
        let y  = lookAt.normalized()
        let up = lookAt.cross(vector: to).normalized()
        let x  = y.cross(vector: up).normalized()
        let z  = x.cross(vector: y).normalized()
        let transform = SCNMatrix4(x: x, y: y, z: z, w: from)
        let geometry  = SCNCylinder(radius: radius,
                                   height: CGFloat(height))
        geometry.firstMaterial?.diffuse.contents  = color
        geometry.firstMaterial?.emission.contents = color
        let childNode = SCNNode(geometry: geometry)
        let tf = SCNMatrix4MakeTranslation(0.0, height / 2.0, 0.0) * transform
        childNode.transform = SCNMatrix4MakeTranslation(0.0, height / 2.0, 0.0) * transform
        childNode.name =  String(format: "cyl %d",cylz.count)

        return (geometry,childNode,height,tf)
    }

    //-----------(oogieScalar)=============================================
    // add corner 'elbow' to scene, useful in highlighting
    func addBall(parent: SCNNode , p:SCNVector3 )
    {
        //Draw sphere at first cylinder end junction
        let tuple = makeCornerSphere(pos: p)
        ballGeomz.append(tuple.g)// 11/30 add geometry storage too
        let nextNode  = tuple.n
        //nextNode.name =  String(format: "ball %d",ballGeomz.count)
        nextNode.name = uid //  5/4 for select / deselect
        parent.addChildNode(nextNode)
        ballz.append(nextNode) //keep track for highlight
    } //end addBall

    //-----------(ScalarShape)=============================================
    // starts a timer which recolors the scalar pipes
    func startFadeout()
    {
        fadeTimer.invalidate() //clobber old timer first
        //print("scalar start fadeout")
        colorPipesWith(brightness: 6.0)  //bright yellow pipes
        fadeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.animateScalarTick), userInfo:  nil, repeats: true)
        fadeCount = 6;  //how many tics we will tock
    } //end startFadeout
    
    //-----------(ScalarShape)=============================================
    // f goes from 1 to 0, 0 is orange, 1 is bright yellow
    func colorPipesWith(brightness:Float)
    {
        let rgfloat = 0.4 + CGFloat(brightness) * 0.1
        let sColor = UIColor(red: rgfloat, green: rgfloat, blue: 0.2, alpha: 1)
        for i in 0..<cylGeometries.count
        {
            cylGeometries[i].firstMaterial?.diffuse.contents   = sColor
            cylGeometries[i].firstMaterial?.emission.contents  = sColor
        }
    } //end colorPipesWith
    
    //-----------(ScalarShape)=============================================
    // 10/20 animate scalar pipe color
    // handle timed sxalar aniation pdates
    @objc func animateScalarTick()
    {
        //print("scalar fade out \(fadeCount)")
        fadeCount = fadeCount - 1;
        colorPipesWith(brightness: Float(fadeCount))
        if  fadeCount == 0
        {
            fadeTimer.invalidate()
        }
    } //end animateScalar
    
    //-----------(ScalarShape)=============================================
    func toggleHighlight()
    {
        highlighted = !highlighted
        //print("scalar \(uid) toggle hilite to \(highlighted)")
        updateHighlight()
    }
    
    //-----------(ScalarShape)=============================================
    func unHighlight()
    {
        highlighted = false
        updateHighlight()
    }

    //-----------(ScalarShape)=============================================
    // floating indicator, value goes from 0 to 1
    func updateIndicator(with:String , value : CGFloat)
    {
        updateBoxPanel(parent: indicatorNode, panel: indicatorBox, label: with, uhit: value)
    }

    //-----------(ScalarShape)=============================================
    // pedestal shape contains main label
    func updateLabel(with:String )
    {
        updateBoxPanel(parent: pedestalNode, panel: pedestalBox, label: with, uhit: -1.0)
    }

    //  uhit is UNIT height, always 0..1 if negative, dont apply offset!
    // NOTE this needs unit,phit,chit predefined above...!!!
    //-----------(ScalarShape)=============================================
    func updateBoxPanel(parent:SCNNode ,panel:SCNBox,label:String, uhit: CGFloat)
    {
        //set labels...
        let ii = createTALLLabelImage(label: label,frame:CGRect(x: 0, y: 0, width: 400, height: 32))
        panel.firstMaterial?.diffuse.contents  = ii
        panel.firstMaterial?.emission.contents = ii
        var s1 = cylBasePos
        if uhit >= 0.0 //need to shift up?
        {
            s1.y = s1.y + Float(chit * uhit)
        }
        parent.position = s1
    } //end updateBoxPanel

        
    //-----------(ScalarShape)=============================================
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
    } //end updateHighlight
    
    //-----------(ScalarShape)=============================================
    // 11/4 new
    func animateDiceSelect()
    {
        var zoom = 2.0
        let scaleAction1 = SCNAction.scale(by: zoom, duration: 0.05)
        let scaleAction2 = SCNAction.scale(by: 1.0 / zoom, duration: 0.8)
        let sequence = SCNAction.sequence([scaleAction1, scaleAction2])
        diceNode.runAction(sequence, completionHandler:nil)

        zoom = zoom * 5.0  //bigger oom for torus
        let scaleAction11 = SCNAction.scale(by: zoom, duration: 0.05)
        let scaleAction12 = SCNAction.scale(by: 1.0 / zoom, duration: 0.8)
        let sequence2 = SCNAction.sequence([scaleAction11, scaleAction12])
        torusNode1.runAction(sequence2)
        torusNode2.runAction(sequence2)
    } //end animateDiceSelect
    
    //-----------(ScalarShape)=============================================
    func animateSelectOut()
    {
        let scaleAction = SCNAction.scale(by: 10, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        zoomed = true
    }
    
    
    //-----------(ScalarShape)=============================================
    func animateSelectIn()
    {
        let scaleAction = SCNAction.scale(by: 0.1, duration: 0.3)
        torusNode1.runAction(scaleAction)
        torusNode2.runAction(scaleAction)
        zoomed = false
    }

} //end ScalarShape
