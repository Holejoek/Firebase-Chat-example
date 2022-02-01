//
//  StorageManager.swift
//  FirebaseChatExample
//
//  Created by Иван Тиминский on 31.01.2022.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    /*
     /images/eggman-gmail-com_picture.png
     */
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Upload picture to firebase and returns with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping  UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            guard error == nil else {
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    print("failedToGetDownloadUrl")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))

            })
        })
    }
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadUrl
        
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL,Error>) -> Void){
        let reference = storage.child(path)
        
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            
            completion(.success(url))

        }
    }
    
}
