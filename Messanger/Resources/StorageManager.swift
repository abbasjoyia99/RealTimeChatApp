//
//  StorageManager.swift
//  Messanger
//
//  Created by Developer on 25/05/2022.
//

import Foundation
import FirebaseStorage
import SwiftUI

final class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    
    public typealias UplpadPictureCompletion = (Result<String,Error>)->Void
    /// upload profile picture
    public func uploadProfilePicture(with data:Data, fileName:String, completion: @escaping UplpadPictureCompletion) {
        
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            
            guard  error == nil else {
                print("Failed to upload profile picture")
                completion(.failure(StorageError.failedToUploadPicture))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: { profileUrl , error in
                guard error == nil else {
                    print("failed to download profile picture")
                    completion(.failure(StorageError.failedToDownloadPicture))
                    return
                }
                
                guard let url = profileUrl?.absoluteString else {
                    completion(.failure(StorageError.failedToGetUrl))
                    return
                }
                completion(.success(url))
            })
        })
        
    }
    /// upload photo into conversation message
    public func uploadMessagePhoto(with data:Data, fileName:String, completion: @escaping UplpadPictureCompletion) {
        
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            
            guard  error == nil else {
                print("Failed to upload profile picture")
                completion(.failure(StorageError.failedToUploadPicture))
                return
            }
            
            self.storage.child("message_images/\(fileName)").downloadURL(completion: { profileUrl , error in
                guard error == nil else {
                    print("failed to download profile picture")
                    completion(.failure(StorageError.failedToDownloadPicture))
                    return
                }
                
                guard let url = profileUrl?.absoluteString else {
                    completion(.failure(StorageError.failedToGetUrl))
                    return
                }
                completion(.success(url))
            })
        })
        
    }
    /// upload Video into conversation message
    public func uploadMessageVideo(with videoUrl:URL, fileName:String, completion: @escaping UplpadPictureCompletion) {
        
        do {
            let data = try Data(contentsOf: videoUrl)
            self.storage.child("message_videos/\(fileName)").putData(data , metadata: nil, completion: { metadata, error in
                
                guard  error == nil else {
                    print("Failed to upload Video")
                    completion(.failure(StorageError.failedToUploadPicture))
                    return
                }
                
                self.storage.child("message_videos/\(fileName)").downloadURL(completion: { profileUrl , error in
                    guard error == nil else {
                        print("failed to download video")
                        completion(.failure(StorageError.failedToDownloadPicture))
                        return
                    }
                    
                    guard let url = profileUrl?.absoluteString else {
                        completion(.failure(StorageError.failedToGetUrl))
                        return
                    }
                    completion(.success(url))
                })
            })
        } catch let error {
            print(error.localizedDescription)
            completion(.failure(StorageError.failedToUploadPicture))
        }
    }
    
    public enum StorageError:Error {
        case failedToUploadPicture
        case failedToDownloadPicture
        case failedToGetUrl
        
    }
    public func downloadURL(with path:String, completion:@escaping (Result<URL,Error>)-> Void) {
        
        let refrence = storage.child(path)
        refrence.downloadURL(completion: { url, error in
            guard let url = url , error == nil else {
                completion(.failure(StorageError.failedToGetUrl))
                return
            }
            
            completion(.success(url))
        })
    }
}
