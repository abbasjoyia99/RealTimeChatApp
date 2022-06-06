//
//  DatabaseManager.swift
//  Messanger
//
//  Created by Developer on 18/05/2022.
//

import Foundation
import FirebaseDatabase
import SwiftUI
import MessageKit
import CoreLocation

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func getSafeEmail(emailAddress:String) -> String {
        var email = emailAddress.replacingOccurrences(of: ".", with: "-")
        email = email.replacingOccurrences(of: "@", with: "-")
        return email
    }
    
}


extension DatabaseManager {
    public func getData(with path:String, completion:@escaping (Result<Any,Error>)->Void) {
        database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.faildedToFetchUsers))
                return
            }
            completion(.success(value))
        })
    }
}

//MARK: - User Management
extension DatabaseManager {
    /// validate user
    public func userExist(with email:String, completion:@escaping((Bool)->Void)) {
        
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard  snapshot.value as? [String:Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    /// insert new user to firebase database
    public  func insertNewUser(user:ChatUser, completion:@escaping (Bool)->Void) {
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: user.email)
        database.child(safeEmail).setValue(["first_name":user.firstName,
                                            "last_name":user.lastName],withCompletionBlock: { error ,_ in
            guard error == nil else {
                completion(false)
                return
            }
            self.database.child("users").observeSingleEvent(of: .value, with: { snapShot in
                if var usersCollection = snapShot.value as? [[String:String]] {
                    let newUser :[String:String] = ["name":user.firstName + " " + user.lastName,"email":user.safeEmail]
                    usersCollection.append(newUser)
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error,_ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    
                } else {
                    let newCollection :[[String:String]] = [["name":user.firstName + " " + user.lastName,
                                                             "email":user.safeEmail]]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error,_ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                
            })
            
        })
    }
    func getAllUsers(completion:@escaping (Result<[[String:String]],Error>)->Void) {
        self.database.child("users").observeSingleEvent(of: .value, with: { snapShot in
            guard let usersCollection = snapShot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.faildedToFetchUsers))
                return
            }
            completion(.success(usersCollection))
        })
    }
    public enum DatabaseError:Error {
        case faildedToFetchUsers
    }
}
//MARK: - Sending Messages / Conversation
extension DatabaseManager {
    /// create new conversation with targated user email and first message
    public func createNewConversation(with otherUserEmail:String,name:String, firstMessage:Message, completion:@escaping (Bool)->Void) {
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUserName = UserDefaults.standard.value(forKey: "name") as? String else {
                  completion(false)
                  return
              }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: currentUserEmail)
        
        let refrence = self.database.child("\(safeEmail)")
        
        refrence.observeSingleEvent(of: .value, with: { snapshot in
            
            guard var userNode = snapshot.value as? [String:Any] else {
                
                print("falied to get user ")
                completion(false)
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormater.string(from: messageDate)
            var message = ""
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationID = "conversation_\(firstMessage.messageId)"
            let newConversation:[String:Any] = ["id":conversationID,
                                                "other_user_email":otherUserEmail,
                                                "name":name,
                                                "latest_message":["date":dateString,
                                                                  "message":message,
                                                                  "isRead":false]]
            let recepitNewConversation:[String:Any] = ["id":conversationID,
                                                       "other_user_email":safeEmail,
                                                       "name":currentUserName,
                                                       "latest_message":["date":dateString,
                                                                         "message":message,
                                                                         "isRead":false]]
            // update receipient user entry
            self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapShot in
                if  var conversations = snapShot.value as? [[String:Any]] {
                    // append
                    conversations.append(recepitNewConversation)
                    self?.database.child("\(otherUserEmail)/conversations").setValue([conversations])
                } else {
                    //  create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recepitNewConversation])
                }
                
            })
            
            // Update current user conversation entry
            
            if var conversation = userNode["conversations"] as? [[String:Any]] {
                // conversation exist for current user
                // you should append conversation array
                conversation.append(newConversation)
                userNode["conversations"] = [conversation]
                refrence.setValue(userNode, withCompletionBlock: {[weak self] error,_ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationId: conversationID, firstMessage: firstMessage, completion: completion)
                })
                
            } else {
                // conversation array doest not exist
                userNode["conversations"] = [newConversation]
                refrence.setValue(userNode, withCompletionBlock: {[weak self] error,_ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationId: conversationID, firstMessage: firstMessage, completion: completion)
                })
            }
            
        })
        
    }
    private func finishCreatingConversation(name:String,conversationId:String, firstMessage:Message,completion:@escaping (Bool)->Void) {
        
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormater.string(from: messageDate)
        var message = ""
        switch firstMessage.kind {
            
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        let safeSenderEmail = DatabaseManager.getSafeEmail(emailAddress: senderEmail)
        let messages:[String:Any] = ["id":firstMessage.messageId,
                                     "type":firstMessage.kind.MessageKindString,
                                     "content":message,
                                     "date":dateString,
                                     "sender_email":safeSenderEmail,
                                     "is_Read":false,
                                     "name":name]
        let value :[String:Any] = ["messages":[messages]]
        database.child("\(conversationId)").setValue(value, withCompletionBlock: { error , _ in
            guard error == nil else {
                completion(false)
                return
            }
            
        })
    }
    /// fetch and retun all conversation with email for user
    public func getAllConversation(with email:String, completion:@escaping (Result<[Conversation],Error>)->Void) {
        
        database.child("\(email)/conversations").observe(.value, with: {
            snapShot in
            guard let conversationValue = snapShot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.faildedToFetchUsers))
                return
            }
            
            let conver:[Conversation] = conversationValue.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let other_user_email = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"]  as? [String:Any],
                      let date = latestMessage["date"] as? String,
                      let isRead = latestMessage["isRead"] as? Bool,
                      let message = latestMessage["message"] as? String else {
                          completion(.failure(DatabaseError.faildedToFetchUsers))
                          return nil
                      }
                let messageObject = LatestMessage(date:date,
                                                  text: message,
                                                  isRead: isRead)
                return Conversation(id: conversationId, name: name, other_user_email:other_user_email, latestMessage: messageObject)
            })
            
            completion(.success(conver))
        })
    }
    /// Fetch and return all messages for conversation with id
    public func getAllMessagesForConversation( with id:String ,completion:@escaping (Result<[Message],Error>)->Void){
        
        database.child("\(id)/messages").observe(.value, with: {
            snapShot in
            
            guard let conversationValue = snapShot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.faildedToFetchUsers))
                return
            }
            
            let messages:[Message] = conversationValue.compactMap({ dictionary in
                guard let messageId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let content = dictionary["content"]  as? String,
                      let dateString = dictionary["date"] as? String,
                      //  let isRead = dictionary["isRead"] as? Bool,
                      let type = dictionary["type"] as? String
                else {
                    completion(.failure(DatabaseError.faildedToFetchUsers))
                    return nil
                }
                var messageKind:MessageKind?
                if (type == "photo") {
                    let media = Media(url: URL(string: content),
                                      image: nil,
                                      placeholderImage: UIImage(systemName: "plus")!,
                                      size: CGSize(width: 300, height: 300))
                    messageKind = .photo(media)
                } else if (type == "video") {
                    let media = Media(url: URL(string: content),
                                      image: nil,
                                      placeholderImage: UIImage(named: "videoPlayPlaceholder")!,
                                      size: CGSize(width: 300, height: 300))
                    messageKind = .video(media)
                } else if (type == "location") {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                              return nil
                          }
                    let location = Location(location:CLLocation(latitude: latitude, longitude: longitude) ,
                                            size: CGSize(width: 300, height: 300))
                    messageKind = .location(location)
                    
                } else  {
                    messageKind = .text(content)
                }
                guard let finalKind = messageKind  else {
                    return nil
                }
                let date = ChatViewController.dateFormater.date(from: dateString) ?? Date()
                let sender = Sender(senderId: senderEmail, displayName: name, photoURL: "")
                
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalKind)
            })
            
            completion(.success(messages))
        })
    }
    /// send message with target conversation and message
    public func sendMessage(to conversationId:String,otherUserEmail:String ,name:String, newMessage:Message, completion:@escaping (Bool)->Void) {
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        database.child("\(conversationId)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var messagesArray = snapshot.value as? [[String:Any]] else {
                completion(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormater.string(from: messageDate)
            var message = ""
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let urlString = mediaItem.url?.absoluteString {
                    message = urlString
                }
                break
            case .video(let mediaItem):
                if let urlString = mediaItem.url?.absoluteString {
                    message = urlString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let safeSenderEmail = DatabaseManager.getSafeEmail(emailAddress: senderEmail)
            let messagesNewEntry:[String:Any] = ["id":newMessage.messageId,
                                                 "type":newMessage.kind.MessageKindString,
                                                 "content":message,
                                                 "date":dateString,
                                                 "sender_email":safeSenderEmail,
                                                 "is_Read":false,
                                                 "name":name]
            messagesArray.append(messagesNewEntry)
            strongSelf.database.child("\(conversationId)/messages").setValue(messagesArray, withCompletionBlock: { error,_ in
                guard error == nil else {
                    completion(false)
                    return
                }
                // Update current user latest message
                strongSelf.database.child("\(safeSenderEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversation = [[String:Any]]()
                    if var currentUserConversations = snapshot.value as? [[String:Any]] {
                        var isFound = false
                        for i in 0..<currentUserConversations.count {
                            let currentUserConversationDic = currentUserConversations[i]
                            if let id = currentUserConversationDic["id"] as? String, id == conversationId {
                                let messageToUpdate = ["date":dateString,
                                                       "isRead":false,
                                                       "message":message] as [String : Any]
                                currentUserConversations[i]["latest_message"] = messageToUpdate
                                databaseEntryConversation = currentUserConversations
                                isFound = true
                                break
                            }
                        }
                        
                        if !(isFound) {
                            let newConversation:[String:Any] = ["id":conversationId,
                                                                "other_user_email":DatabaseManager.getSafeEmail(emailAddress: otherUserEmail),
                                                                "name":name,
                                                                "latest_message":["date":dateString,
                                                                "message":message,
                                                                "isRead":false]]
                            currentUserConversations.append(newConversation)
                            databaseEntryConversation = currentUserConversations
                            
                        }
                        
                    } else {
        let newConversation:[String:Any] = ["id":conversationId,
                                            "other_user_email":DatabaseManager.getSafeEmail(emailAddress: otherUserEmail),
                                            "name":name,
                                            "latest_message":["date":dateString,
                                            "message":message,
                                            "isRead":false]]
                        databaseEntryConversation = [newConversation]
                    }
                    
                    
                    
                    strongSelf.database.child("\(safeSenderEmail)/conversations").setValue(databaseEntryConversation, withCompletionBlock: { error,_ in
                        
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        // update other user message
                        guard let currentUserName = UserDefaults.standard.value(forKey: "name") else {
                            return
                        }
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {  snapshot in
                            var databaseOtherUserEntryConversation = [[String:Any]]()
                            
                            let messageToUpdate = ["date":dateString,
                                                   "isRead":false,
                                                   "message":message] as [String : Any]
                            
                            if  var otherUserConversations = snapshot.value as? [[String:Any]]  {
                                var isFound = false
                                for i in 0..<otherUserConversations.count {
                                    let otherUserConversationDic = otherUserConversations[i]
                                    if let id = otherUserConversationDic["id"] as? String, id == conversationId {
                                        
                                        otherUserConversations[i]["latest_message"] = messageToUpdate
                                        databaseOtherUserEntryConversation = otherUserConversations
                                        isFound = true
                                        break
                                    }
                                }
                                
                                if !(isFound) {
                                    let newConversation:[String:Any] = ["id":conversationId,
                                                                        "other_user_email":DatabaseManager.getSafeEmail(emailAddress: senderEmail),
                                                                        "name":currentUserName,
                                                                        "latest_message":["date":dateString,
                                                                        "message":message,
                                                                        "isRead":false]]
                                    otherUserConversations.append(newConversation)
                                    databaseOtherUserEntryConversation = otherUserConversations
                                }
                                
                            } else {
                                let newConversation:[String:Any] = ["id":conversationId,
                                                                    "other_user_email":DatabaseManager.getSafeEmail(emailAddress: senderEmail),
                                                                    "name":currentUserName,
                                                                    "latest_message":["date":dateString,
                                                                    "message":message,
                                                                    "isRead":false]]
                                databaseOtherUserEntryConversation = [newConversation]
                            }
                            

                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseOtherUserEntryConversation, withCompletionBlock: { error,_ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                            
                        })
                        
                    })
                    
                })
                
                
                
            })
        })
    }
    
    public func deleteConversation(conversationId:String, completion:@escaping (Bool)->Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        print("deleting conversation with id:\(conversationId)")
        let refrence = self.database.child("\(safeEmail)/conversations")
        refrence.observeSingleEvent(of: .value, with: {  snapshot in
            if var conversations = snapshot.value as? [[String:Any]] {
                var positionToRemove = 0
                
                for conversation in  conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        print("found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                refrence.setValue(conversations, withCompletionBlock: { error,_ in
                    guard  error == nil else {
                        print("failed to write updated conversation")
                        completion(false)
                        return
                    }
                    print("deleted conversation")
                    completion(true)
                })
            }
            
        })
    }
    public func conversationExist(with targetRecipeintEmail:String, completion:@escaping (Result<String,Error>)->Void) {
        
        let safeRecipientEmail = DatabaseManager.getSafeEmail(emailAddress: targetRecipeintEmail)
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(.failure(DatabaseError.faildedToFetchUsers))
            return
        }
        _ = DatabaseManager.getSafeEmail(emailAddress: currentUserEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.faildedToFetchUsers))
                return
            }
            
            if  let targetConversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    completion(.failure(DatabaseError.faildedToFetchUsers))
                    return  false
                }
                return targetRecipeintEmail == targetSenderEmail
            }) {
                guard let id = targetConversation["id"] as? String else  {
                    completion(.failure(DatabaseError.faildedToFetchUsers))
                    return
                }
                completion(.success(id))
            }
            completion(.failure(DatabaseError.faildedToFetchUsers))
            return
        })
    }
}
