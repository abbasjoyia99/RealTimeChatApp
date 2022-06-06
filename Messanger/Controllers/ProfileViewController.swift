//
//  ProfileViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SwiftUI
import SDWebImage


enum ProfileViewModelType {
    case info, logout
}
struct ProfileviewModel {
    let profileViewModelType: ProfileViewModelType
    let title:String
    let handler:(()->Void)?
}

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var tableView:UITableView!
    private var loginObserver:NSObjectProtocol?
    
    var data = [ProfileviewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        
        loginObserver =  NotificationCenter.default.addObserver(forName: .didLoginNotification, object: nil, queue: .main, using: {[weak self] _ in
           
            guard let strongSelf = self else {
                return
            }
            strongSelf.setProfileDataSource()
        })
        
        
        // Do any additional setup after loading the view.
    }
    
    deinit {
        if let loginObserver = loginObserver {
            NotificationCenter.default.removeObserver(loginObserver)
        }

    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    override func viewDidAppear(_ animated: Bool) {
        setProfileDataSource()
    }
    private func setProfileDataSource() {
        data.removeAll()
        data.append(ProfileviewModel(profileViewModelType: .info, title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")", handler: nil))
        data.append(ProfileviewModel(profileViewModelType: .info, title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")", handler: nil))
        data.append(ProfileviewModel(profileViewModelType: .logout, title: "Log Out", handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presetLogoutActionSheet()
        }))
        
        tableView.tableHeaderView = createHeaderView()
        self.tableView.reloadData()
    }
    func createHeaderView()->UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let filePath = "images/" + fileName
        
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame: CGRect(x:(headerView.width-150)/2 ,
                                                  y:75 ,
                                                  width: 150,
                                                  height: 150))
        
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.borderWidth = 3
        imageView.layer.cornerRadius = imageView.width/2
        imageView.layer.masksToBounds = true
        StorageManager.shared.downloadURL(with: filePath, completion: {  result in
            switch result {
            case . success( let url) :
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("fail : \(error)")
            }
        })
        headerView.addSubview(imageView)
                
        return headerView
    }
}

extension ProfileViewController:UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return data.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setup(with: data[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        data[indexPath.row].handler?()
    }
    func presetLogoutActionSheet() {
        let actionSheet = UIAlertController(title: "Messanger",
                                            message: "Are you sure you want to log Out?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log Out",
                                            style: .destructive,
                                            handler: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            UserDefaults.standard.setValue(nil, forKey: "email")
            UserDefaults.standard.setValue(nil, forKey: "name")
            // facebook logout
            FBSDKLoginKit.LoginManager().logOut()
            //Google logout
            GIDSignIn.sharedInstance.signOut()
            
            do {
                try FirebaseAuth.Auth.auth().signOut()
                let vc = LoginViewController()
                let navigationVC = UINavigationController(rootViewController: vc)
                navigationVC.modalPresentationStyle = .fullScreen
                navigationVC.navigationBar.isHidden = false
                strongSelf.present(navigationVC, animated: false, completion: nil)
            }
            catch {
                print("Failed to sign out")
            }
            
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet,animated: true)
    }
}

class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"
    
    func setup(with viewModel:ProfileviewModel) {
        
        self.textLabel?.text = viewModel.title
        switch viewModel.profileViewModelType {
        case.info :
            self.textLabel?.textAlignment = .left
            self.selectionStyle = .none
        case.logout :
            
            self.textLabel?.textAlignment = .center
            self.textLabel?.textColor = .red
        }
    }
}
