//
//  PhotoViewerViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import SDWebImage
class PhotoViewerViewController: UIViewController {
    
    private let url:URL
    
    private let imageView:UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    init(with url:URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(imageView)
        title = "Photo"
        view.backgroundColor = .black
        navigationItem.largeTitleDisplayMode = .never
        imageView.sd_setImage(with: url, completed: nil)
        // Do any additional setup after loading the view.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = self.view.bounds
    }
    
}
