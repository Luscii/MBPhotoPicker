//
//  MBPhotoPicker.swift
//  MBPhotoPicker
//
//  Created by Marcin Butanowicz on 02/01/16.
//  Copyright © 2016 MBSSoftware. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices

@objc open class MBPhotoPicker: NSObject {
    
    // MARK: Localized strings
    @objc open var alertTitle: String? = "Alert title"
    
    @objc open var alertMessage: String? = "Alert message"
    
    @objc open var actionTitleCancel: String = "Action Cancel"
    
    @objc open var actionTitleTakePhoto: String = "Action take photo"
    
    @objc open var actionTitleLastPhoto: String = "Action last photo"
    
    @objc open var actionTitleOther: String = "Action other"
    
    @objc open var actionTitleLibrary: String = "Action Library"
    
    
    // MARK: Photo picker settings
    @objc open var allowDestructive: Bool = false
    
    @objc open var allowEditing: Bool = false
    
    @objc open var disableEntitlements: Bool = false
    
    @objc open var cameraDevice: UIImagePickerController.CameraDevice = .rear
    
    @objc open var cameraFlashMode: UIImagePickerController.CameraFlashMode = .auto
    
    open var resizeImage: CGSize?
    
    /**
     Using for iPad devices
     */
    @objc open var popoverTarget: UIView?
    
    open var popoverRect: CGRect?
    
    @objc open var popoverDirection: UIPopoverArrowDirection = .any
    
    /**
     List of callbacks variables
     */
    @objc open var photoCompletionHandler: ((_ image: UIImage?) -> Void)?
    
    @objc open var presentedCompletionHandler: (() -> Void)?
    
    @objc open var cancelCompletionHandler: (() -> Void)?
    
    @objc open var errorCompletionHandler: ((_ error: ErrorPhotoPicker) -> Void)?
    
    @objc open var otherCompletionHandler: (() -> Void)?
    
    /**
     Customization colors
     */
    @objc open var alertTintColor: UIColor!
    
    // MARK: Error's definition
    @objc public enum ErrorPhotoPicker: Int {
        case cameraNotAvailable
        case libraryNotAvailable
        case accessDeniedCameraRoll
        case entitlementiCloud
        case wrongFileType
        case popoverTargetMissing
        case other
        
        public func name() -> String {
            switch self {
            case .cameraNotAvailable: return "Camera not available"
            case .libraryNotAvailable: return "Library not available"
            case .accessDeniedCameraRoll: return "Access denied to camera roll"
            case .entitlementiCloud: return "Missing iCloud Capatability"
            case .wrongFileType: return "Wrong file type"
            case .popoverTargetMissing: return "Missing property popoverTarget while iPad is run"
            case .other: return "Other"
            }
        }
    }
    
    // MARK: Public
    @objc open func present() -> Void {
        let topController = UIApplication.shared.windows.first?.rootViewController
        present(topController!)
    }
    
    @objc open func present(_ controller: UIViewController!) -> Void {
        self.controller = controller
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .actionSheet)
        
        if (alertTintColor != nil) {
            alert.view.tintColor = alertTintColor!
        }
        
        let actionTakePhoto = UIAlertAction(title: self.localizeString(actionTitleTakePhoto), style: .default, handler: { (alert: UIAlertAction!) -> Void in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.presentImagePicker(.camera, topController: controller)
            } else {
                self.errorCompletionHandler?(.cameraNotAvailable)
            }
        })
        
        alert.addAction(actionTakePhoto)
        
        let actionLibrary = UIAlertAction(title: self.localizeString(actionTitleLibrary), style: .default, handler: { (alert: UIAlertAction!) -> Void in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                self.presentImagePicker(.photoLibrary, topController: controller)
            } else {
                self.errorCompletionHandler?(.libraryNotAvailable)
            }
        })
        
        alert.addAction(actionLibrary)
        
        let actionLast = UIAlertAction(title: self.localizeString(actionTitleLastPhoto), style: .default, handler: { (alert: UIAlertAction!) -> Void in
            self.lastPhotoTaken({ (image) -> Void in self.photoHandler(image) },
                errorHandler: { (error) -> Void in self.errorCompletionHandler?(.accessDeniedCameraRoll) }
            )
        })
        
        alert.addAction(actionLast)
        
        if !self.disableEntitlements {
            let actionOther = UIAlertAction(title: self.localizeString(actionTitleOther), style: allowDestructive ? .destructive : .default, handler: { (alert: UIAlertAction!) -> Void in
                //                let document = UIDocumentMenuViewController(documentTypes: [kUTTypeImage as String, kUTTypeJPEG as String, kUTTypePNG as String, kUTTypeBMP as String, kUTTypeTIFF as String], inMode: .Import)
                //                document.delegate = self
                //                controller.presentViewController(document, animated: true, completion: nil)
                self.otherCompletionHandler?()
            })
            
            alert.addAction(actionOther)
        }
        
        
        let actionCancel = UIAlertAction(title: self.localizeString(actionTitleCancel), style: .cancel, handler: { (alert: UIAlertAction!) -> Void in
            self.cancelCompletionHandler?()
        })
        
        alert.addAction(actionCancel)
        
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let popover = self.popoverTarget else {
                self.errorCompletionHandler?(.popoverTargetMissing)
                return;
            }
            
            if let presenter = alert.popoverPresentationController {
                alert.modalPresentationStyle = .popover
                presenter.sourceView = popover;
                presenter.permittedArrowDirections = self.popoverDirection
                
                if let rect = self.popoverRect {
                    presenter.sourceRect = rect
                } else {
                    presenter.sourceRect = popover.bounds
                }
            }
        }
        
        controller.present(alert, animated: true) { () -> Void in
            self.presentedCompletionHandler?()
        }
    }
    
    // MARK: Private
    internal weak var controller: UIViewController?
    
    var imagePicker: UIImagePickerController!
    func presentImagePicker(_ sourceType: UIImagePickerController.SourceType, topController: UIViewController!) {
        imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = self
        imagePicker.isEditing = self.allowEditing
        if sourceType == .camera {
            imagePicker.cameraDevice = self.cameraDevice
            if UIImagePickerController.isFlashAvailable(for: self.cameraDevice) {
                imagePicker.cameraFlashMode = self.cameraFlashMode
            }
        }
        topController.present(imagePicker, animated: true, completion: nil)
    }
    
    func photoHandler(_ image: UIImage!) -> Void {
        let resizedImage: UIImage = UIImage.resizeImage(image, newSize: self.resizeImage)
        self.photoCompletionHandler?(resizedImage)
    }
    
    func localizeString(_ string: String!) -> String! {
        var localizedString = string
        let podBundle = Bundle(for: self.classForCoder)
        if let bundleURL = podBundle.url(forResource: "MBPhotoPicker", withExtension: "bundle") {
            if let bundle = Bundle(url: bundleURL) {
                localizedString = NSLocalizedString(string, tableName: "Localizable", bundle: bundle, value: "", comment: "")
            } else {
                assertionFailure("Could not load the bundle")
            }
        }
        
        return localizedString!
    }
}

extension MBPhotoPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { () -> Void in
            self.cancelCompletionHandler?()
        }
    }
    
    @objc public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] {
            self.photoHandler(image as! UIImage)
        } else {
            self.errorCompletionHandler?(.other)
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    @objc public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension MBPhotoPicker: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        var error: NSError?
        let filerCordinator = NSFileCoordinator()
        filerCordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error, byAccessor: { (url: URL) -> Void in
            if let data: Data = try? Data(contentsOf: url) {
                if data.isSupportedImageType() {
                    if let image: UIImage = UIImage(data: data) {
                        self.photoHandler(image)
                    } else {
                        self.errorCompletionHandler?(.other)
                    }
                } else {
                    self.errorCompletionHandler?(.wrongFileType)
                }
            } else {
                self.errorCompletionHandler?(.other)
            }
        })
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.cancelCompletionHandler?()
    }
}

extension MBPhotoPicker: UIDocumentMenuDelegate {
    public func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        self.controller?.present(documentPicker, animated: true, completion: nil)
    }
    
    public func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController) {
        self.cancelCompletionHandler?()
    }
}


extension MBPhotoPicker {
    internal func lastPhotoTaken (_ completionHandler: @escaping (_ image: UIImage?) -> Void, errorHandler: @escaping (_ error: NSError?) -> Void) {
        
        PHPhotoLibrary.requestAuthorization { (status: PHAuthorizationStatus) -> Void in
            if (status == PHAuthorizationStatus.authorized) {
                let manager = PHImageManager.default()
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: true)]
                let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
                let asset: PHAsset? = fetchResult.lastObject as PHAsset?
                
                let initialRequestOptions = PHImageRequestOptions()
                initialRequestOptions.isSynchronous = true
                initialRequestOptions.resizeMode = .fast
                initialRequestOptions.deliveryMode = .fastFormat
                
                manager.requestImageData(for: asset!, options: initialRequestOptions) { (data: Data?, title: String?, orientation: UIImage.Orientation, info: [AnyHashable: Any]?) -> Void in
                    guard let dataImage = data else {
                        errorHandler(nil)
                        return
                    }
                    
                    let image:UIImage = UIImage(data: dataImage)!
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        completionHandler(image)
                    })
                }
            } else {
                errorHandler(nil)
            }
        }
    }
}

extension UIImage {
    static public func resizeImage(_ image: UIImage!, newSize: CGSize?) -> UIImage! {
        guard var size = newSize else { return image }
        
        let widthRatio = size.width/image.size.width
        let heightRatio = size.height/image.size.height
        
        let ratio = min(widthRatio, heightRatio)
        size = CGSize(width: image.size.width*ratio, height: image.size.height*ratio)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        image.draw(in: CGRect(origin: CGPoint.zero, size: size))
        
        let scaledImage: UIImage! = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
}

extension Data {
    public func isSupportedImageType() -> Bool {
        var c = [UInt32](repeating: 0, count: 1)
        (self as NSData).getBytes(&c, length: 1)
        switch (c[0]) {
        case 0xFF, 0x89, 0x00, 0x4D, 0x49, 0x47, 0x42:
            return true
        default:
            return false
        }
    }
}

