//
//  PipeShape.swift
//  oogie2D
//
//  Created by Dave Scruton on 11/25/19.
//  Copyright © 2019 fractallonomy. All rights reserved.
//
// 11/29 add highlighted
// 1/14  fix bug in normals in create3DPipe
// 1/22  redo create3DPipe, simplify args
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
    #if VERSION_2D
    let shapeRad    : Double = 1.0
    let markerHit = 0.2
    let pipeRad : CGFloat = 0.025
    #elseif VERSION_AR
    let shapeRad    : Double = 0.25
    let markerHit = 0.05  //1/13
    let pipeRad : CGFloat = 0.008 //1/20
    #endif
    var pipeColor = UIColor(hue: 0.1, saturation: 1.0, brightness: 1.0, alpha: 1.0)
    var ballGeomz : [SCNSphere] = []
    var ballz : [SCNNode] = []
    var cylGeometries : [SCNGeometry] = []
    var cylHeights : [Float] = []
    var wavelength = 1.0 //DHS 11/28 # texture cycles per pipe
    //12/30 need a uid for selecting stuff!
    var uid = "pipe_" + ProcessInfo.processInfo.globallyUniqueString
    var highlighted  = false
    var zoomed = false
    var infobox = SCNBox()
    var infoNode = SCNNode()

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
    func makePipeCyl(from: SCNVector3 , to: SCNVector3) -> (g: SCNGeometry , n:SCNNode, h:Float){
        return makeCylinder(from:from , to:to , radius: pipeRad , color : pipeColor)
    }

    //-----------(oogiePipe)=============================================
    func makeCylinder(from: SCNVector3, to: SCNVector3, radius: CGFloat , color : UIColor) -> (g: SCNGeometry , n:SCNNode,h : Float)
    {
        
        let lookAt = to - from
        
        //print("makecyl to \(to) from \(from) lookat \(lookAt)")
        let height = lookAt.length()

        let y = lookAt.normalized()
        let up = lookAt.cross(vector: to).normalized()
        let x = y.cross(vector: up).normalized()
        let z = x.cross(vector: y).normalized()
        let transform = SCNMatrix4(x: x, y: y, z: z, w: from)

        let geometry = SCNCylinder(radius: radius,
                                   height: CGFloat(height))
        geometry.firstMaterial?.diffuse.contents = color
        let childNode = SCNNode(geometry: geometry)
        childNode.transform = SCNMatrix4MakeTranslation(0.0, height / 2.0, 0.0) *
          transform

        return (geometry,childNode,height)
    }

    //-----------(oogiePipe)=============================================
    // add corner 'elbow' to scene, useful in highlighting
    func addBall(parent: SCNNode , p:SCNVector3)
    {
        //Draw sphere at first cylinder end junction
        let tuple = createCornerSphere(pos: p)
        let nextGeom = tuple.g
        let nextNode = tuple.n
        
        ballGeomz.append(nextGeom)// 11/30 add geometry storage too
        parent.addChildNode(nextNode)
        ballz.append(nextNode) //keep track for highlight
    } //end addBall

    //-----------(oogiePipe)=============================================
    // 1/22 combine all args into OogiePipe struct
    func create3DPipe(oop : OogiePipe) -> SCNNode
    {
        //11/27 good a place as any for uid
        uid = "pipe_" + ProcessInfo.processInfo.globallyUniqueString
        //print("create 3d pipe uid \(uid)")
        //Our master node...
        let parent = SCNNode()
        
        //11/29 info box. gets parented later down...
        // created small, zooms up on select
        infobox = SCNBox(width: 0.085, height: 0.015 , length: 0.015, chamferRadius: 0)
        infobox.firstMaterial?.diffuse.contents  = UIColor.blue
        //11/30 rotate box, was scaled wrongly for short/wide texture
        infoNode = SCNNode(geometry: infobox)
        infoNode.eulerAngles = SCNVector3Make(0, 0, Float(Double.pi/2.0))
        infoNode.name = uid //12/1 for select / deselect
        
        //First half of pipe: get normal , equatorial normal for start object pos
        //Get normal...
        var nx =  cos(oop.flon) * cos(oop.flat) //1/14 wups need to incorporate cosine!
        var nz = -sin(oop.flon) * cos(oop.flat)
        var ny =  sin(oop.flat)
        //get equatorial normal
        var enx = cos(oop.flon)
        var enz = -sin(oop.flon)
        var eny = 0.0
        var enlen = sqrt(enx*enx + eny*eny + enz*enz)
        enx = enx / enlen
        eny = eny / enlen
        enz = enz / enlen
        var pfx = oop.sPos00.x + Float(shapeRad + markerHit) * Float(nx)
        var pfy = oop.sPos00.y + Float(shapeRad + markerHit) * Float(ny)
        var pfz = oop.sPos00.z + Float(shapeRad + markerHit) * Float(nz)
        //Compute pos at top of marker...1/14: pfy looks wrong!
        let p0 = SCNVector3(pfx,pfy,pfz)

        //Compute equatorial position (zero lat)
        var epfx = oop.sPos00.x + Float(shapeRad + 2*markerHit) * Float(enx)
        var epfz = oop.sPos00.z + Float(shapeRad + 2*markerHit) * Float(enz)
        let p1 = SCNVector3(epfx,pfy,epfz) //first junction point

        //Keep track of our pipe geometries, for texturing
        cylGeometries.removeAll()
        cylHeights.removeAll()
        addBall(parent: parent, p:p0)
        //Draw sphere at first cylinder end junction
        addBall(parent: parent,p:p0)
        addBall(parent: parent,p:p1)
        
        let tuple1 = makePipeCyl(from: p1, to: p0)
        
        //Bump up ceiling to just above shapes...
        #if VERSION_2D
        var ceilingy = Float(1.0)
        #elseif VERSION_AR
        var ceilingy = Float(0.2)
        #endif
        let ty0 = oop.sPos00.y + 2.0 //the 2.0 should be bigger than shape radius!
        ceilingy = max(ceilingy,ty0)
        let ty1 = oop.sPos01.y + 2.0 //the 2.0 should be bigger than shape radius!
        ceilingy = max(ceilingy,ty1)

        //get 1st ceiling point...
        let cp0 = SCNVector3(epfx,ceilingy,epfz)
        addBall(parent: parent,p:cp0)
        let tuple2 = makePipeCyl(from: cp0, to: p1)
        //Add our pipe cylinders...
        parent.addChildNode(tuple1.n)
        cylGeometries.append(tuple1.g)
        cylHeights.append(tuple1.h)
        parent.addChildNode(tuple2.n)
        cylGeometries.append(tuple2.g)
        cylHeights.append(tuple2.h)

        tuple2.n.name = uid //11/29 add uid to vertical pipe (for select)

        if (oop.tlat < 10.0) //DHS 11/27 big lat means go to shape, trivial 2nd half of pipe
        {
            
            //Second half of pipe, same but for oop.sPos01 pos, lat lon
            nx =  cos(oop.tlon) * cos(oop.tlat) //1/14 wups need to incorporate cosine!
            nz = -sin(oop.tlon) * sin(oop.tlat)
            ny =  sin(oop.tlat)

            enx = cos(oop.tlon)
            enz = -sin(oop.tlon)
            eny = 0.0
            enlen = sqrt(enx*enx + eny*eny + enz*enz)
            enx = enx / enlen
            eny = eny / enlen
            enz = enz / enlen
            
            pfx = oop.sPos01.x + Float(shapeRad + markerHit) * Float(nx)
            pfy = oop.sPos01.y + Float(shapeRad + markerHit) * Float(ny)
            pfz = oop.sPos01.z + Float(shapeRad + markerHit) * Float(nz)
            //Compute pos at top of marker...
            let p2 = SCNVector3(pfx,pfy,pfz)
            
            //Compute equatorial position (zero lat)
            epfx = oop.sPos01.x + Float(shapeRad + 2*markerHit) * Float(enx)
            epfz = oop.sPos01.z + Float(shapeRad + 2*markerHit) * Float(enz)
            let p3 = SCNVector3(epfx,pfy,epfz) //first junction point
            //Draw sphere at first cylinder end junction, 2nd shape
            addBall(parent: parent,p:p2)
            addBall(parent: parent,p:p3)
            //get 2nd ceiling point...
            let cp1 = SCNVector3(epfx,ceilingy,epfz)
            let tuple5 = makePipeCyl(from: p3, to: p2)
            addBall(parent: parent,p:cp1)
            let tuple4 = makePipeCyl(from: p3, to: cp1)
            
            //Finally, join two ceiling points...
            let tuple3 = makePipeCyl(from: cp1, to: cp0)
            
            parent.addChildNode(tuple3.n)
            parent.addChildNode(tuple4.n)
            parent.addChildNode(tuple5.n)
            cylGeometries.append(tuple3.g)
            cylHeights.append(tuple3.h)
            cylGeometries.append(tuple4.g)
            cylHeights.append(tuple4.h)
            cylGeometries.append(tuple5.g)
            cylHeights.append(tuple5.h)
            
            tuple4.n.name = uid //11/29 (for select)
            tuple3.n.name = uid

        }
        else //trivial pipe to shape?
        {
            //print("pipe2shape")
            let cp3 = SCNVector3(oop.sPos01.x,ceilingy,oop.sPos01.z) //ceiling above shape
            addBall(parent: parent,p:cp3)
            let tuple3 = makePipeCyl(from: oop.sPos01, to: cp3) //11/29 wps wrong directdion
            parent.addChildNode(tuple3.n)
            //join at cieling  s this out of order?
            let tuple4 = makePipeCyl(from: cp3, to: cp0)
            //11/29 add info node to top ceiling pipe?
            tuple4.n.addChildNode(infoNode)
            parent.addChildNode(tuple4.n)
            tuple4.n.name = uid   //11/29 (for select)
            tuple3.n.name = uid
            cylGeometries.append(tuple4.g) //are these in correct order?
            cylHeights.append(tuple4.h)
            cylGeometries.append(tuple3.g)
            cylHeights.append(tuple3.h)

        } //end else
        return parent
    } //end create3DPipe
    
 //-----------(oogiePipe)=============================================
 public func createPipeLabel(label: String , frame:CGRect ,vals : [Float]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor);
    var vmin :Float = 999.0
    var vmax :Float = -999.0
    if vals.count == 0 //1/13/20 handle empty vals
    {
        vmin = 0
        vmax = 0
    }
   else
    {
        for i in 0...vals.count-1
        {
            vmin = min(vmin,vals[i])
            vmax = max(vmin,vals[i])
        }
    }
    let vconv : Float = 1.0 / 255.0
    //print("vminmax \(vmin),\(vmax)")
        context.fill(frame);
        //First draw pipe label...
        var xi = CGFloat(0.0)
        var yi = CGFloat(0.0)
        var xs = frame.size.width
        var ys = CGFloat(20.0)
        let textFont = UIFont(name: "Helvetica Bold", size: CGFloat(ys-3))!
        let text_style=NSMutableParagraphStyle()
        text_style.alignment=NSTextAlignment.center
            let textFontAttributes = [
                    NSAttributedString.Key.font: textFont,
                    NSAttributedString.Key.foregroundColor: UIColor.white,
                    NSAttributedString.Key.paragraphStyle: text_style
                    ] as [NSAttributedString.Key : Any]
        let trect =  CGRect(x: xi, y: yi, width: xs, height: ys)
        label.draw(in: trect, withAttributes: textFontAttributes)
        //Now time to add some graphics below...
        xi = 0
        yi = frame.size.height
        let cc = UIColor.white
        context.setFillColor(cc.cgColor);
        xs = 1
        for val in vals
        {
            ys = CGFloat(20.0 * vconv*val) //11/30 convert 0..255 -> 0..1
            context.fill(CGRect(x: xi, y: yi-ys, width: xs, height: ys))
            xi = xi + xs
        }
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    } //end createPipeLabel


    
    //-----------(oogiePipe)=============================================
    // 11/27 produces texture for pipe, assuming buffer vals has data and
    //   then overlays a grid, xg/yg = #gridlines
    // bptr goes from 0 to 255, just as an indicator
    public func createGridImage(frame:CGRect , c:UIColor , xg : Int , yg : Int, bptr:Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
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
    func texturePipe( phase : Float ,chan : String , vals : [Float],vsize : Int , bptr : Int)
    {
        let xs = 2.0
        var ys = 2.0
        let xt = 0.0
        var yt :Float = 0.0
        
        var chtotal = 0.0
        for h in cylHeights {chtotal = chtotal + Double(h)}
        
        var cp = 0
        let chanColor = getColorForChan(chan: chan)
        let vsizze = vals.count
        //DHS 11/28 we need to know how big the pipe buffer is here!
        let f = CGRect(x: 0, y: 0, width: 32, height: vsizze) //11/28 where do i get buffer size?
        //11/28Compute #gridlines along pipe
        let yg = 4*Int(CGFloat(chtotal));
        
        //load up a gradient for the image colors, use buffer and bptr offset..
        _ = vsizze
        let t = createGridImage(frame:f , c:chanColor , xg : 4 , yg : yg,bptr:bptr)
        
        for g in cylGeometries
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
                
                fm.diffuse.contents = t
                fm.emission.contents = t
            }

        }
        
        
    } //end texturePipe

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
    func updateInfo(nameStr : String , vals : [Float])
    {
        let ii = createPipeLabel(label: nameStr, frame: CGRect(x: 0, y: 0, width: 128, height: 32), vals: vals)
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


