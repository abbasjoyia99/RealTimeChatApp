//
//  RegisteredViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import Firebase
import JGProgressHUD

class RegisteredViewController: UIViewController {
    
    private let scrollView :UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    private let logoImageView:UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle")
        imageView.tintColor = .gray
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        return imageView
    }()
    private let firstNameField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "First Name..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    private let lastNameField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Last Name..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
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
    
    private let signUpButton:UIButton = {
        let button = UIButton()
        button.setTitle("Sign Up", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    private let spinner = JGProgressHUD(style: .dark)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign Up"
        view.backgroundColor = .systemBackground
        signUpButton.addTarget(self, action: #selector(didTabSignUp), for: .touchUpInside)
        firstNameField.delegate = self
        lastNameField.delegate = self
        emailField.delegate = self
        passwordField.delegate = self
        
        scrollView.isUserInteractionEnabled = true
        logoImageView.isUserInteractionEnabled = true
        
        let tabGesture = UITapGestureRecognizer(target: self, action: #selector(didTabProfilePicChange))
        tabGesture.numberOfTapsRequired = 1
        logoImageView.addGestureRecognizer(tabGesture)
        
        // Add subviews
        self.view.addSubview(scrollView)
        scrollView.addSubview(logoImageView)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(lastNameField)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(signUpButton)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = self.view.bounds
        let size = view.width/3
        logoImageView.frame = CGRect(x: (view.width-size)/2, y: 20, width:size , height: size)
        logoImageView.layer.cornerRadius = logoImageView.width/2.0
        
        firstNameField.frame = CGRect(x: 30, y: logoImageView.bottom+10, width: scrollView.width-60, height: 52)
        lastNameField.frame = CGRect(x: 30, y: firstNameField.bottom+10, width: scrollView.width-60, height: 52)
        emailField.frame = CGRect(x: 30, y: lastNameField.bottom+10, width: scrollView.width-60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom+10, width: scrollView.width-60, height: 52)
        signUpButton.frame = CGRect(x: 30, y: passwordField.bottom+10, width: scrollView.width-60, height: 52)
    }
    @objc func  didTabProfilePicChange() {
        imagePickingOptionSheet()
    }
    @objc func didTabSignUp() {
        guard let email = emailField.text ,
              let password = passwordField.text,
              let firstName = firstNameField.text,
              let lastName = lastNameField.text,
              !email.isEmpty,
              !password.isEmpty,password.count >= 6,
              !firstName.isEmpty,
              !lastName.isEmpty else {
                  self.alertSignUpError(message: "Please fill all information to Sign Up...")
                  return
              }
        UserDefaults.standard.setValue(email, forKey: "email")
        UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
        spinner.show(in: view)
        // Register on Firebase
        DatabaseManager.shared.userExist(with: email, completion: { [weak self] exist in
            guard !exist else {
                // User already exist
                self?.alertSignUpError(message: "Looks like user already registered with this email:\(email)")
                return
            }
            
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: { [weak self] authResult, error in
                guard let strongSelf = self else { return}
                DispatchQueue.main.async {
                    strongSelf.spinner.dismiss()
                }
                guard  authResult != nil , error == nil else {
                    
                    self?.alertSignUpError(message: "Failed to create user with email:\(email)")
                    return
                }
                let user = ChatUser(firstName: firstName, lastName: lastName, email: email)
                DatabaseManager.shared.insertNewUser(user: user,completion: { success in
                    if (success) {
                        guard let image = strongSelf.logoImageView.image,
                              let data = image.pngData() else {
                                  return
                              }
                       
                      // upload image
                        StorageManager.shared.uploadProfilePicture(with: data, fileName: user.profilePictureFileName, completion: { result in
                            switch result {
                            case .success(let url):
                                print("download url:\(url)")
                                UserDefaults.standard.setValue(url, forKey: "profile_picture_url")
                            case .failure(let error):
                                print("Storage error:\(error)")
                            }
                            
                        })
                    }
                    
                })
                NotificationCenter.default.post(name: .didLoginNotification, object: nil)
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        })

    }
    func alertSignUpError(message:String) {
        let alert = UIAlertController(title: "Oops",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true)
    }
    
}

extension RegisteredViewController:UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == firstNameField {
            lastNameField.becomeFirstResponder()
        }
        else if textField == lastNameField {
            emailField.becomeFirstResponder()
        } else if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            didTabSignUp()
        }
        return true
    }
}

extension RegisteredViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickingOptionSheet() {
        let alertSheet = UIAlertController(title: "Messanger",
                                           message: "How would you like to choose image",
                                           preferredStyle: .actionSheet)
        alertSheet.addAction(UIAlertAction(title: "Cancel",
                                           style: .cancel,
                                           handler: nil))
        alertSheet.addAction(UIAlertAction(title: "Camera",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentCamera()
        }))
        alertSheet.addAction(UIAlertAction(title: "Galery",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentGalery()
        }))
        present(alertSheet,animated: true)
    }
    func presentCamera() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .camera
        present(pickerVC,animated: true)
    }
    func presentGalery() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .photoLibrary
        present(pickerVC,animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as?  UIImage else {
            return
        }
        logoImageView.image = selectedImage
        
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
