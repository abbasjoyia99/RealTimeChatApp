//
//  ConversationCell.swift
//  Messanger
//
//  Created by Developer on 30/05/2022.
//

import UIKit
import SDWebImage

class ConversationCell: UITableViewCell {
    
    static let identifier = "ConversationCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        return imageView
        }()
    private let userNameLabel:UILabel = {
     let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    private let messageLabel:UILabel = {
     let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 19, weight: .regular)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(messageLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        userImageView.frame = CGRect(x: 10, y: 10, width: 100, height: 100)
        userNameLabel.frame = CGRect(x: userImageView.rigth + 10, y: 10, width: contentView.width - 20, height:(contentView.height-20)/2)
        messageLabel.frame = CGRect(x: userImageView.rigth + 10, y: userNameLabel.bottom + 10, width: contentView.width - 20, height:(contentView.height-20)/2)
        
    }
    public func configure(with model:Conversation) {
        self.userNameLabel.text = model.name
        self.messageLabel.text = model.latestMessage.text
        
        let path = "images/\(model.other_user_email)_profile_picture.png"
        
        StorageManager.shared.downloadURL(with: path, completion: { [weak self] result in
            switch result {
            case .failure(let error) :
                print("failed to get image\(error)")
            case.success(let url) :
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url, completed: nil)
                }
            }
            
        })
    }
}
