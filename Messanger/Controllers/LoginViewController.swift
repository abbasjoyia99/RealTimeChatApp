//
//  LoginViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import Firebase
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

class LoginViewController: UIViewController {
    private let scrollView :UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    private let logoImageView:UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.tintColor = .link
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton:UIButton = {
        let button = UIButton()
        button.setTitle("Sign In", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .link
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    private let faceBookLoginButton:FBLoginButton = {
        let button = FBLoginButton()
        button.backgroundColor = .link
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.permissions = ["email","public_profile"]
        return button
    }()
    private let googleLoginButton = GIDSignInButton()
    
    private let spinner = JGProgressHUD(style: .dark)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log In"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign Up", style: .done, target: self, action: #selector(didTabSignUp))
        loginButton.addTarget(self, action: #selector(loginButtonTabed), for: .touchUpInside)
        emailField.delegate = self
        passwordField.delegate = self
        faceBookLoginButton.delegate = self
        // googleLoginButton
        
        googleLoginButton.layer.cornerRadius = 12
        googleLoginButton.layer.masksToBounds = true
        googleLoginButton.style = .standard
        googleLoginButton.addTarget(self, action: #selector(didTabGoogleLoginButton), for: .touchUpInside)
        
        // Add subviews
        self.view.addSubview(scrollView)
        scrollView.addSubview(logoImageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(faceBookLoginButton)
        scrollView.addSubview(googleLoginButton)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = self.view.bounds
        let size = view.width/4
        logoImageView.frame = CGRect(x: (view.width-size)/2, y: 20, width:size , height: size)
        emailField.frame = CGRect(x: 30, y: logoImageView.bottom+10, width: scrollView.width-60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom+10, width: scrollView.width-60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom+10, width: scrollView.width-60, height: 52)
        faceBookLoginButton.frame = CGRect(x: 30, y: loginButton.bottom+10, width: scrollView.width-60, height: 52)
        googleLoginButton.frame = CGRect(x: 30, y: faceBookLoginButton.bottom+10, width: scrollView.width-60, height: 52)
    }
    
    @objc func loginButtonTabed() {
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else {
                  alertUserLoginError()
                  return
              }
        // Login with Firebase
        
        spinner.show(in: view)
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: { [weak self] authResult, error in
            
            guard let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard   error == nil else {
                print("Failed to login user with email:\(email)")
                return
            }
            let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
            DatabaseManager.shared.getData(with: safeEmail, completion: {  result in
                switch result {
                case .success(let data):
                    print("user information:\(data)")
                    guard let userData = data as? [String:Any],
                    let first_name = userData["first_name"] as? String,
                    let last_name = userData["last_name"] as? String else {
                        return
                    }
                    
                    UserDefaults.standard.setValue("\(first_name) \(last_name)", forKey: "name")
                    NotificationCenter.default.post(name: .didLoginNotification, object: nil)
                case.failure(let error):
                    print("failed to get user name with error:\(error)")
                }
                
            })
            UserDefaults.standard.setValue(email, forKey: "email")
            strongSelf.navigationController?.dismiss(animated: true)
        })
    }
    @objc func didTabGoogleLoginButton() {
        spinner.show(in: view)
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) { [weak self] user, error in
            
            if let error = error {
                print("goole log in failed with error:\(error)")
                return
            }
            DispatchQueue.main.async {
                self?.spinner.dismiss()
            }
            guard let email = user?.profile?.email ,
                  let firstName = user?.profile?.givenName,
                  let lastName = user?.profile?.familyName else {
                      return
                  }
            UserDefaults.standard.setValue(email, forKey: "email")
            UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
            DatabaseManager.shared.userExist(with: email, completion: { exist in
                if !(exist) {
                    
                    let chatUser = ChatUser(firstName: firstName,
                                            lastName: lastName,
                                            email: email)
                    DatabaseManager.shared.insertNewUser(user:chatUser,completion: { success in
                        if (success) {
                            guard let hasImage = user?.profile?.hasImage else {
                                return
                            }
                            if (hasImage) {
                                guard let url = user?.profile?.imageURL(withDimension: 200) else {
                                    return
                                }
                                URLSession.shared.dataTask(with: url, completionHandler: {
                                    data,_,_ in
                                    guard let  data = data else {
                                        return
                                    }
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: chatUser.profilePictureFileName, completion: { result in
                                        switch result {
                                        case .success(let url):
                                            print("download url:\(url)")
                                            UserDefaults.standard.setValue(url, forKey: "profile_picture_url")
                                        case .failure(let error):
                                            print("Storage error:\(error)")
                                        }
                                        
                                    })
                                }).resume()
                            }
                            
                        }
                        
                    } )
                }
                
            })
            guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
            else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                guard let strongSelf = self else { return }
                guard authResult != nil , error == nil else {
                    print("failed to sign in with credentials")
                    return
                }
                strongSelf.navigationController?.dismiss(animated:true, completion: nil)
            })
            
            
        }
    }
    func alertUserLoginError() {
        let alert = UIAlertController(title: "Oops", message: "Please enter all information to login...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler:nil))
        present(alert, animated: true)
    }
    @objc func didTabSignUp() {
        let vc = RegisteredViewController()
        vc.title = "Sign up"
        navigationController?.pushViewController(vc, animated: true)
    }
    
}

extension LoginViewController:UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField == emailField) {
            passwordField.becomeFirstResponder()
        }
        else if (textField == passwordField) {
            loginButtonTabed()
        }
        return true
    }
}

extension LoginViewController: LoginButtonDelegate {
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        
    }
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        
        guard let token = result?.token?.tokenString  else {
            print("Facebook login failed")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields":"email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token,
                                                         version: nil,
                                                         httpMethod: .get)
        
        
        facebookRequest.start(completion: { connection, result, error in
            
            guard let result = result as? [String:Any] , error == nil else {
                print("unable to get user name and email")
                return
            }
            guard let email = result["email"] as? String ,
                  let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let picture = result["picture"] as? [String:Any],
                  let data = picture["data"] as? [String:Any],
                  let pictureUrl = data["url"] as? String else {
                      return
                  }
            UserDefaults.standard.setValue(email, forKey: "email")
            UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
            DatabaseManager.shared.userExist(with: email, completion: {  exist in
                
                if !(exist) {
                    let user = ChatUser(firstName: firstName, lastName: lastName, email: email)
                    DatabaseManager.shared.insertNewUser(user:user, completion: { success in
                        if (success) {
                            guard let url = URL(string: pictureUrl) else {
                                return
                            }
                            URLSession.shared.dataTask(with: url, completionHandler: { data,_,_ in
                                guard let data = data else {
                                    return
                                }
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: user.profilePictureFileName, completion: { result in
                                    switch result {
                                    case .success(let url):
                                        print("download url:\(url)")
                                        UserDefaults.standard.setValue(url, forKey: "profile_picture_url")
                                    case .failure(let error):
                                        print("Storage error:\(error)")
                                    }
                                    
                                })
                            })
                            
                        }
                    } )
                }
            })
            let credentials = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credentials, completion: { [weak self] authResult, error in
                guard let strongSelf = self else { return }
                guard authResult != nil , error == nil else {
                    print("failed to sign in with credentials")
                    return
                }
                strongSelf.navigationController?.dismiss(animated:true, completion: nil)
            })
            
        })
        
    }
}
