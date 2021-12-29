//

//  tooobShape.swift
//  oogie2D
//
//  Copyright © 2020 fractallonomy
//  Created Oct 28 2021
//
//  Meant to provide a wraparound tooob animation
//    just a cylinder double sided, with an animated texture...
//  has a self-contained texture, noteresidue,
//   which needs update calls!
import SceneKit
 
class tooobShape: SCNNode {

    var mainParent = SCNNode()
    var mainCyl       = SCNCylinder()
    var mainTube      = SCNTube()
    var toobGeometry  = SCNGeometry()

    var nR = noteResidue()
    
    
//    var pedestalBox   = SCNBox()
//    var pedestalNode  = SCNNode()
//    var cylBasePos    =  SCNVector3()
    //10/11 add torii / box label panels
//    var torus1       = SCNTorus() //used for top/bottom torus


    let overallScale : CGFloat = 1.0
    let crad : CGFloat = 5.0   //big, 4 meter diameter?
    let chit : CGFloat = 80.0  // long, extends to horizon?

    var wColor1 = UIColor.white
    var wColor2 = UIColor.yellow
    var wColor3 = UIColor.blue
    var wColor4 = UIColor.red
    var slowTimer = Timer()
//    var fadeTimer = Timer()

    
    //-----------(tooobShape)=============================================
    // NOTE this basically functions as the init, returned node is added
    //   as a child of this object...
    func createToob(sPos00  : SCNVector3 ) -> SCNNode
    {
        var tooobNode = SCNNode()
        let f = CGRect(x: 0, y: 0, width: 512, height: 512)
        let t = createGridImage(frame:f , bg:.clear , fg:.white , xg : 16 , yg : 20 )
        toobGeometry = SCNTube(innerRadius: crad * 0.98, outerRadius: crad, height: chit)
        toobGeometry.firstMaterial?.diffuse.contents  = t
        toobGeometry.firstMaterial?.emission.contents  = t
        toobGeometry.firstMaterial?.isDoubleSided = true
        tooobNode = SCNNode(geometry:toobGeometry)
        tooobNode.position = sPos00
        //rotate 90 degrees on x axis to make tooob go down Z axis
        tooobNode.eulerAngles = SCNVector3Make(-Float.pi / 2.0 , 0, 0)
        tooobNode.name = "tooob"
        
        //make our timer too... OUCH!
        slowTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.updateSlow), userInfo:  nil, repeats: true)

        return tooobNode

 
    }

 

    //-----------(tooobShape)=============================================
    // called by timer, updates shape.  good / bad idea?
    @objc func updateSlow()
    {
        //time to get results and post them...
        let ii = nR.output
        toobGeometry.firstMaterial?.diffuse.contents  = ii
        toobGeometry.firstMaterial?.emission.contents  = ii
    }


  
    //-----------(tooobShape)=============================================
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
        
        let gridwid = 1.0
        //add gray? GRID xy lines...
        context.setFillColor(fg.cgColor);
        xi = 0.0
        yi = 0.0
        xs = gridwid
        ys = CGFloat(frame.size.height)
        for _ in 0...xg-1
        {
            context.fill(CGRect(x: xi, y: yi, width: xs, height: ys));
            xi  = xi + frame.size.width/CGFloat(xg)
        }
        xi = 0.0
        yi = 0.0
        xs = CGFloat(frame.size.width)
        ys = gridwid
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
 
} //end tooobShape
