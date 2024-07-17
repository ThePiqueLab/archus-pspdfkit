//
//  CustomTabbedViewController.swift
//  RCTPSPDFKit
//
//  Created by Yves Rupert Francisco on 7/17/24.
//  Copyright © 2024 Facebook. All rights reserved.
//

import Foundation
import PSPDFKit
import PSPDFKitUI

class CustomTabbedViewController: PDFTabbedViewController, PDFTabbedViewControllerDelegate {
  let backButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30));
  
  let base64String = "data:image/png;base64,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"
  
  public override func commonInit(withPDFController pdfController: PDFViewController?) {
    super.commonInit(withPDFController: pdfController)
    
    delegate = self
    
    logger.info("pdfController: \(String(describing: pdfController))")
    logger.info("self.pdfController: \(String(describing: self.pdfController))")
    
    //   var currentLeftBarButtons = self.navigationItem.leftBarButtonItems
    
    //  if let imageData = base64String.data(using: .utf8) {
    //    logger.info("imageData : \(imageData)")
    //    let closeButton = UIBarButtonItem()
    //    closeButton.tintColor = UIColor(red: 0.31, green: 0.33, blue: 0.48, alpha: 1.0)
    //    closeButton.image = UIImage(data: imageData)
    //    currentLeftBarButtons?.append(closeButton)
    //    self.navigationItem.backBarButtonItem = closeButton
    //  }
    
    //  self.navigationItem.setLeftBarButtonItems(currentLeftBarButtons, animated: false)
    
    let controller = self.pdfController
    
    logger.info("have controller \(controller)")
    
    var leftBarButtonItems = controller.navigationItem.leftBarButtonItems ?? []
    leftBarButtonItems.append(controller.closeButtonItem)
    self.navigationItem.setLeftBarButtonItems(leftBarButtonItems, animated: false)
    
    let rightBarButtonItems = controller.navigationItem.rightBarButtonItems
    self.navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: false)

    
    
//    let thumbnailsButtonItem = UIBarButtonItem(image: SDK.imageNamed("document_editor"), style: .plain, target: self, action: #selector(leaserButtonPressed(sender:)))
    
//    let shareButtonItem = UIBarButtonItem(image: SDK.imageNamed("share"), style: .plain, target: self, action: #selector(leaserButtonPressed(sender:)))
    
//    let annotationButtonItem = UIBarButtonItem(image: SDK.imageNamed("edit_annotations"), style: .plain, target: self, action: #selector(onAnnotationButtonPressed(sender:)))
////    let outlineButtonItem = UIBarButtonItem(image: SDK.imageNamed("outline"), style: .plain, target: self, action: #selector(leaserButtonPressed(sender:)))
//    let searchButtonItem = UIBarButtonItem(image: SDK.imageNamed("search"), style: .plain, target: self, action: #selector(leaserButtonPressed(sender:)))
//    let items = [
////      thumbnailsButtonItem,
////      searchButtonItem,
////      outlineButtonItem,
//      self.pdfController.annotationButtonItem,
//      self.pdfController.thumbnailsButtonItem,
//      imageItem
//    ]
    
//    self.pdfController.updateConfiguration(builder: {
//      $0.overrideClass(AnnotationToolbar.self, with: AnnotationToolbarWithClone.self)
//      $0.overrideClass(AnnotationStyleViewController.self, with: CustomAnnotationStyleViewController.self)
//    })
//    logger.info("self.pdfController.configuration: \(self.pdfController.configuration)")
    
    
//    self.pdfController.navigationItem.setRightBarButtonItems(items, for: .document, animated: false)
    
    /** Uncomment these lines to show the document picker. */
    let resourceUrl = Bundle.main.resourceURL!
    logger.info("Bundle.main.resourceURL: \(String(describing: resourceUrl))")
    
    documents = ["dummy.pdf", "dotted_landscape.pdf"].map {
      Document(url: URL(string: $0)!)
    }
    logger.info("documents: \(documents)")
//    documentPickerController = PDFDocumentPickerController(directory: resourceUrl?.path, includeSubdirectories: true, library: SDK.shared.library)
  }
  
}
