//
//  MediaGridCell.swift
//  MediaBrowser
//
//  Created by Seungyoun Yi on 2017. 9. 6..
//  Copyright © 2017년 Seungyoun Yi. All rights reserved.
//

import UIKit
import DACircularProgress

public class MediaGridCell: UICollectionViewCell {
    let videoIndicatorPadding = CGFloat(10.0)
    
    var index = 0
    var selectionMode = false
    
    private let imageView = UIImageView()
    private let videoIndicator = UIImageView()
    private var loadingError: UIImageView?
	private let loadingIndicator = DACircularProgressView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    private let selectedButton = UIButton(type: .custom)
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        // Grey background
        backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        
        // Image
        imageView.frame = self.bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        imageView.autoresizesSubviews = true
        
        addSubview(imageView)
        
        // Video Image
        videoIndicator.isHidden = false
        let videoIndicatorImage = UIImage.imageForResourcePath(
            name: "VideoOverlay",
            inBundle: Bundle(for: MediaGridCell.self))!
            
        videoIndicator.frame = CGRect(
            x: self.bounds.size.width - videoIndicatorImage.size.width - videoIndicatorPadding,
            y: self.bounds.size.height - videoIndicatorImage.size.height - videoIndicatorPadding,
            width: videoIndicatorImage.size.width,
            height: videoIndicatorImage.size.height)
        
        videoIndicator.image = videoIndicatorImage
        videoIndicator.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        videoIndicator.autoresizesSubviews = true
        addSubview(videoIndicator)
        
        // Selection button
        selectedButton.contentMode = UIViewContentMode.topRight
        selectedButton.adjustsImageWhenHighlighted = false

        selectedButton.setImage(
            UIImage.imageForResourcePath(
                name: "ImageSelectedSmallOff",
                inBundle: Bundle(for: MediaGridCell.self)),
            for: .normal)

        selectedButton.setImage(UIImage.imageForResourcePath(
                name: "ImageSelectedSmallOn",
                inBundle: Bundle(for: MediaGridCell.self)),
            for: .selected)

        selectedButton.addTarget(self, action: #selector(MediaGridCell.selectionButtonPressed), for: .touchDown)
        selectedButton.isHidden = true
        selectedButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        addSubview(selectedButton)
    
        // Loading indicator
        loadingIndicator.isUserInteractionEnabled = false
        loadingIndicator.thicknessRatio = 0.1
        loadingIndicator.roundedCorners = 0
        addSubview(loadingIndicator)
        
        // Listen for photo loading notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setProgressFromNotification),
            name: NSNotification.Name(rawValue: MWPHOTO_PROGRESS_NOTIFICATION),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoLoadingDidEndNotification),
            name: NSNotification.Name(rawValue: MWPHOTO_LOADING_DID_END_NOTIFICATION),
            object: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private weak var mwGridController: MediaGridViewController?

    var gridController: MediaGridViewController? {
        set(gridCtl) {
            mwGridController = gridCtl
        
            if let gc = gridCtl {
                // Set custom selection image if required
                if let browser = gc.browser {
                    if browser.customImageSelectedSmallIconName.characters.count > 0 {
                        selectedButton.setImage(UIImage(named: browser.customImageSelectedSmallIconName), for: .selected)
                    }
                }
            }
        }
        
        get {
            return mwGridController
        }
    }

    //MARK: - View

    public override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds
        
        loadingIndicator.frame = CGRect(x: CGFloat(floorf(Float(bounds.size.width - loadingIndicator.frame.size.width) / 2.0)),
                                        y: CGFloat(floorf(Float(bounds.size.height - loadingIndicator.frame.size.height) / 2.0)),
                                        width: loadingIndicator.frame.size.width,
                                        height: loadingIndicator.frame.size.height)
        
        selectedButton.frame = CGRect(x: bounds.size.width - selectedButton.frame.size.width,
                                      y: 0.0,
                                      width: selectedButton.frame.size.width,
                                      height: selectedButton.frame.size.height)
    }

    //MARK: - Cell

    public override func prepareForReuse() {
        photo = nil
        mwGridController = nil
        imageView.image = nil
        loadingIndicator.progress = 0
        selectedButton.isHidden = true
        hideImageFailure()
        
        super.prepareForReuse()
    }

    //MARK: - Image Handling

    private var Media: Media?

    var photo: Media? {
        set(p) {
            Media = p
            
            if let ph = p {
                videoIndicator.isHidden = !ph.isVideo
                
                if nil == ph.underlyingImage {
                    showLoadingIndicator()
                }
                else {
                    hideLoadingIndicator()
                }
            }
            else {
                showImageFailure()
            }
        }
        
        get {
            return Media
        }
    }

    func displayImage() {
        if let p = Media {
            imageView.image = p.underlyingImage
            selectedButton.isHidden = !selectionMode
            self.hideImageFailure()
        }
    }

    //MARK: - Selection

    public override var isSelected: Bool {
        set(sel) {
            super.isSelected = sel
            selectedButton.isSelected = sel
        }
        
        get {
            return super.isSelected
        }
    }

    func selectionButtonPressed() {
        selectedButton.isSelected = !selectedButton.isSelected
        
        if let gc = gridController {
            if let browser = gc.browser {
                browser.setPhotoSelected(selected: selectedButton.isSelected, atIndex: index)
            }
        }
    }

    //MARK: - Touches

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        imageView.alpha = 0.6
        super.touchesBegan(touches, with: event)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        imageView.alpha = 1
        super.touchesEnded(touches, with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        imageView.alpha = 1
        super.touchesCancelled(touches!, with: event)
    }

    //MARK: - Indicators

    private func hideLoadingIndicator() {
        loadingIndicator.isHidden = true
    }

    private func showLoadingIndicator() {
        loadingIndicator.progress = 0
        loadingIndicator.isHidden = false
        
        hideImageFailure()
    }

    private func showImageFailure() {
        // Only show if image is not empty
        if let p = photo, p.emptyImage {
            if nil == loadingError {
                let error = UIImageView()
                error.image = UIImage.imageForResourcePath(
                    name: "ImageError",
                    inBundle: Bundle(for: MediaGridCell.self))
        
                error.isUserInteractionEnabled = false
                error.sizeToFit()
            
                addSubview(error)
                loadingError = error
            }
            
            if let e = loadingError {
                e.frame = CGRect(
                    x: CGFloat(floorf(Float(bounds.size.width - e.frame.size.width) / 2.0)),
                    y: CGFloat(floorf(Float(bounds.size.height - e.frame.size.height) / 2.0)),
                    width: e.frame.size.width,
                    height: e.frame.size.height)
            }
        }
        
        hideLoadingIndicator()
        imageView.image = nil
    }

    private func hideImageFailure() {
        if loadingError != nil {
            loadingError!.removeFromSuperview()
            loadingError = nil
        }
    }

    //MARK: - Notifications

    public func setProgressFromNotification(notification: NSNotification) {
        if let dict = notification.object as? [String : AnyObject?],
            let photoWithProgress = dict["photo"] as? Media,
            let mwp = Media, photosEqual(p1: photoWithProgress, mwp)
        {
            if let progress = dict["progress"] as? String,
                let progressVal =  NumberFormatter().number(from: progress)
            {
                DispatchQueue.main.async() {
                    self.loadingIndicator.progress = CGFloat(max(min(1.0, progressVal.floatValue), 1.0))
                    return
                }
            }
        }
    }

    public func handlePhotoLoadingDidEndNotification(notification: NSNotification) {
        if let p = notification.object as? Media,
            let mwp = Media, photosEqual(p1: p, mwp)
        {
            if p.underlyingImage != nil {
                // Successful load
                displayImage()
            }
            else {
                // Failed to load
                showImageFailure()
            }
            
            hideLoadingIndicator()
        }
    }
    
    private func photosEqual(p1: Media, _ p2: Media) -> Bool {
        return
            p1.underlyingImage == p2.underlyingImage &&
            p1.emptyImage == p2.emptyImage &&
            p1.isVideo == p2.isVideo &&
            p1.caption == p2.caption
    }
}