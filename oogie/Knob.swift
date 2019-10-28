//   _  __            _
//  | |/ /_ __   ___ | |__
//  | ' /| '_ \ / _ \| '_ \
//  | . \| | | | (_) | |_) |
//  |_|\_\_| |_|\___/|_.__/
//
//  Alpha-Dial: changes value between min/max, freezes dial at limits.
//  DUH
// 10/5 add wraparound, also 3x knob gesture delta in wraparound state
//           (this is for string choices, like param select)
// 10/10 add .5 to top of wraparound limit for string choices, makes a cleaner transition
//        still seems too quick wrapping 1,0,15,14...  why?
import UIKit
import Foundation
import CoreGraphics

var isContinuous = true
class Knob: UIControl {
  
    var minimumValue: Float = 0
    var maximumValue: Float = 20
    var totalAngle  : Float = 0
    var lastAngle   : Float = 0
    var verbose     : Bool = false
    var wraparound  : Bool = false
    var knobImage   = UIImage(named:"wheel01.png")
    private (set) var value: Float = 0
    private let renderer = KnobRenderer()
  
  //======knob=================================
  var startAngle: CGFloat {
    get { return renderer.startAngle }
    set { renderer.startAngle = newValue }
  }
  
  //======knob=================================
  var endAngle: CGFloat {
    get { return renderer.endAngle }
    set { renderer.endAngle = newValue }
  }
    
  //======knob=================================
  func setKnobBitmap( bname : String)
  {
     knobImage   = UIImage(named:bname)
     //reset layer contents...
     renderer.imageLayer.contents = knobImage?.cgImage
  }
    
  
  //======knob=================================
  func setValue(_ newValue: Float, animated: Bool = false) {
    //print("knob set \(newValue)")
    renderer.setKnobAngle(CGFloat(newValue), animated: animated)
    value = newValue
    totalAngle = value //9/17 duh need to set
  }
  
  
  
  //======knob=================================
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  
  //======knob=================================
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }
  
  //======knob=================================
  private func commonInit() {
    renderer.updateBounds(bounds)
    renderer.color = tintColor
    renderer.setKnobAngle(0, animated: false)
    
    layer.addSublayer(renderer.imageLayer)
    layer.addSublayer(renderer.bBevelLayer)
    layer.addSublayer(renderer.rBevelLayer)

    let gestureRecognizer = RotationGestureRecognizer(target: self, action: #selector(Knob.handleGesture(_:)))
    addGestureRecognizer(gestureRecognizer)
    
  }
  
  //======knob=================================
    @objc private func handleGesture(_ gesture: RotationGestureRecognizer) {
        if gesture.state == .began
        {
            lastAngle = Float(gesture.touchAngle)
        }
        else{
            var delta = Float(gesture.touchAngle) - lastAngle
            
            //10/5 faster on wraparound (string) parameter type
            if wraparound {delta = delta * 3}
            if (delta > 3) {delta = delta - 2 * .pi} //Big change? we flipped past 2pi!
            else if (delta < -3) {delta = delta + 2 * .pi} //Big change? we flipped past 2pi!
            //print("tv \(totalAngle) , min/max \(minimumValue),\(maximumValue) wrap \(wraparound)")
            totalAngle = totalAngle + delta
            if !wraparound //10/5 wraparound doesnt need limit warnings!
            {
                renderer.showRightBevel (flag: totalAngle < maximumValue)
                renderer.showBottomBevel(flag: totalAngle > minimumValue)
                totalAngle = min(max(totalAngle,minimumValue),maximumValue)
            }
            else{ //handle wrap
                if totalAngle < minimumValue {totalAngle = maximumValue}
                if totalAngle > maximumValue+1.5 {totalAngle = minimumValue} //DHS 10/10 add .5 to max
            }
            setValue(totalAngle)
            if verbose{ print("  paramKnob \(totalAngle) minmax \(minimumValue) \(maximumValue)") }
            lastAngle  = Float(gesture.touchAngle)
        }
        if isContinuous {
      sendActions(for: .valueChanged)
    } else {
      if gesture.state == .ended || gesture.state == .cancelled {
        sendActions(for: .valueChanged)
      }
    }


  }
  
}


//======KnobRenderer================
private class KnobRenderer {
  
  let imageLayer  = CALayer()
  let bBevelLayer = CALayer()
  let rBevelLayer = CALayer()
  let knobImage   = UIImage(named:"wheel01.png")
  let bBevelImage = UIImage(named:"bottomBevel.png")
  let rBevelImage = UIImage(named:"rightBevel.png")

  init() {
    imageLayer.contents    = knobImage?.cgImage
    bBevelLayer.contents   = bBevelImage?.cgImage
    rBevelLayer.contents   = rBevelImage?.cgImage
    bBevelLayer.isHidden   = true
    rBevelLayer.isHidden   = true
  }
  
  func showBottomBevel(flag:Bool)
  {
     bBevelLayer.isHidden = flag
     bBevelLayer.opacity  = 0.5
  }
  
  func showRightBevel(flag:Bool)
  {
     rBevelLayer.isHidden = flag
     rBevelLayer.opacity  = 0.5
  }
  

  var color: UIColor = .blue {
    didSet {
    }
  }
  
  
  //======KnobRenderer================
  private (set) var pointerAngle: CGFloat = 0
  
  //======KnobRenderer================
  var startAngle: CGFloat = 0.0 {
    didSet {
    }
  }
  
  //======KnobRenderer================
  var endAngle: CGFloat = CGFloat(Double.pi) * 2.0 {
    didSet {
    }
  }

  //======KnobRenderer================
  // handles drawing our image
  func setKnobAngle(_ newPointerAngle: CGFloat, animated: Bool = false) {
    imageLayer.transform = CATransform3DMakeRotation(newPointerAngle, 0.0, 0.0, 1.0)
    pointerAngle = newPointerAngle
  }
  
  //======KnobRenderer================
  func updateBounds(_ bounds: CGRect) {
    imageLayer.bounds = bounds
    imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    rBevelLayer.bounds = bounds
    rBevelLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    bBevelLayer.bounds = bounds
    bBevelLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)

  }
  
}


import UIKit.UIGestureRecognizerSubclass

//======RotationGestureRecognizer================
private class RotationGestureRecognizer: UIPanGestureRecognizer {
  
  //======RotationGestureRecognizer================
  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    
    maximumNumberOfTouches = 1
    minimumNumberOfTouches = 1
  }
  
  //======RotationGestureRecognizer================
  private(set) var touchAngle: CGFloat = 0
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    updateAngle(with: touches)
  }
  
  //======RotationGestureRecognizer================
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with: event)
    updateAngle(with: touches)
  }
  
  //======RotationGestureRecognizer================
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
  }
  
  //======RotationGestureRecognizer================
  private func updateAngle(with touches: Set<UITouch>) {
    guard
      let touch = touches.first,
      let view = view
      else {
        return
    }
    let touchPoint = touch.location(in: view)
    touchAngle = angle(for: touchPoint, in: view)
  }
  
  //======RotationGestureRecognizer================
  private func angle(for point: CGPoint, in view: UIView) -> CGFloat {
    let centerOffset = CGPoint(x: point.x - view.bounds.midX, y: point.y - view.bounds.midY)
    return atan2(centerOffset.y, centerOffset.x)
  }
  
  
}



