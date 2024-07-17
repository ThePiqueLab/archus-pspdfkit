//
//  StrokeBasedEraserView.swift
//  archusnotesappv2
//
//  Created by Yves Rupert Francisco on 7/4/24.
//

import Foundation
import UIKit
import PSPDFKit
import PSPDFKitUI

class StrokeBasedEraserView : UIView {
  let logger = RCTLog()
  var lines = [[CGPoint]()]
  var inPage: UIView? = nil
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.clear
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = UIColor.clear
  }
  
  override func draw(_ rect: CGRect) {
    super.draw(rect)
    guard let context = UIGraphicsGetCurrentContext() else { return }
    
    context.setStrokeColor(UIColor.red.cgColor)
    context.setLineWidth(10)
    context.setLineCap(.round)
    
    lines.forEach{ line in
      for (i, p) in line.enumerated() {
        if i == 0 {
          context.move(to: p)
        } else {
          context.addLine(to: p)
        }
      }
    }
    
    
    context.strokePath()
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    lines.append([CGPoint]())
  }
  
  /** Track the finger as we move across the screen. */
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let point = touches.first?.location(in: self) else { return }
    
    guard var lastLine = lines.popLast() else { return }
    
    lastLine.append(point)
    lines.append(lastLine)
    
    NotificationCenter.default.post(name: .EraseByStroke, object: point)
    setNeedsDisplay()
  }
}
