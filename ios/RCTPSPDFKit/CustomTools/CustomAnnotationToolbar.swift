//
//  CustomAnnotationToolbar.swift
//  RCTPSPDFKit
//
//  Created by Yves Rupert Francisco on 7/17/24.
//  Copyright © 2024 Facebook. All rights reserved.
//

import Foundation
import UIKit
import PSPDFKit
import PSPDFKitUI

extension Notification.Name {
  public static let CloneNewInk = Notification.Name("CloneNewInk")
  public static let DeleteNewInk = Notification.Name("DeleteNewInk")
  public static let ToggleEraseByStroke = Notification.Name("ToggleEraseByStroke")
  public static let EraseByStroke = Notification.Name("EraseByStroke")
  public static let WindowWillClose = Notification.Name("WindowWillClose")
  public static let WindowReopened = Notification.Name("WindowReopened")
  public static let PSCDocumentOpenedInNewScene = NSNotification.Name("PSCDocumentOpenedInNewScene")
  public static let CloseFileTabbar = NSNotification.Name("CloseFileTabbar")
  public static let Leaser = NSNotification.Name("Leaser")
  public static let ToolBarChanged = NSNotification.Name("ToolBarChanged");
  public static let onSelectedFilePath = NSNotification.Name("onSelectedFilePath");
  public static let ClickedAddNewPage = NSNotification.Name("ClickedAddNewPage");
  public static let ClickedRemovePage = NSNotification.Name("ClickedRemovePage");
}

public extension UIColor{
  var codedString: String?{
    do{
      let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
      
      return data.base64EncodedString()
    }
    catch let error{
      print("Error converting color to coded string: \(error)")
      return nil
    }
  }
  
  static func color(withCodedString string: String) -> UIColor?{
    guard let data = Data(base64Encoded: string) else{
      return nil
    }
    
    return try! NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
  }
}

// MARK: - Annotation Toolbar with Laser and Clone
class CustomAnnotationToolbar: AnnotationToolbar {
  /** This is used to persist the created cloned annotation tools so that when the user reopens the pdf view, we can recreate the same annotation tools.  */
  let userDefaults = UserDefaults.standard;
  /** This is the key for accessing the cloned annotation tool ids in the `userDefaults`. */
  let CLONED_BUTTON_IDS_KEY = "CLONED_BUTTON_IDS";
  /** This is used for the laser tool. */
  var laserBrushView = LaserBrushView();
  /** The stroke-based eraser. */
  var strokeBasedEraserView = StrokeBasedEraserView();
  /** This is to indicate whether the stroke-based eraser is on or not. */
  var strokeBasedEraserIsOn = false;
  /** Logger for react native. Use this instead of `print()` so that we can see the logs from the react native console. */
  let logger = RCTLog();
  
  
  // MARK: - Lifecycle
  override init(annotationStateManager: AnnotationStateManager) {
    super.init(annotationStateManager: annotationStateManager)
    
    let annotationToolbarProxy = AnnotationToolbar.appearance()
    
    /** Sets the color of the annotation tool icons */
    let appearance = UIToolbarAppearance()
    //        appearance.backgroundColor = barColor
    annotationToolbarProxy.standardAppearance = appearance
    annotationToolbarProxy.compactAppearance = appearance
    annotationToolbarProxy.tintColor = UIColor(red: 243.0/255.0, green: 107.0/255.0, blue: 127.0/255.0, alpha: 1.0)
    
    /** Sets the color of the navigation bar icons. */
    let appearanceProxy = UINavigationBar.appearance(whenContainedInInstancesOf: [PDFNavigationController.self])
    appearanceProxy.tintColor =  UIColor(red: 243.0/255.0, green: 107.0/255.0, blue: 127.0/255.0, alpha: 1.0)
    
    
    /** Adds the laser/wand annotation tool */
    let laser = ToolbarSelectableButton();
    laser.image=UIImage(systemName: "wand.and.rays");
    laser.accessibilityLabel = "laser";
    laser.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons=[laser];
    
    /** Adds the eraser annotation tool. */
    let eraser = ToolbarSelectableButton();
    eraser.image=PSPDFKit.SDK.imageNamed("eraser");
    eraser.accessibilityLabel = "eraser";
    eraser.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    /** Long Press Gesture - This is for enabling long press on buttons with style picker. */
    additionalButtons?.append(eraser);
    
    /** Adds the ink pen annotation tool. */
    let ink = ToolbarSelectableButton();
    ink.image=PSPDFKit.SDK.imageNamed("ink");
    ink.accessibilityLabel = Annotation.Variant.inkPen.rawValue;
    ink.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    /** This is for adding a small dot indicator on the tool to indicate the current style of the tool. */
    calculateIndicator(sender: ink);
    additionalButtons?.append(ink);
    
    /** Get the cloned annotation tool ids from the `userDefaults`. */
    var clonedButtonIds = userDefaults.array(forKey: self.CLONED_BUTTON_IDS_KEY) as? [String];
    
    logger.info("GET clonedButtonIds: \(clonedButtonIds?.joined(separator: ", ") ?? "[]")");
    
    /** Adds the previously cloned ink pen annotation tools. */
    clonedButtonIds?.filter({ $0.hasSuffix("ink_pen") }).forEach { variantId in
      let clonedInkButton = ToolbarSelectableButton();
      clonedInkButton.image=PSPDFKit.SDK.imageNamed("ink");
      clonedInkButton.accessibilityLabel = variantId;
      clonedInkButton.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside);
      /** This is for adding a small dot indicator on the tool to indicate the current style of the tool. */
      calculateIndicator(sender: clonedInkButton);
      additionalButtons?.append(clonedInkButton);
    }
    
    /** Adds the ink highlighter annotation tool.  */
    let inkHighlight = ToolbarSelectableButton();
    inkHighlight.image=PSPDFKit.SDK.imageNamed("ink_highlighter");
    inkHighlight.accessibilityLabel = Annotation.Variant.inkHighlighter.rawValue;
    inkHighlight.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    /** This is for adding a small dot indicator on the tool to indicate the current style of the tool. */
    calculateIndicator(sender: inkHighlight);
    additionalButtons?.append(inkHighlight);
    
    /** Adds the previously cloned ink highlighter annotation tools. */
    clonedButtonIds?.filter({ $0.hasSuffix("ink_highlighter") }).forEach { variantId in
      let clonedInkHighlighterButton = ToolbarSelectableButton();
      clonedInkHighlighterButton.image=PSPDFKit.SDK.imageNamed("ink_highlighter");
      clonedInkHighlighterButton.accessibilityLabel = variantId;
      clonedInkHighlighterButton.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
      /** This is for adding a small dot indicator on the tool to indicate the current style of the tool. */
      calculateIndicator(sender: clonedInkHighlighterButton);
      additionalButtons?.append(clonedInkHighlighterButton);
    }
    
    /** Adds the selection annotation tool. */
    let selectionTool = ToolbarSelectableButton();
    selectionTool.image=PSPDFKit.SDK.imageNamed("selectiontool");
    selectionTool.accessibilityLabel = "selectionTool";
    selectionTool.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(selectionTool);
    
    /** Adds the line annotation tool. */
    let line = ToolbarSelectableButton();
    line.image=PSPDFKit.SDK.imageNamed("line");
    line.accessibilityLabel = "line";
    line.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(line);
    
    /** Adds the line arrow annotation tool. */
    let lineArrow = ToolbarSelectableButton();
    lineArrow.image=PSPDFKit.SDK.imageNamed("line_arrow");
    lineArrow.accessibilityLabel = "arrow";
    lineArrow.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(lineArrow);
    
    /** Adds the ink magic annotation tool.  */
    let inkMagic = ToolbarSelectableButton();
    inkMagic.image=PSPDFKit.SDK.imageNamed("ink_magic");
    inkMagic.accessibilityLabel = "inkMagic";
    inkMagic.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(inkMagic);
    
    /** Adds the highlight annotation tool. */
    let textHighlight = ToolbarSelectableButton();
    textHighlight.image=PSPDFKit.SDK.imageNamed("highlight");
    textHighlight.accessibilityLabel = "textHighlighter";
    textHighlight.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(textHighlight)
    
    /** Adds the free text annotation tool. */
    let freeText = ToolbarSelectableButton();
    freeText.image=PSPDFKit.SDK.imageNamed("freetext");
    freeText.accessibilityLabel = "freeText";
    freeText.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(freeText);
    
    /** Adds the note annotation tool. */
    let note = ToolbarSelectableButton();
    note.image=PSPDFKit.SDK.imageNamed("text");
    note.accessibilityLabel = "note";
    note.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
    additionalButtons?.append(note);
    
    /** Event Listeners */
    let dnc = NotificationCenter.default
    
    /** Adds event listener for `CloneNewInk`*/
    dnc.removeObserver(self, name: .CloneNewInk, object: nil)
    dnc.addObserver(self, selector: #selector(onClonePressed), name: .CloneNewInk, object: nil)
    
    /** Adds event listener for `DeleteNewInk` */
    dnc.removeObserver(self, name: .DeleteNewInk, object: nil)
    dnc.addObserver(self, selector: #selector(onDeletePressed), name: .DeleteNewInk, object: nil)
    
    /** Adds event listener for `ToolBarChanged`*/
    dnc.removeObserver(self, name: .ToolBarChanged, object: nil)
    dnc.addObserver(self, selector: #selector(onToolBarChanged), name: .ToolBarChanged, object: nil)
    
    /**
     * Adds event listener for `ToggleEraseByStroke`
     */
    dnc.removeObserver(self, name: .ToggleEraseByStroke, object: nil)
    dnc.addObserver(self, selector: #selector(onToggleEraseByStroke), name: .ToggleEraseByStroke, object: nil)
    /**
     * Adds event listener for `EraseByStroke`
     */
    dnc.removeObserver(self, name: .EraseByStroke, object: nil)
    dnc.addObserver(self, selector: #selector(onEraseByStroke), name: .EraseByStroke, object: nil)
    
    let compactConfiguration = AnnotationToolConfiguration(annotationGroups: [])
    let regularConfiguration = AnnotationToolConfiguration(annotationGroups: [])
    configurations = [compactConfiguration, regularConfiguration]
    annotationStateManager.addObserver(self, forKeyPath: "lineWidth", options: [.new], context: nil)
    annotationStateManager.addObserver(self, forKeyPath: "drawColor", options: [.new], context: nil)
  }
  
  /** This is used for adding an small dot indicator on the tools that has a style picker. */
  @objc public func calculateIndicator(sender:ToolbarSelectableButton) {
    let oldStyle = SDK.shared.styleManager.lastUsedStyle(forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: sender.accessibilityLabel as! String)))
    
    let indictorView = CALayer();
    indictorView.accessibilityLabel = "indicator";
    
    if oldStyle != nil {
      for (key,value) in (oldStyle?.styleDictionary as! Dictionary<AnnotationStyle.Key, Any>) {
        if key == AnnotationStyle.Key.color {
          indictorView.backgroundColor = (value as! UIColor).cgColor;
        }
        if key == AnnotationStyle.Key.lineWidth {
          let newWidth = ((value as! CGFloat) / 40.0) * 12.0 < 4 ? 4 : ((value as! CGFloat) / 40.0) * 12.0;
          let xPosition = 40 - newWidth;
          let yPositon = 40 - newWidth;
          indictorView.frame = CGRect(x: xPosition, y: yPositon, width: newWidth, height: newWidth);
          indictorView.cornerRadius = newWidth / 2;
        }
      }
    } else {
      let newWidth = 4.0;
      let xPosition = 40 - newWidth;
      let yPositon = 40 - newWidth;
      indictorView.frame = CGRect(x: xPosition, y: yPositon, width: newWidth, height: newWidth);
      indictorView.backgroundColor = UIColor.blue.cgColor;
      indictorView.cornerRadius = newWidth / 2;
    }
    
    sender.layer.addSublayer(indictorView);
  }
  
  /** This is for updating the color of the small dot indicator on the tools of the toolbar that has a style picker. */
  @objc public func updateIndicator(sender:ToolbarSelectableButton,lineWidth:CGFloat,drawColor:UIColor) {
    sender.layer.sublayers?.forEach{ layer in
      if layer.accessibilityLabel != nil {
        layer.removeFromSuperlayer();
      }
    }
    let indictorView = CALayer();
    indictorView.accessibilityLabel = "indicator";
    let newWidth = ( lineWidth / 40.0) * 12.0 < 4 ? 4 : (lineWidth / 40.0) * 12.0;
    let xPosition = 40 - newWidth;
    let yPositon = 40 - newWidth;
    indictorView.frame = CGRect(x: xPosition, y: yPositon, width: newWidth, height: newWidth);
    indictorView.cornerRadius = newWidth / 2;
    indictorView.backgroundColor = drawColor.cgColor;
    
    sender.layer.addSublayer(indictorView);
  }
  
  /** Handles the annotation tool pressed event. */
  @objc public func inkBarButtonItemPressed(_ sender: ToolbarSelectableButton) {
    removeLaserLayer();
    removeStrokeBasedEraserLayer();
    for button in additionalButtons! {
      if button != sender {
        button.isSelected = false;
      }
    }
    
    // Toggle Individual actions on select of different tools
    switch sender.accessibilityLabel {
    case "laser":
      annotationStateManager.toggleState(.string3D);
      /** Toggle `isSelected` to toggle background color. */
      sender.isSelected = !sender.isSelected;
      if sender.isSelected {
        addLaserLayer(sender: sender);
      }
    case "eraser":
      annotationStateManager.setState(.eraser, variant: nil);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
        if strokeBasedEraserIsOn {
          addStrokeBasedEraserLayer();
        }
      } else {
        sender.isSelected = true;
      }
    case "inkPen":
      annotationStateManager.setState(.ink, variant: Annotation.Variant.inkPen);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "inkHighlighter":
      annotationStateManager.setState(.ink, variant: Annotation.Variant.inkHighlighter);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "selectionTool":
      if sender.isSelected {
        annotationStateManager.setState(nil, variant: nil);
        sender.isSelected = false;
      } else {
        annotationStateManager.setState(.selectionTool, variant: nil);
        sender.isSelected = true;
      }
    case "line":
      annotationStateManager.setState(.line, variant: nil);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "arrow":
      annotationStateManager.setState(.line, variant: Annotation.Variant.lineArrow);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "inkMagic":
      annotationStateManager.setState(.ink, variant: Annotation.Variant.inkMagic);
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "textHighlighter":
      annotationStateManager.setState(.highlight, variant: nil)
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "freeText":
      annotationStateManager.setState(.freeText, variant: nil)
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    case "note":
      if sender.isSelected {
        annotationStateManager.setState(nil, variant: nil)
        sender.isSelected = false;
      } else {
        annotationStateManager.setState(.note, variant: nil)
        sender.isSelected = true;
      }
    default:
      /** This is for handling the cloned tools, which has a dynamic accessibility label that is used as the variant's raw value. */
      annotationStateManager.setState(.ink, variant: Annotation.Variant(sender.accessibilityLabel ?? "clone"));
      if sender.isSelected {
        /** Show the style picker of the annotation tool. Also don't set `isSelected=false` */
        annotationStateManager.toggleStylePicker(sender, presentationOptions: nil);
      } else {
        sender.isSelected = true;
      }
    }
  }
  
  /** This is for adding the laser layer on top of the pdf view so that we can draw laser annotations. */
  @objc public func addLaserLayer(sender:ToolbarSelectableButton) {
    laserBrushView = LaserBrushView();
    laserBrushView.frame=(annotationStateManager.pdfController?.view.frame)!;
    annotationStateManager.pdfController?.view.addSubview(laserBrushView)
  }
  
  /** This is for removing the laser layer from the pdf view. */
  @objc public func removeLaserLayer() {
    laserBrushView.removeFromSuperview();
  }
  
  /** Unselects all the additional buttons. */
  @objc public func unselectAdditionalButtons() {
    for button in additionalButtons! {
      if button.isSelected {
        button.isSelected = false;
      }
    }
  }
  
  /**
   * =======================
   * Event handlers
   * =======================
   */
  
  @objc public func onToolBarChanged(_ notification: Notification?){
    logger.info("Toolbar changed")
    removeLaserLayer();
    removeStrokeBasedEraserLayer()
    unselectAdditionalButtons()
    annotationStateManager.setState(nil, variant: nil);
  }
  
  // MARK: - Clone and delete
  
  /**
   * Handles the `DeleteNewInk` event, fired from the `CustomAnnotationStyleViewController`
   * This removes the selected annotation tool from the toolbar.
   */
  @objc public func onDeletePressed(_ notification: Notification?) {
    /**
     * Find the index of the selected annotation tool
     * We can do this because this is called from the Delete button from the style picker of the currently selected tool.
     */
    if let index = additionalButtons?.firstIndex(where: {$0.isSelected == true}) {
      let item = additionalButtons?[index];
      let isHighighter = item?.currentImage == PSPDFKit.SDK.imageNamed("ink_highlighter");
      
      additionalButtons?.remove(at: index)
      self.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height-50);
      
      unselectAdditionalButtons();
      annotationStateManager.setState(nil, variant: nil);
      
      /** Unregister the deleted clone ink tool from the `userDefaults` array of `clonedButtons`  */
      var clonedButtonIds = userDefaults.array(forKey: self.CLONED_BUTTON_IDS_KEY) as? [String]
      /** Early exit if `clonedButtonIds` is already empty. */
      if clonedButtonIds == nil || clonedButtonIds!.isEmpty {
        return;
      }
      
      /** Finds the index of the button, then removes it from the `clonedButtonIds` */
      logger.info("clonedButtonIds before delete: \(clonedButtonIds?.joined(separator: ", "))");
      if let clonedButtonIndex = clonedButtonIds?.firstIndex(where: { $0 == item?.accessibilityLabel }) {
        logger.info("clonedButtonIndex: \(clonedButtonIndex)");
        clonedButtonIds?.remove(at: clonedButtonIndex);
        
        logger.info("clonedButtonIds after delete: \(clonedButtonIds?.joined(separator: ", "))");
        userDefaults.set(clonedButtonIds, forKey: self.CLONED_BUTTON_IDS_KEY);
      }
    }
  }
  
  /**
   * Handles the `CloneNewInk` event, fired from the `CustomAnnotationStyleViewController`
   * This creates a new ink or ink highlighter tool and adds it to the toolbar.
   */
  @objc public func onClonePressed(_ notification: Notification?) {
    /**
     * Find the index of the selected annotation tool
     * We can do this because this is called from the Clone button from the style picker of the currently selected tool.
     */
    logger.info("WILL clone pressed tool");
    
    if let index = additionalButtons?.firstIndex(where: {$0.isSelected == true}) {
      let item = additionalButtons?[index];
      let isHighlighter = item?.currentImage == PSPDFKit.SDK.imageNamed("ink_highlighter");
      
      let variantRawValue = notification?.object as! String;
      let variantId = UUID().uuidString + (isHighlighter ? "ink_highlighter" : "ink_pen");
      
      /** Adds the ink annotation tool. */
      let newInkButton = ToolbarSelectableButton();
      newInkButton.image = isHighlighter ? PSPDFKit.SDK.imageNamed("ink_highlighter") : PSPDFKit.SDK.imageNamed("ink");
      newInkButton.accessibilityLabel = variantId;
      newInkButton.addTarget(self, action: #selector(inkBarButtonItemPressed), for: .touchUpInside)
      
      if isHighlighter {
        initHighlighterLastUsed(variantId: variantId)
      } else {
        initInkLastUsed(variantId: variantId)
      }
      
      calculateIndicator(sender: newInkButton);
      additionalButtons?.insert(newInkButton, at: index + 1);
      
      unselectAdditionalButtons();
      
      /** Sets the cloned tool to enabled. */
      newInkButton.isSelected = true;
      annotationStateManager.setState(.ink, variant: Annotation.Variant(variantId));
      
      /** Registers the new clone ink tool to the `userDefaults` array of `clonedButtons`  */
      var clonedButtonIds = userDefaults.array(forKey: self.CLONED_BUTTON_IDS_KEY);
      /** Initialize the `clonedButtonIds` when `nil` */
      if clonedButtonIds == nil {
        clonedButtonIds = Array();
      }
      logger.info("onClonePressed adding variantId: " + variantId);
      /** Append the `variantId` of the `newInkButton` to the `clonedButtonIds` */
      clonedButtonIds?.append(variantId);
      userDefaults.set(clonedButtonIds, forKey: self.CLONED_BUTTON_IDS_KEY);
      
      logger.info("DID clone pressed tool");
    }
  }
  
  /**
   * Used when cloning a new ink pen tool.
   * Presets the styles of the passed `variantId` of the annotation tool.
   */
  @objc public func initInkLastUsed(variantId:String){
    let drawingColor = UIColor.blue
    let colorProperty = "color"
    let lineWidthProperty = "lineWidth"
    
    SDK.shared.styleManager.setLastUsedValue(drawingColor, forProperty: colorProperty, forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: variantId)))
    // Set line width of ink annotations.
    
    SDK.shared.styleManager.setLastUsedValue(3, forProperty: lineWidthProperty, forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: variantId)))
  }
  
  /**
   * Used when cloning a new ink highlighter tool.
   * Presets the styles of the passed `variantId` of the annotation tool.
   */
  @objc public func initHighlighterLastUsed(variantId:String){
    let highlightingColor = UIColor.yellow
    let colorProperty = "color"
    let alphaProperty = "alpha"
    let lineWidthProperty = "lineWidth"
    
    // Set highlight color.
    SDK.shared.styleManager.setLastUsedValue(highlightingColor, forProperty: colorProperty, forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: variantId)))
    SDK.shared.styleManager.setLastUsedValue(0.5, forProperty: alphaProperty, forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: variantId)))
    // Set line width of highlight annotations.
    SDK.shared.styleManager.setLastUsedValue(20, forProperty: lineWidthProperty, forKey: Annotation.ToolVariantID(tool: .ink, variant: Annotation.Variant(rawValue: variantId)))
  }
  
  // MARK: - Erase By Stroke
  
  @objc public func onEraseByStroke(_ notification: Notification?) {
    guard let pdfController = annotationStateManager.pdfController,
          let document = pdfController.document,
          let point = notification?.object as? CGPoint else {
      return
    }
    logger.info("point : x=\(point.x), y=\(point.y)")
    
    // Iterate over all visible pages and remove all editable annotations.
    for pageView in pdfController.visiblePageViews {
      //      let pointPdfSpace = pageView.convert(point, to: pageView.pdfCoordinateSpace)
      //      logger.RCTLogInfo("pointPdfSpace : x=\(pointPdfSpace.x), y=\(pointPdfSpace.y)")
      logger.info("pageView.visibleRect values: minX=\(pageView.visibleRect.minX), minY=\(pageView.visibleRect.minY) maxX=\(pageView.visibleRect.maxX), maxY=\(pageView.visibleRect.maxY)")
      
      
      logger.info("pdfController.view.bounds values: minX=\(pdfController.view.bounds.minX), minY=\(pdfController.view.bounds.minY) maxX=\(pdfController.view.bounds.maxX), maxY=\(pdfController.view.bounds.maxY)")
      
      let offsetX = (pageView.visibleRect.maxX - pdfController.view.bounds.maxX) / 2
      let offsetY = (pageView.visibleRect.maxY - pdfController.view.bounds.maxY) / 2
      logger.info("offsetX : \(offsetX)")
      logger.info("offsetY : \(offsetY)")
      
      let newPointX = point.x + offsetX
      let newPointY = point.y + offsetY
      
      let newPoint = CGPoint(x: newPointX, y: newPointY)
      logger.info("newPoint : x=\(newPoint.x), y=\(newPoint.y)")
      
      let annotations = document.annotationsForPage(at: pageView.pageIndex, type: editablAnnotationKind)
      //      document.remove(annotations: annotations)
      
      // Remove any annotation on the page as well (updates views).
      // Alternatively, you can call `reloadData` on the pdfController.
      for annotation in annotations {
        // Get the (normalized) PDF coordinates of the annotation.
        let annotationPDFRect = annotation.boundingBox
        // Convert the annotation's PDF coordinates to view coordinates.
        let annotationViewRect = pageView.convert(annotationPDFRect, from: pageView.pdfCoordinateSpace)
        
        if let points = annotation.points {
          for p in points {
            logger.info("annotation \(annotation.id) values: x=\(p.x), minY=\(p.y)")
          }
        }
        
        if let rects = annotation.rects {
          for rect in rects {
            logger.info("annotation \(annotation.id) values: minX=\(rect.minX), minY=\(rect.minY) maxX=\(rect.maxX), maxY=\(rect.maxY)")
          }
        }
        
        if annotationViewRect.contains(newPoint) {
          logger.info("annotation.boundingBox values: minX=\(annotation.boundingBox.minX), minY=\(annotation.boundingBox.minY) maxX=\(annotation.boundingBox.maxX), maxY=\(annotation.boundingBox.maxY)")
          logger.info("annotationViewRect values: minX=\(annotationViewRect.minX), minY=\(annotationViewRect.minY) maxX=\(annotationViewRect.maxX), maxY=\(annotationViewRect.maxY)")
          logger.info("annotationViewRect contains point: x=\(newPoint.x), y=\(newPoint.y)")
          //          pageView.remove(annotation, options: nil, animated: true)
          
          document.remove(annotations: [annotation])
        }
      }
    }
  }
  
  func getCirclePoints(centerPoint point: CGPoint, radius: CGFloat, n: Int)->[CGPoint] {
    let result: [CGPoint] = stride(from: 0.0, to: 360.0, by: Double(360 / n)).map {
      let bearing = CGFloat($0) * .pi / 180
      let x = point.x + radius * cos(bearing)
      let y = point.y + radius * sin(bearing)
      return CGPoint(x: x, y: y)
    }
    return result
  }
  
  func linesCross(start1: CGPoint, end1: CGPoint, start2: CGPoint, end2: CGPoint) -> (x: CGFloat, y: CGFloat)? {
    // calculate the differences between the start and end X/Y positions for each of our points
    let delta1x = end1.x - start1.x
    let delta1y = end1.y - start1.y
    let delta2x = end2.x - start2.x
    let delta2y = end2.y - start2.y
    
    // create a 2D matrix from our vectors and calculate the determinant
    let determinant = delta1x * delta2y - delta2x * delta1y
    
    if abs(determinant) < 0.0001 {
      // if the determinant is effectively zero then the lines are parallel/colinear
      return nil
    }
    
    // if the coefficients both lie between 0 and 1 then we have an intersection
    let ab = ((start1.y - start2.y) * delta2x - (start1.x - start2.x) * delta2y) / determinant
    
    if ab > 0 && ab < 1 {
      let cd = ((start1.y - start2.y) * delta1x - (start1.x - start2.x) * delta1y) / determinant
      
      if cd > 0 && cd < 1 {
        // lines cross – figure out exactly where and return it
        let intersectX = start1.x + ab * delta1x
        let intersectY = start1.y + ab * delta1y
        return (intersectX, intersectY)
      }
    }
    
    // lines don't cross
    return nil
  }
  
  private var editablAnnotationKind: Annotation.Kind {
    var kind = Annotation.Kind.all
    kind.remove(.link)
    kind.remove(.widget)
    return kind
  }
  
  @objc public func onToggleEraseByStroke(_ notification: Notification?) {
    let isOn = notification?.object as! Bool;
    logger.info("WILL toggle erase by stroke: " + String(isOn))
    strokeBasedEraserIsOn = isOn;
    if strokeBasedEraserIsOn {
      addStrokeBasedEraserLayer();
    } else {
      removeStrokeBasedEraserLayer();
    }
    logger.info("DID toggle erase by stroke: " + String(isOn))
  }
  
  /** This is for adding the laser layer on top of the pdf view so that we can draw laser annotations. */
  @objc public func addStrokeBasedEraserLayer() {
    strokeBasedEraserView = StrokeBasedEraserView()
    strokeBasedEraserView.inPage = annotationStateManager.pdfController?.visiblePageViews[0]
    strokeBasedEraserView.frame = (annotationStateManager.pdfController?.view.frame)!
    annotationStateManager.pdfController?.view.addSubview(strokeBasedEraserView)
  }
  
  /** This is for removing the laser layer from the pdf view. */
  @objc public func removeStrokeBasedEraserLayer() {
    strokeBasedEraserIsOn = false;
    strokeBasedEraserView.removeFromSuperview();
  }
  
  
  public override func annotationStateManager(_ manager: AnnotationStateManager, didChangeState oldState: Annotation.Tool?, to newState: Annotation.Tool?, variant oldVariant: Annotation.Variant?, to newVariant: Annotation.Variant?) {
    if oldState == .note || oldState == .selectionTool || oldState == .freeText {
      if newState == nil {
        unselectAdditionalButtons();
      }
    }
    
    super.annotationStateManager(manager, didChangeState: oldState, to: newState, variant: oldVariant, to: newVariant)
  }
  
  /** Observes the current style values and updates the indicator. */
  public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "lineWidth" || keyPath == "drawColor" {
      if annotationStateManager.state?.rawValue ?? ".ink" == Annotation.ToolVariantID(tool: .ink).rawValue && annotationStateManager.variant?.rawValue != "text" {
        /** Start updating the user preference display. */
        let button = additionalButtons?.first(where: { $0.isSelected == true })
        if button != nil {
          updateIndicator(sender: button as! ToolbarSelectableButton, lineWidth: annotationStateManager.lineWidth, drawColor: annotationStateManager.drawColor ?? UIColor.blue);
        }
      }
    }
  }
}

// MARK: - Annotation style view controller

/**
 * This is used for customizing the style picker.
 * 1. Removes the 'Blend Mode' under the style picker.
 * 2. Adds the 'Clone' option for cloning the currently selected ink of highlighter tool.
 * 3. Adds the 'Remove' option for removing the cloned ink or highlighter tool.
 * - disabled by default.
 * - only enabled on the cloned tool's style picker.
 */
public class CustomAnnotationStyleViewController: AnnotationStyleViewController
{
  let logger = RCTLog()
  var eraseByStrokeIsOn = false;
  
  /** Fires the `CloneNewInk` event. */
  @objc public func clonePressed(_ sender: UIButton) {
    let annotation = self.annotations?[0];
    if (annotation != nil) {
      NotificationCenter.default.post(name: Notification.Name.CloneNewInk, object: annotation?.variant?.rawValue)
    } else {
      NotificationCenter.default.post(name: Notification.Name.CloneNewInk, object: "")
    }
  }
  
  /** Fires the `DeleteNewInk` event. */
  @objc public func deletePressed(_ sender: UIButton) {
    let annotation = self.annotations?[0];
    if (annotation != nil) {
      NotificationCenter.default.post(name: Notification.Name.DeleteNewInk, object: annotation?.variant?.rawValue)
    } else {
      NotificationCenter.default.post(name: Notification.Name.DeleteNewInk, object: "")
    }
  }
  
  @objc public func toggleEraseByStroke(_ sender: UISwitch) {
    if let annotation = self.annotations?[0] {
      eraseByStrokeIsOn = sender.isOn
      logger.info("sending toggle erase by stroke: " + String(sender.isOn))
      NotificationCenter.default.post(name: Notification.Name.ToggleEraseByStroke, object: sender.isOn)
    }
  }
  
  /** Adds the "Clone" and "Delete" buttons on the style picker of the ink annotation tools except for the `inkMagic` variant.  */
  public override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    let footer = UIView();
    footer.backgroundColor = UIColor.clear;
    
    let annotation = self.annotations?[0]
    /**
     * Add a clone and delete button to the style picker of the `ink` and `inkHighlighter` tools.
     * Do nothing when the annotation tool is not an `ink` tool or a `inkMagic` tool.
     */
    if annotation?.typeString == .ink && annotation?.variant != Annotation.Variant.inkMagic {
      footer.frame = CGRect(x: 0, y: 0, width:350,height: 100);
      /** Divider before the Clone button */
      let line1 = UIView();
      line1.frame = CGRect(x: 15, y: 0, width: 350, height: 0.4);
      line1.backgroundColor = UIColor.lightGray;
      footer.addSubview(line1);
      
      /** Clone button */
      let clone = UIButton();
      clone.setTitle("Clone", for: .normal);
      clone.frame = CGRect(x: 15, y: 0, width: 350, height: 40);
      clone.tintColor = UIColor.black;
      clone.setTitleColor(.black, for: .normal)
      clone.addTarget(self, action: #selector(clonePressed), for: .touchUpInside)
      clone.contentHorizontalAlignment = .left;
      clone.backgroundColor = UIColor.clear;
      footer.addSubview(clone);
      
      /** Divider after the Clone button */
      let line2 = UIView();
      line2.frame = CGRect(x: 15, y: 41, width: 350, height: 0.3);
      line2.backgroundColor = UIColor.lightGray;
      footer.addSubview(line2);
      
      /** Delete button */
      let delete = UIButton();
      let annotation = self.annotations?[0]
      if annotation?.variant == Annotation.Variant.inkHighlighter || annotation?.variant == Annotation.Variant.inkPen {
        delete.isEnabled=false;
        delete.setTitleColor(.gray, for: .normal)
      } else {
        delete.isEnabled=true;
        delete.setTitleColor(.black, for: .normal)
      }
      
      delete.setTitle("Delete", for: .normal);
      delete.frame = CGRect(x: 15, y: 42, width: 350, height: 40);
      delete.tintColor = UIColor.black;
      delete.addTarget(self, action: #selector(deletePressed), for: .touchUpInside)
      
      delete.contentHorizontalAlignment = .left;
      delete.backgroundColor = UIColor.clear;
      footer.addSubview(delete);
    } else if annotation?.typeString == .eraser {
      footer.frame = CGRect(x: 0, y: 0, width: 350, height: 50)
      /** Divider before the Clone button */
      let line = UIView();
      line.frame = CGRect(x: 15, y: 0, width: 350, height: 0.4);
      line.backgroundColor = UIColor.lightGray;
      footer.addSubview(line);
      
      /** The label to the left of the toggle switch. */
      let toggleSwitchLabel = UILabel()
      toggleSwitchLabel.text = "Erase by Stroke"
      toggleSwitchLabel.frame = CGRect(x: 15, y: 0, width: 285, height: 50)
      toggleSwitchLabel.textAlignment = .left
      
      /** The toggle switch to the right of the label. */
      let toggleSwitch = UISwitch()
      toggleSwitch.isOn = eraseByStrokeIsOn
      toggleSwitch.frame = CGRect(x: 300, y: 10, width: 50, height: 30)
      toggleSwitch.addTarget(self, action: #selector(toggleEraseByStroke), for: .touchUpInside)
      toggleSwitch.center.y = toggleSwitchLabel.center.y
      footer.addSubview(toggleSwitch)
      footer.bringSubviewToFront(toggleSwitch)
      footer.addSubview(toggleSwitchLabel)
    }
    return footer;
  }
  
  /**
   * Determines whether the footer (container for the Clone and Delete buttons) should be displayed.
   * Show only on inkPen and inkHighlighter tools as we only want to allow users to clone only the inkPen and inkHighlighter tool.
   *
   * @returns
   * - `100` if it should be displayed, `0` if not.
   * - `1` as a special case for `inkMagic` tool as returning `0` makes the style picker width span the whole screen.
   */
  public override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    /**
     * This is to prevent rendering the Clone and Delete button twice in the style picker.
     */
    if section != 0 {
      return 0;
    }
    
    let annotation = self.annotations?[0]
    if annotation?.typeString == .ink && annotation?.variant != Annotation.Variant.inkMagic {
      return 100;
      
    } else if annotation?.typeString == .eraser {
      /**
       * TODO: Uncomment this to show stroke-based eraser toggle.
       */
      //      return 50;
      return 0;
    } else if annotation?.variant == Annotation.Variant.inkMagic {
      /**
       * Return `1` as a special case for `inkMagic` tool as returning 0 makes the style picker width span the whole screen.
       * TODO: Update this when there's a better solution to handling this.
       */
      return 1;
    } else {
      return 0;
    }
  }
  
  /**
   * Selects the properties to display on the style picker.
   *
   * This is used to filter out the "Blend Mode" in the style picker.
   * So that it only shows the following:
   *  - "Color" - `.color`
   *  - "Background Color" - `.fillColor`
   *  - "Opacity" - `.alpha`
   *  - "Thickness" - `.lineWidth`
   *  - "Font Size" - `.fontSize`
   *  - "Color Presets" - `.colorPreset`
   * @see https://pspdfkit.com/api/ios/documentation/pspdfkit/annotationstyle/key
   */
  public override func properties(for annotations: [Annotation]) -> [[AnnotationStyle.Key]] {
    // Allow show the color, opacity (alpha), font size, and thickness on the style picker.
    let supportedKeys: [AnnotationStyle.Key] = [.color, .fillColor, .alpha, .lineWidth, .fontSize, .colorPreset]
    return super.properties(for: annotations).map {
      $0.filter { $0 != .blendMode }
    }
  }
}
