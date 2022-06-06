//
//  ChatViewController.swift
//  Messanger
//
//  Created by Developer on 20/05/2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

struct Message:MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}
struct Media:MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location:LocationItem {
    var location: CLLocation
    var size: CGSize
}
extension MessageKind {
    var MessageKindString:String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedString"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contactItem"
        case .linkPreview(_):
            return "link"
        case .custom(_):
            return "custom"
        }
        
        
    }
}

struct Sender:SenderType {
    
    public var senderId: String
    public var displayName: String
    public var photoURL:String
}
class ChatViewController: MessagesViewController {
    
    public static var dateFormater:DateFormatter  {
        let formater = DateFormatter()
        formater.dateStyle = .medium
        formater.timeStyle = .long
        formater.locale = .current
        return formater
    }
    
    public var isNewConversation = false
    private let otherUserEmail:String!
    private var conversationId:String?
    private var messages = [Message]()
    
    private var senderPhotoUrl:URL?
    private var otherUserPhotoUrls:URL?
    
    private var selfSender:Sender?  {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        return Sender(senderId: safeEmail,
                      displayName: "Me",
                      photoURL: "")
    }
    init(with email:String,id:String?) {
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInputBarButton()
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
    }
    private func setupInputBarButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({ [weak self] _ in
            self?.presentInputSheetAction()
            
        })
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    private func presentInputSheetAction() {
        let actionsheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        actionsheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.photoInputActionSheet()
        }))
        actionsheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self]  _ in
            self?.videoInputActionSheet()
        }))
        actionsheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {  _ in
            
        }))
        actionsheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {[weak self]  _ in
            self?.presentLocationPicker()
        }))
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionsheet, animated: true)
    }
    override func viewWillAppear(_ animated: Bool) {
        
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            self.listenForMessages(id: conversationId)
        }
    }
    private func presentLocationPicker() {
        let vc = LocationViewController(coordinates: nil)
        vc.title = "Pick Location"
        vc.completion = { [weak self] selectedLocation in
            
            guard let strongSelf = self else {
                return
            }
            let longitude:Double = selectedLocation.longitude
            let latitude:Double = selectedLocation.latitude
            
            guard let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender,
                  let messageId = strongSelf.createMessageId() else {
                      return
                  }
            
            let location = Location(location:
                                        CLLocation(latitude: latitude, longitude: longitude),
                                    size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationId,
                                               otherUserEmail: strongSelf.otherUserEmail,
                                               name: name,
                                               newMessage: message,
                                               completion: { success in
                if (success) {
                    print("Sent location message")
                } else {
                    print("failed to send location message")
                }
                
            })
            
        }
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    private func listenForMessages(id:String) {
        DatabaseManager.shared.getAllMessagesForConversation(with:id , completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                }
            case.failure(let error) :
                print("failed to load messages error:\(error)")
            }
            
        })
    }
    
}
extension ChatViewController:InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: "", with: "").isEmpty, let selfSender = self.selfSender, let messageId = self.createMessageId() else {
            return
        }
        // send message
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        if (self.isNewConversation) {
            // create new conversation
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message, completion: { [weak self] success in
                
                if (success) {
                    self?.messageInputBar.inputTextView.text = nil
                    self?.isNewConversation = false
                    let newConversationid = "conversations_\(messageId)"
                    self?.conversationId = newConversationid
                    self?.listenForMessages(id: newConversationid)
                    print("message sent")
                } else {
                    print("failed to sent message")
                }
            })
        } else {
            // append existing conversation
            guard let conversationId = conversationId else {
                return
            }
            DatabaseManager.shared.sendMessage(to:conversationId, otherUserEmail: otherUserEmail, name: self.title ?? "User" , newMessage: message, completion:{  [weak self] success in
                if (success) {
                    self?.isNewConversation = false
                    self?.messageInputBar.inputTextView.text = nil
                    print("message sent")
                } else {
                    print("failed to sent message")
                }
                
            })
        }
    }
    func createMessageId() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormater.string(from: Date())
        let newIdentifier = "\(self.otherUserEmail ?? "")_\(safeEmail)_\(dateString)"
        return newIdentifier
    }
}

extension ChatViewController:MessagesLayoutDelegate,MessagesDataSource,MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is nill, email should be cashed")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return self.messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        switch message.kind {
        case .photo(let media) :
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default :
            break
        }
   
    }
    
}
extension ChatViewController:MessageCellDelegate {
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = self.messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = self.messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData) :
            let vc = LocationViewController(coordinates:locationData.location.coordinate )
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
       
        default :
            break
        }
    }
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = self.messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = self.messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media) :
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media) :
            guard let videoUrl = media.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default :
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // current user
            return .link
        }
        return .secondarySystemBackground
    }
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // current user photo
            if let currentUserPhotoUrl = self.senderPhotoUrl {
                avatarView.sd_setImage(with: currentUserPhotoUrl, completed: nil)
            } else {
                // download photo
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
                let filePath = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(with:filePath , completion: { result in
                    switch result {
                    case.success(let url) :
                        self.senderPhotoUrl = url
                        avatarView.sd_setImage(with: url, completed: nil)
                    case.failure(let error) :
                        print("failed to get current user image url:\(error)")
                    }
                    
                })
            }
        } else {
            // other user photo
            if let otherUserPhotoUrl = self.otherUserPhotoUrls {
                avatarView.sd_setImage(with: otherUserPhotoUrl, completed: nil)
            } else {
                // download photo
                let safeEmail = DatabaseManager.getSafeEmail(emailAddress: otherUserEmail)
                let filePath = "images/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(with:filePath , completion: { result in
                    switch result {
                    case.success(let url) :
                        self.senderPhotoUrl = url
                        avatarView.sd_setImage(with: url, completed: nil)
                    case.failure(let error) :
                        print("failed to get other user image url:\(error)")
                    }
                    
                })
            }

        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func videoInputActionSheet() {
        let alertSheet = UIAlertController(title: "Attach Video",
                                           message: "Where would you like to attach video from?",
                                           preferredStyle: .actionSheet)
        alertSheet.addAction(UIAlertAction(title: "Cancel",
                                           style: .cancel,
                                           handler: nil))
        alertSheet.addAction(UIAlertAction(title: "Camera",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentVideoCamera()
        }))
        alertSheet.addAction(UIAlertAction(title: "Galery",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentVideoGalery()
        }))
        present(alertSheet,animated: true)
    }
    func photoInputActionSheet() {
        let alertSheet = UIAlertController(title: "Attach Photo",
                                           message: "Where would you like to attach photo from?",
                                           preferredStyle: .actionSheet)
        alertSheet.addAction(UIAlertAction(title: "Cancel",
                                           style: .cancel,
                                           handler: nil))
        alertSheet.addAction(UIAlertAction(title: "Camera",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentPhotoCamera()
        }))
        alertSheet.addAction(UIAlertAction(title: "Galery",
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.presentPhotoGalery()
        }))
        present(alertSheet,animated: true)
    }
    
    func presentPhotoCamera() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .camera
        present(pickerVC,animated: true)
    }
    func presentPhotoGalery() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .photoLibrary
        present(pickerVC,animated: true)
    }
    
    func presentVideoCamera() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .camera
        pickerVC.mediaTypes = ["public.movie"]
        pickerVC.videoQuality = .typeMedium
        present(pickerVC,animated: true)
    }
    func presentVideoGalery() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        pickerVC.allowsEditing = true
        pickerVC.sourceType = .photoLibrary
        pickerVC.mediaTypes = ["public.movie"]
        pickerVC.videoQuality = .typeMedium
        present(pickerVC,animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = self.createMessageId() else {
                  return
            }
        
        if let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as?  UIImage, let imageData = selectedImage.pngData() {
            // upload image
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "_") + ".png"
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                
                switch result {
                case.success(let urlString):
                    print("uploaded photo:\(urlString)")
                    guard let strongSelf = self,
                          let conversationId = self?.conversationId,
                          let name = self?.title,
                          let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus"),
                          let selfSender = self?.selfSender else {
                              return
                          }
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       name: name,
                                                       newMessage: message,
                                                       completion: { success in
                        if (success) {
                            print("photo sent")
                        } else {
                            print("failed to send photo")
                        }
                        
                    })
                case.failure(let error):
                    print("message photo upload failed:\(error)")
                }
                
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
            // upload Video
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "_") + ".mov"
    
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
                switch result {
                case.success(let urlString):
                    print("uploaded video url:\(urlString)")
                    guard let strongSelf = self,
                          let conversationId = self?.conversationId,
                          let name = self?.title,
                          let url = URL(string: urlString),
                          let placeHolder = UIImage(systemName: "plus"),
                          let selfSender = self?.selfSender else {
                              return
                          }
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeHolder,
                                      size: .zero)
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       name: name,
                                                       newMessage: message,
                                                       completion: { success in
                        if (success) {
                            print("video sent")
                        } else {
                            print("failed to send video")
                        }
                        
                    })
                case.failure(let error):
                    print("message photo upload failed:\(error)")
                }
                
            })
        }
        
        
        
        // send message
        
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
