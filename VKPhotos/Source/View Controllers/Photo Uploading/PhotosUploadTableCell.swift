//
//  PhotosUploadingTableCell.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 13/06/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos

protocol PhotosUploadingCellDelegate: class {
    func addCaptionButtonTapped(_ cell: PhotosUploadTableCell)
    func retryButtonTapped(_ cell: PhotosUploadTableCell)
}

class PhotosUploadTableCell: UITableViewCell {
    @IBOutlet weak var photoPreview: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!

    @IBOutlet weak var addCaptionButton: UIButton!
    @IBOutlet weak var retryButton: UIButton!

    @IBOutlet weak var progressBackgroundView: UIView!
    @IBOutlet weak var progressBackgroundViewWidthConstraint: NSLayoutConstraint! {
        didSet {
            progressBackgroundViewWidthConstraint.constant = 0
        }
    }

    @IBAction func addCaptionButtonTap(_ sender: UIButton) {
        delegate?.addCaptionButtonTapped(self)
    }

    @IBAction func retryButtonTap(_ sender: UIButton) {
        delegate?.retryButtonTapped(self)
    }

    weak var delegate: PhotosUploadingCellDelegate?

    private let STATUS_MESSAGE_QUEUE = "Waiting".localized() + "..."
    private let STATUS_MESSAGE_UPLOADING = "Uploading".localized() + "..."
    private let STATUS_MESSAGE_DONE = "Finished".localized()
    private let STATUS_MESSAGE_ERROR = "Error".localized()

    override func prepareForReuse() {
        photoPreview.image = nil
        retryButton.isHidden = true
        addCaptionButton.isEnabled = false
        progressBackgroundView.alpha = 0
    }

    func updateProgressBar(_ value: Float, animated: Bool = true) {
        let total = bounds.size.width
        let progressWidth = CGFloat((value * 100.0) * Float(total / 100))

        guard animated else {
            progressBackgroundViewWidthConstraint.constant = progressWidth
            layoutIfNeeded()
            return
        }

        UIView.animate(withDuration: 0.175, animations: { [weak self] in
            self?.progressBackgroundViewWidthConstraint.constant = progressWidth
            self?.layoutIfNeeded()
        })
    }

    func updateStatus(_ status: UploadPhotoTaskStatus) {
        retryButton.isHidden = status != .error

        switch status {
        case .done:
            statusLabel.text = STATUS_MESSAGE_DONE
            statusLabel.textColor = .black
            addCaptionButton.isEnabled = true

            UIView.animate(withDuration: 0.9) { [weak self] in
                self?.progressBackgroundView.alpha = 0
            }
        case .ready:
            statusLabel.text = STATUS_MESSAGE_QUEUE
            statusLabel.textColor = .black
            progressBackgroundView.alpha = 1
        case .error:
            statusLabel.text = STATUS_MESSAGE_ERROR
            statusLabel.textColor = .red
            progressBackgroundView.alpha = 1
        case .inProgress:
            statusLabel.text = STATUS_MESSAGE_UPLOADING
            statusLabel.textColor = .black
            progressBackgroundView.alpha = 1
        }
    }

    func updateUIByTask(_ task: UploadPhotoTask) {
        retryButton.isHidden = task.status != .error
        addCaptionButton.isEnabled = task.status == .done
        updateProgressBar(task.progress, animated: false)

        switch task.status {
        case .error:
            statusLabel.text = STATUS_MESSAGE_ERROR
            statusLabel.textColor = .red
            progressBackgroundView.alpha = 1
        case .inProgress:
            statusLabel.text = STATUS_MESSAGE_UPLOADING
            statusLabel.textColor = .black
            progressBackgroundView.alpha = 1
        case .ready:
            statusLabel.text = STATUS_MESSAGE_QUEUE
            statusLabel.textColor = .black
            progressBackgroundView.alpha = 1
        case .done:
            statusLabel.text = STATUS_MESSAGE_DONE
            progressBackgroundView.alpha = 0
        }
    }
}
