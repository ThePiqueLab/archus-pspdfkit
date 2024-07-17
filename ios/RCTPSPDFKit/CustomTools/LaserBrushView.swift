//
//  LaserBrushView.swift
//  CustomPdfView
//
//  Created by Jianlong Nie on 2023/3/28.
//

import Foundation
import UIKit

class LaserBrushView: UIView {
  var lastPoint = CGPoint.zero
  var brushWidth: CGFloat = 7.0
  var brushColor = UIColor.white
  var shadowColor = UIColor.red.cgColor
  var shadowBlur: CGFloat = 12.0
  // 定义一个计时器
  var timer: Timer?
  private var previousTimestamp: TimeInterval?
  
  private var path = UIBezierPath()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.clear
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    backgroundColor = UIColor.clear
  }
  
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    
    // 创建阴影
    context.setShadow(offset: CGSize(width: 0, height: 0), blur: shadowBlur, color: shadowColor)
    
    // 设置画笔宽度
    
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    // 绘制路径
    brushColor.setStroke()
    path.stroke()
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    self.alpha = 1.0;
    if let touch = touches.first {
      lastPoint = touch.location(in: self)
      path.move(to: lastPoint)
      setNeedsDisplay()
    }
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first {
      let newPoint = touch.location(in: self)
      let previousPoint = touch.previousLocation(in: self)
      let distance = hypot(newPoint.x - previousPoint.x, newPoint.y - previousPoint.y)
      let timeInterval = touch.timestamp - (previousTimestamp ?? touch.timestamp)
      
      // 计算速度
      let velocity = distance / CGFloat(timeInterval)
      
      // 根据速度调整画笔宽度
      //                    brushWidth = max(1, min(30, velocity / 1000 * 10))
      path.lineWidth = brushWidth
      path.addLine(to: newPoint)
      lastPoint = newPoint
      setNeedsDisplay()
      previousTimestamp = touch.timestamp
      // 如果计时器已经存在，则重置计时器
      timer?.invalidate()
      timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) { [weak self] _ in
        // 添加淡出动画
        UIView.animate(withDuration: 0.5, animations: {
          self?.alpha = 0.0
        }) { _ in
          // 动画完成后，将淡出效果视图从画布上移除
          self?.path.removeAllPoints();
          self?.alpha = 1.0
          self?.setNeedsDisplay();
        }
      }
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first {
      let newPoint = touch.location(in: self)
      path.addLine(to: newPoint)
      lastPoint = newPoint
      
    }
  }
}
