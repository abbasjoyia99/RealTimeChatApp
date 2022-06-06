//
//  NewConversationCell.swift
//  Messanger
//
//  Created by Developer on 02/06/2022.
//

import Foundation

import SDWebImage

class NewConversationCell: UITableViewCell {
    
    static let identifier = "NewConversationCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
        }()
    private let userNameLabel:UILabel = {
     let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
   
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        userImageView.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        userNameLabel.frame = CGRect(x: userImageView.rigth + 10, y: 20, width: contentView.width - 20, height:50)
        
        
    }
    public func configure(with model:SearchResult) {
        self.userNameLabel.text = model.name
        
        
        let path = "images/\(model.email)_profile_picture.png"
        
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
