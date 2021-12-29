//   ____  _            ____  _
//  |  _ \(_)_ __   ___/ ___|| |__   __ _ _ __   ___
//  | |_) | | '_ \ / _ \___ \| '_ \ / _` | '_ \ / _ \
//  |  __/| | |_) |  __/___) | | | | (_| | |_) |  __/
//  |_|   |_| .__/ \___|____/|_| |_|\__,_| .__/ \___|
//          |_|                          |_|
//
//  PipeShape.swift
//  oogie2D
//
//  Created by Dave Scruton on 11/25/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
// 11/29 add highlighted
// 1/14  fix bug in normals in create 3DPipe
// 1/22  redo create 3DPipe, simplify args
// 2/3   add shapeYoff to ceiling calc
// 4/23  increase pipe radius : should this be in DB settings?
// 5/4   add uid name to sphere nodes
// 10/5  add dataImage access
// 10/6  add wraparound support to pipeDataImage, pull image from pipe 3d label
//        redo create PipeDataImage
// 10/22 fix bug in create3DPipe
// 10/23 fix AR infobox size bug
// 10/26 get rid of 2D support for coords, various float var type changes
// 12/24 in create3DPipe change is Shape to obj Type
import Foundation
import UIKit
import SceneKit


//Some SCNVector3 operators...
func - (v1 : SCNVector3 , v2 : SCNVector3) -> SCNVector3
{
    return SCNVector3Make(v1.x - v2.x , v1.y - v2.y , v1.z - v2.z)
}
func + (v1 : SCNVector3 , v2 : SCNVector3) -> SCNVector3
{
    return SCNVector3Make(v1.x + v2.x , v1.y + v2.y , v1.z + v2.z)
}
func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
}

func * (left: SCNMatrix4, right: SCNMatrix4) -> SCNMatrix4 {
    return SCNMatrix4Mult(left, right)
}

//Normalize vector: needed?
//func normal (v : SCNVector3) -> SCNVector3
//{
//    //asdf
//}

extension SCNVector3 {
    /**
     * Calculates the cross product between two SCNVector3.
     */
    func cross(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(y * vector.z - z * vector.y, z * vector.x - x * vector.z, x * vector.y - y * vector.x)
    }

    func length() -> Float {
        return sqrtf(x*x + y*y + z*z)
    }

    /**
     * Normalizes the vector described by the SCNVector3 to length 1.0 and returns
     * the result as a new SCNVector3.
     */
    func normalized() -> SCNVector3 {
        return self / length()
    }
}

extension SCNMatrix4 {
    public init(x: SCNVector3, y: SCNVector3, z: SCNVector3, w: SCNVector3) {
        self.init(
            m11: x.x,
            m12: x.y,
            m13: x.z,
            m14: 0.0,

            m21: y.x,
            m22: y.y,
            m23: y.z,
            m24: 0.0,

            m31: z.x,
            m32: z.y,
            m33: z.z,
            m34: 0.0,

            m41: w.x,
            m42: w.y,
            m43: w.z,
            m44: 1.0)
    }
}



class PipeShape: SCNNode {

    //12/30 is there a smarter way to do this?
    //10/26 remove VERSION_2D crap
    let shapeRad    : Double = 0.25
    let markerHit = 0.05  //1/13
    let pipeRad : CGFloat = 0.008 //1/20
    let infoBoxWid = 0.02 //10/23 scale info box
    let infoBoxHit = 0.0025
    let colorz : [UIColor] = [.red,.green,.blue,.cyan,.magenta,.yellow,.gray,.white]


    var pipeColor = UIColor(hue: 0.1, saturation: 1.0, brightness: 1.0, alpha: 1.0)
    var dataImage = UIImage() //10/5
    var ballGeomz : [SCNSphere] = []
    var ballz : [SCNNode] = []
    var cylz  : [SCNNode] = []
    var mainParent = SCNNode()
    var cylGeometries : [SCNGeometry] = []
    var cylHeights : [Float] = []
    var wavelength = 1.0 //DHS 11/28 # texture cycles per pipe
    //12/30 need a uid for selecting stuff!
    var uid = "pipe_" + ProcessInfo.processInfo.globallyUniqueString
    var highlighted  = false
    var zoomed = false
    var infobox = SCNBox()
    var infoNode = SCNNode()
    var multiGrid = UIImage()
    // 1/26 new stuff...
    var flat    = 0.0
    var flon    = 0.0
    var tlat    = 0.0
    var tlon    = 0.0
    var sPos00  = SCNVector3()
    var sPos01  = SCNVector3()
    
    var channel = 0  //11/17 pipe color channel
    /**
     * Divides the x, y and z fields of a SCNVector3 by the same scalar value and
     * returns the result as a new SCNVector3.
     */
    //-----------(oogiePipe)=============================================
    func createCornerSphere(pos : SCNVector3) -> (g:SCNSphere , n:SCNNode)
    {
        let sphere = SCNSphere(radius: pipeRad)
        sphere.firstMaterial?.diffuse.contents  = pipeColor
        sphere.firstMaterial?.specular.contents = UIColor.white
        let sphereNode = SCNNode(geometry:sphere)
        sphereNode.position = pos
        return (sphere,sphereNode)
    }  //end createCornerSphere

    //-----------(oogiePipe)=============================================
    func makePipeCyl(from: SCNVector3 , to: SCNVector3, newNode : Bool) ->
        (g: SCNGeometry , n:SCNNode, h:Float, t : SCNMatrix4 )
    {
        return makeCylinder(from:from , to:to , radius: pipeRad , color : pipeColor, newNode : newNode)
    }

    //-----------(oogiePipe)=============================================
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
        geometry.firstMaterial?.diffuse.contents = color
        let childNode = SCNNode(geometry: geometry)
        let tf = SCNMatrix4MakeTranslation(0.0, height / 2.0, 0.0) * transform
        childNode.transform = SCNMatrix4MakeTranslation(0.0, height / 2.0, 0.0) * transform
        childNode.name =  String(format: "cyl %d",cylz.count)

        return (geometry,childNode,height,tf)
    }

    //-----------(oogiePipe)=============================================
    // add corner 'elbow' to scene, useful in highlighting
    func addBall(parent: SCNNode , p:SCNVector3 )
    {
        //Draw sphere at first cylinder end junction
        let tuple = createCornerSphere(pos: p)
        ballGeomz.append(tuple.g)// 11/30 add geometry storage too
        let nextNode  = tuple.n
        //nextNode.name =  String(format: "ball %d",ballGeomz.count)
        nextNode.name = uid //  5/4 for select / deselect
        parent.addChildNode(nextNode)
        ballz.append(nextNode) //keep track for highlight
    } //end addBall

    //-----------(oogiePipe)=============================================
    // 1/22 combine all args into OogiePipe struct
    // 12/24 replace issShape with objjType string
    //-----------(oogiePipe)=============================================
     //-----------(oogiePipe)=============================================
    func create3DPipe(uid: String ,  //9/25
                        flat : Double , flon : Double , sPos00  : SCNVector3 ,
                       tlat : Double , tlon : Double , sPos01  : SCNVector3 ,
                       objType: String, newNode : Bool
     ) -> SCNNode
     {
         var cIndex = 0 //local pointer to cylinder nodes during update
         var bIndex = 0 //local pointer to ball nodes during update
         if !newNode && ballz.count == 0 {return SCNNode()} //wups! no pipe to update yet!
         if newNode
         {
             //Our master node...
             mainParent = SCNNode()
             
             //11/29 info box. gets parented later down...
             // created small, zooms up on select
             infobox = SCNBox(width: infoBoxWid, height: infoBoxHit , length: infoBoxHit, chamferRadius: 0)
             infobox.firstMaterial?.diffuse.contents  = UIColor.blue
             //11/30 rotate box, was scaled wrongly for short/wide texture
             infoNode = SCNNode(geometry: infobox)
             infoNode.eulerAngles = SCNVector3Make(0, 0, Float(Double.pi/2.0))
             infoNode.name = uid //12/1 for select / deselect
         }
         //.. may have to move/ update infobox!
         
         //First half of pipe: get normal , equatorial normal for start object pos
         //Get normal...
         var nx =  cos( flon) * cos( flat) //1/14 wups need to incorporate cosine!
         var nz = -sin( flon) * cos( flat)
         var ny =  sin( flat)
         //get equatorial normal
         var enx = cos( flon)
         var enz = -sin( flon)
         var eny = 0.0
         var enlen = sqrt(enx*enx + eny*eny + enz*enz)
         enx = enx / enlen
         eny = eny / enlen
         enz = enz / enlen
         var pfx =  sPos00.x + Float(shapeRad + markerHit) * Float(nx)
         var pfy =  sPos00.y + Float(shapeRad + markerHit) * Float(ny)
         var pfz =  sPos00.z + Float(shapeRad + markerHit) * Float(nz)
         //Compute pos at top of marker...1/14: pfy looks wrong!
         let p0 = SCNVector3(pfx,pfy,pfz)

         //Compute equatorial position (zero lat)
         var epfx =  sPos00.x + Float(shapeRad + 2*markerHit) * Float(enx)
         var epfz =  sPos00.z + Float(shapeRad + 2*markerHit) * Float(enz)
         let p1 = SCNVector3(epfx,pfy,epfz) //first junction point

         let usecylz = true
        
         if newNode
         {
             //Keep track of our pipe geometries, for texturing
             cylGeometries.removeAll()
             cylHeights.removeAll()
             cylz.removeAll()
             ballz.removeAll()
         }
         //Bump up ceiling to just above shapes...
         //10/26 remove VERSION_2D crap
         var ceilingy  = Float(0.2)
         let shapeYoff = Float(0.5) // 2/3/20

         let ty0 =  sPos00.y + shapeYoff //2/3/20 redid
         ceilingy = max(ceilingy,ty0)
         let ty1 =  sPos01.y + shapeYoff //2/3/20 redid
         ceilingy = max(ceilingy,ty1)

         //Draw sphere at first cylinder end junction
         if (newNode)   //2/1
         {
            addBall(parent: mainParent,p:p0)
            addBall(parent: mainParent,p:p1)
         }
         else if bIndex < ballz.count //update? just change position
         {
           ballz[bIndex].position = p0
           bIndex += 1
           ballz[bIndex].position = p1
           bIndex += 1
         }
         let tuple1 = makePipeCyl(from: p1, to: p0, newNode : newNode)

         //get 1st ceiling point...
         let cp0 = SCNVector3(epfx,ceilingy,epfz)
         if (newNode)   //2/1
         {
            addBall(parent: mainParent,p:cp0)
         }
         else if bIndex < ballz.count //update? just change position
         {
           ballz[bIndex].position = cp0
           bIndex += 1
         }
         let tuple2 = makePipeCyl(from: cp0, to: p1, newNode : newNode)
         tuple2.n.name = uid //11/29 add uid to vertical pipe (for select)
         if newNode && usecylz
         {
             //Add our pipe cylinders...
             mainParent.addChildNode(tuple1.n)
             cylz.append(tuple1.n)
             cylGeometries.append(tuple1.g)
             cylHeights.append(tuple1.h)
             mainParent.addChildNode(tuple2.n)
             cylz.append(tuple2.n)
             cylGeometries.append(tuple2.g)
             cylHeights.append(tuple2.h)
         }
         else if !newNode && usecylz  //update? just send resulting transforms to cylz array
         {
             cylz[cIndex].transform = tuple1.t
             cylz[cIndex].geometry  = tuple1.g
             cylGeometries[cIndex]  = tuple1.g //also update texture geometry area
             cIndex+=1
             cylz[cIndex].transform = tuple2.t
             cylz[cIndex].geometry  = tuple2.g
             cylGeometries[cIndex]  = tuple2.g
            cIndex+=1
         }

         if objType == "voice" //DHS 11/27 big lat means go to shape, trivial 2nd half of pipe
         {
             //Second half of pipe, same but for  sPos01 pos, lat lon
             nx =  cos( tlon) * cos( tlat) //1/14 wups need to incorporate cosine!
             nz = -sin( tlon) * cos( tlat) //10/22 bug fix, was sin(tlat)
             ny =  sin( tlat)

             enx = cos( tlon)
             enz = -sin( tlon)
             eny = 0.0
             enlen = sqrt(enx*enx + eny*eny + enz*enz)
             enx = enx / enlen
             eny = eny / enlen
             enz = enz / enlen
             
             pfx =  sPos01.x + Float(shapeRad + markerHit) * Float(nx)
             pfy =  sPos01.y + Float(shapeRad + markerHit) * Float(ny)
             pfz =  sPos01.z + Float(shapeRad + markerHit) * Float(nz)
             //Compute pos at top of marker...
             let p2 = SCNVector3(pfx,pfy,pfz)
             
             //Compute equatorial position (zero lat)
             epfx =  sPos01.x + Float(shapeRad + 2*markerHit) * Float(enx)
             epfz =  sPos01.z + Float(shapeRad + 2*markerHit) * Float(enz)
             let p3 = SCNVector3(epfx,pfy,epfz) //first junction point
             //Draw sphere at first cylinder end junction, 2nd shape
             if (newNode)   //2/1
             {
                addBall(parent: mainParent,p:p2 )
                addBall(parent: mainParent,p:p3 )
             }
             else if bIndex < ballz.count //update? just change position
             {
                ballz[bIndex].position = p2
                bIndex += 1
                ballz[bIndex].position = p3
                bIndex += 1
            }
            //get 2nd ceiling point...
             let cp1 = SCNVector3(epfx,ceilingy,epfz)
             let tuple5 = makePipeCyl(from: p3, to: p2, newNode : newNode)
             if (newNode)  //2/1
             {
                addBall(parent: mainParent,p:cp1)
             }
             else if bIndex < ballz.count //update? just change position
             {
               ballz[bIndex].position = cp1
               bIndex += 1
             }
             let tuple4 = makePipeCyl(from: p3, to: cp1, newNode : newNode)
             tuple4.n.name = uid //11/29 (for select)

             //Finally, join two ceiling points...
             let tuple3 = makePipeCyl(from: cp1, to: cp0, newNode : newNode)
             tuple3.n.name = uid

             if newNode && usecylz
             {
                 mainParent.addChildNode(tuple3.n)
                 cylz.append(tuple3.n)
                 mainParent.addChildNode(tuple4.n)
                 cylz.append(tuple4.n)
                 mainParent.addChildNode(tuple5.n)
                 cylz.append(tuple5.n)
                 cylGeometries.append(tuple3.g)
                 cylHeights.append(tuple3.h)
                 cylGeometries.append(tuple4.g)
                 cylHeights.append(tuple4.h)
                 cylGeometries.append(tuple5.g)
                 cylHeights.append(tuple5.h)
             }
             else if !newNode && usecylz //update? just send resulting transforms to cylz array
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
         else if objType == "shape" //Shape Object
         {
             //print("pipe2shape")
             let cp3 = SCNVector3( sPos01.x,ceilingy, sPos01.z) //ceiling above shape
             if (newNode)  //2/1
             {
                addBall(parent: mainParent,p:cp3)
             }
             else if bIndex < ballz.count //update? just change position
             {
               ballz[bIndex].position = cp3
               bIndex += 1
             }
             let tuple3 = makePipeCyl(from:  sPos01, to: cp3, newNode : newNode) //11/29 wps wrong direction
             tuple3.n.name = uid
             //join at cieling  s this out of order?
             let tuple4 = makePipeCyl(from: cp3, to: cp0, newNode : newNode)
             tuple4.n.name = uid   //11/29 (for select)
             //11/29 add info node to top ceiling pipe?
             tuple4.n.addChildNode(infoNode)
             if newNode && usecylz
             {
                 mainParent.addChildNode(tuple4.n)
                 cylz.append(tuple4.n)
                 mainParent.addChildNode(tuple3.n)
                 cylz.append(tuple3.n)
                 cylGeometries.append(tuple4.g) //are these in correct order?
                 cylHeights.append(tuple4.h)
                 cylGeometries.append(tuple3.g)
                 cylHeights.append(tuple3.h)
             }
             else if !newNode  && usecylz //update? just send resulting transforms to cylz array
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
         return mainParent
     } //end create3DPipe


 //-----------(oogiePipe)=============================================
    public func createPipeLabel(label: String , frame:CGRect)  -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor);
        
        //print("vminmax \(vmin),\(vmax)")
        context.fill(frame);
        //First draw pipe label...
        let xi = CGFloat(0.0)
        let yi = CGFloat(0.0)
        let xs = frame.size.width
        let ys = CGFloat(30.0)
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(ys*0.6))!
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
    } //end createPipeLabel
    

    //-----------(oogiePipe)=============================================
    // 10/5 just store graph internally
    public func createPipeDataImage( frame:CGRect , pinfo : pipeInfo)
    {
        let maxSize = pinfo.pbSize
        let bptr    = pinfo.bptr
        let wrapped = pinfo.wrapped
        let vals    = pinfo.buffer

        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor);
        //print("cpdi max \(maxSize) bptr \(bptr) wrap \(wrapped)")
        var istart = 0;
        var iend   = Int(vals.count) - 1
        if vals.count == 0 //1/13/20 handle empty vals
        {
            context.fill(frame);
        }
        else //got data? graph it
        {
            if wrapped   //10/6 handle wraparound...
              {
                istart = bptr
                iend   = bptr + maxSize - 1
               }
            context.fill(frame);
            //Add our graph...
            let yhit = frame.size.height
            var xi = CGFloat(0.0)
            let yi = frame.size.height
            let xs = CGFloat(frame.size.width) / 256.0
            var ys = CGFloat(0.0)
            context.setFillColor(UIColor.white.cgColor);
            for i in istart...iend
            {
                let iptr = i % maxSize  //note we may wrap around our buffer!
                if (iptr >= 0 && iptr < vals.count) //just in case of weird iptr val...
                {
                    let val = vals[iptr]
                    ys = CGFloat(Float(yhit) * val) //11/30 convert 0..255 -> 0..1
                    context.fill(CGRect(x: xi, y: yi-ys, width: xs, height: ys))
                }
                xi = xi + xs
            }
        } //end else
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        dataImage = resultImage //10/5 for outside inspection
    } //end createPipeDataImage
    
    //-----------(oogiePipe)=============================================
    // 11/27 produces texture for pipe, assuming buffer vals has data and
    //   then overlays a grid, xg/yg = #gridlines
    // bptr goes from 0 to 255, just as an indicator
    public func createGridImage(frame:CGRect , c:UIColor , xg : Int , yg : Int, bptr:Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        guard let context = UIGraphicsGetCurrentContext() else {return UIImage()} //DHS 1/31
        context.setFillColor(UIColor.black.cgColor);
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
        //print("cgimage hite \(frame.size.height)")
        _ = CGFloat(frame.size.height)
        for i in 0...Int(frame.size.height-1) //step along whole length if vals..
        {
            var iii = i - bptr
            while iii < 0 {iii = iii + 256}
            let cc = getBarColor(c: c, fampl: CGFloat(Float(iii%64)/64.0))
            context.setFillColor(cc.cgColor);
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            yi = yi + 1.0
        }
        let needgrid = 1
        if needgrid > 0
        {
            //add gray? GRID xy lines...
            context.setFillColor(UIColor.gray.cgColor);
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
        }
        //Pack up and return image!
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createGridImage

    // for all pipe textures, make 7 different grids, R/G/B/C/M/Y/Greyscale
    public func createMultiGridImage( ) -> UIImage {
        let frame = CGRect(x: 0,y: 0,width: 512,height: 512) //nice and big
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        guard let context = UIGraphicsGetCurrentContext() else {return UIImage()} //DHS 1/31
        context.setFillColor(UIColor.black.cgColor);
        context.fill(frame);
        
        let cc = colorz.count
        
        var xi = 0.0
        var yi = 0.0
        var xs = Double(frame.size.width)
        var ys = 1.0
        
        
        for i in 0...cc-1 //loop over colors...draw gradient top to bottom
        {
            yi = 0.0
            let c = colorz[i]
            xs = Double(512 / cc)
            xi = Double(i) * xs
            for j in 0...Int(frame.size.height-1) //create gradient for each color
            {
                let cc = getBarColor(c: c, fampl: CGFloat(j) / CGFloat(frame.size.height) ) //CGFloat(Float(iii%64)/64.0))
                context.setFillColor(cc.cgColor);
                context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
                yi = yi + 1.0
            }
        }
        let xg = 8*8   //# gridlines across/updown
        let yg = 8
        context.setFillColor(UIColor.white.cgColor);
        //lets do vertical lines... (along pipes)
        xi = 0.0
        yi = 0.0
        xs = 1.0
        ys = CGFloat(frame.size.height)
        for _ in 0...xg-1
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            xi  = xi + frame.size.width/CGFloat(xg)
        }
        
        //Draw grid lines ACROSS image now...
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
    } //end createMultiGridImage

    
    
    
    
    
    
    
    
    
    //-----------(oogiePipe)=============================================
    // 11/1 new, only makes 1xn grid
    public func createBabyGridImage(frame:CGRect , c:UIColor ,  yg : Int, bptr:Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        guard let context = UIGraphicsGetCurrentContext() else {return UIImage()} //DHS 1/31
        context.setFillColor(UIColor.black.cgColor);
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
        //print("cgimage hite \(frame.size.height)")
        _ = CGFloat(frame.size.height)
        //Create bkgd gradient!
        for i in 0...Int(frame.size.height-1) //step along whole length if vals..
        {
            var iii = i - bptr
            while iii < 0 {iii = iii + 256}
            let cc = getBarColor(c: c, fampl: CGFloat(Float(iii%64)/64.0))
            context.setFillColor(cc.cgColor);
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            yi = yi + 1.0
        }
        //add gray? GRID xy lines...
        context.setFillColor(UIColor.white.cgColor);
        xi = 0.0
        yi = 0.0
        xs = 1.0
        ys = CGFloat(frame.size.height)
        context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
        
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
    } //end createBabyGridImage

    
    //-----------(oogiePipe)=============================================
    // 11/27 given 0...1 amplitude input, output color dimmed just so...
    public func getBarColor(c:UIColor , fampl : CGFloat) -> UIColor{
        var red : CGFloat = 0.0
        var green : CGFloat = 0.0
        var blue : CGFloat = 0.0
        var aaa  : CGFloat = 0.0
        c.getRed(&red, green: &green, blue: &blue, alpha: &aaa)
        red = red * fampl
        green = green * fampl
        blue = blue * fampl

        return UIColor(red: red,
                            green: green,
                            blue: blue,
                            alpha: aaa)
    } //end getBarColor

    //-----------(oogiePipe)=============================================
    // 11/27 convert string to color, crude!
    public func getColorForChan(chan:String) -> UIColor
    {
        var ccc = UIColor.black
        switch chan
        {
            case "red"         : ccc = UIColor.red
            case "green"   : ccc = UIColor.green
            case "blue"    : ccc = UIColor.blue
            case "cyan"    : ccc = UIColor.cyan
            case "magenta" : ccc = UIColor.magenta
            case "yellow"  : ccc = UIColor.yellow
            default: ccc = UIColor.gray
        }
        
        return ccc
    }

    //-----------(oogiePipe)=============================================
    // 11/17 point to color in multicolors
    public func getIndexForChan(chan:String) -> Int
    {
        var ii = 0
        switch chan
        {
            case "red"     : ii = 0
            case "green"   : ii = 1
            case "blue"    : ii = 2
            case "cyan"    : ii = 3
            case "magenta" : ii = 4
            case "yellow"  : ii = 5
            default:  ii = 6  //grayscale
        }
        return ii
    } //end getIndexForChan
    
    //-----------(oogiePipe)=============================================
    //11/16 just slide pipe texture along, using bptr
    //  channel is used to pick a segment of texture
    func updatePipeTexture( bptr:Int)
    {
        //var chtotal = 0.0
        let xt = Float(channel) / 8.0
        let yt = 1.0 - (Float(bptr) / 256.0)
        let xs = 0.125   //1/8 of texture for each color grad
        var ys = 1.0
        var i = 0
        for g in cylGeometries //hope this in order???
        {
            let hh = cylHeights[i]
            ys = 4.0 * Double(hh) //yscale proportional to cylinder height
            let scale = SCNMatrix4MakeScale(Float(xs), Float(ys), 0)
            let translation = SCNMatrix4MakeTranslation(Float(xt), Float(yt), 0)
            let transform = SCNMatrix4Mult(scale,translation)

            //print("cyl:\(g) hh \(hh)")
            if g.firstMaterial != nil
            {
                g.firstMaterial!.diffuse.contentsTransform  = transform
                g.firstMaterial!.emission.contentsTransform = transform
            }
            i = i + 1
        }
    } //end updatePipeTexture

    
    func updatePipeTextureOLD(bptr:Int)
    {
        //var chtotal = 0.0
       // for h in cylHeights {chtotal = chtotal + Double(h)}

        let xt : Float = 0.0
        let yt = 1.0 - (Float(bptr) / 256.0)
        let xs = 8.0
        var ys = 2.0
        var i = 0
        for g in cylGeometries //hope this in order???
        {
            let hh = cylHeights[i]
            ys = Double(hh) //match cylinder height in yscale...
            let scale = SCNMatrix4MakeScale(Float(xs), Float(ys), 0)
            let translation = SCNMatrix4MakeTranslation(Float(xt), Float(yt), 0)
            let transform = SCNMatrix4Mult(scale,translation)

            //print("cyl:\(g) hh \(hh)")
            if g.firstMaterial != nil
            {
                g.firstMaterial!.diffuse.contentsTransform  = transform
                g.firstMaterial!.emission.contentsTransform = transform
            }
            i = i + 1
        }
    } //end updatePipeTexture

    //-----------(oogiePipe)=============================================
    // also called from outside when pipe edited
    func setNewChannel( chan : String)
    {
        channel = getIndexForChan(chan:chan)
    }
    
    
    //-----------(oogiePipe)=============================================
    // 11/16 remove valz arg
    func addPipeTexture( phase : Float ,chan : String , vsize : Int , bptr : Int)
    {
        let xs = 8.0
        var ys = 2.0
        let xt = 0.0
        var yt :Float = 0.0
        //11/17 this should only be made ONCE!!
        multiGrid = createMultiGridImage()
        setNewChannel(chan: chan)
 
        
        var chtotal = 0.0
        for h in cylHeights {chtotal = chtotal + Double(h)}
        
        var cp = 0
        //let chanColor = getColorForChan(chan: chan)
        //11/28Compute #gridlines along pipe
        let yg = 4*Int(CGFloat(chtotal));
        //1/30 avoid krash on zero yg
        if yg == 0 {return}

        for g in cylGeometries //loop over pipe segments
        {
            let h = cylHeights[cp]
            cp+=1
            if let fm = g.firstMaterial
            {
                //print("tex g \(g)")
                fm.diffuse.wrapS = .repeat
                fm.diffuse.wrapT = .repeat
                fm.emission.wrapS = .repeat
                fm.emission.wrapT = .repeat
                ys = wavelength * Double(h) / chtotal
                let scale = SCNMatrix4MakeScale(Float(xs), Float(ys), 0)
                let translation = SCNMatrix4MakeTranslation(Float(xt), Float(yt), 0)
                let transform = SCNMatrix4Mult(scale,translation)
                fm.diffuse.contentsTransform  = transform
                fm.emission.contentsTransform = transform

                yt = yt + Float(ys)
                
                fm.diffuse.contents = multiGrid //11/17
                fm.emission.contents = multiGrid
            }

        }
    } //end addPipeTexture

    //-----------(PipeShape)=============================================
    func toggleHighlight()
    {
        highlighted = !highlighted
        updateHighlight()
    }

    //-----------(PipeShape)=============================================
    func unHighlight()
    {
        highlighted = false
        updateHighlight()
    }
    
    //-----------(PipeShape)=============================================
    // h = highlighted. zoom shit up. emphasize color.
    func scaleBallzAndInfo(h:Bool)
    {
        var s = 2.0  //sphere scale up / dn
        var b = 10.0  //box scale up / dn
        if h {s = 0.5 ; b = 0.1}
        let scaleBallzAction = SCNAction.scale(by: CGFloat(s), duration: 0.3)
        for bbb in ballz // corner ballz
        {
            bbb.runAction(scaleBallzAction)
        }
        let scaleBoxAction = SCNAction.scale(by: CGFloat(b), duration: 0.5)
        infoNode.runAction(scaleBoxAction) //11/30 scale info too
    } //end scaleBallzAndInfo

    
    //-----------(PipeShape)=============================================
    func animateSelectOut()
    {
        var tcolor = UIColor.red
        if highlighted
        {
            tcolor = UIColor.white
        }
        for s in ballGeomz //11/30 color my ballz
        {
            s.firstMaterial?.diffuse.contents = tcolor
        }

        scaleBallzAndInfo(h: false)
        zoomed = true
    }
    
    //-----------(PipeShape)=============================================
    func animateSelectIn()
    {
        scaleBallzAndInfo(h: true)
        zoomed = false
    }

    
    //-----------(PipeShape)=============================================
//    func updateInfo(nameStr : String ,maxSize: Int , bptr: Int , wrapped : Bool , vals : [Float])
    func updateInfo(nameStr : String , pinfo : pipeInfo)
    {
        let ff = CGRect(x: 0, y: 0, width: 128, height: 32)
        let ii = createPipeLabel(label: nameStr, frame: ff )
        createPipeDataImage(frame: ff, pinfo : pinfo)
        infobox.firstMaterial?.diffuse.contents  = ii
        infobox.firstMaterial?.emission.contents = ii
    } //end updateInfo


    //-----------(PipeShape)=============================================
    func updateHighlight()
    {
        if highlighted
        {
            if !zoomed {animateSelectOut()}
        }
        else
        {
            if zoomed {animateSelectIn()}
        }
    } //end updateHighlight


}


