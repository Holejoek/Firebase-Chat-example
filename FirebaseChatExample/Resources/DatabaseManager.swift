//
//  DatabaseManager.swift
//  FirebaseChatExample
//
//  Created by Иван Тиминский on 24.01.2022.
//

import Foundation
import FirebaseDatabase
import AVFoundation
import MessageKit
import CoreLocation

///Manager object to read and write data to
final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAdress: String) -> String{
        var safeEmail = emailAdress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}
extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}

//MARK: - AccountManager

extension DatabaseManager {
    /// Checks if user exists for given email
    /// Parameters
    /// - 'email':              Target email to be checked
    /// - 'completion':     Async closure to return with result
    public func userExists(with email: String, completion: @escaping ((Bool)-> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? [String: Any] != nil else {  // snapshot - данные из бд, если существуют по данному мылу
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// insert new users to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ]) { [weak self] error, _  in
            guard let strongSelf = self else { return }
            
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to user dictionary
                    let newElement =
                    ["name": user.firstName + " " + user.lastName,
                     "email": user.safeEmail]
                    
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                    
                } else {
                    //create array
                    let newCollection: [[String: String]] = [
                        ["name": user.firstName + " " + user.lastName,
                         "email": user.safeEmail]
                    ]
                    
                    strongSelf.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
            completion(true)
        }
    }
    public func getAllUsers(completion: @escaping(Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
}



//MARK: - Sending messages / conversations

extension DatabaseManager {
    /*
     "dasdasd" {
     "messsages": [
     {
     "id": String
     "type": text, photo, video,..
     "content": String,
     "date": Date(),
     "sender_email": String,
     "isRead": true/false,
     
     
     [
     [
     "conversation_id": "dasdasd"
     "other_user_email":
     "latest_message": => {
     "date": Data()
     "latest_message": "message:
     "is_read": true/false
     ],
     [
     "name":
     "safe_email""
     
     ]
     ]
     
     */
    /// Creates a new converssation with targer user email and first message
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String, let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            print("createNewConversation")
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAdress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
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
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message" : [
                    "date" : dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message" : [
                    "date" : dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    // create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            }
            
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                //conversation array exists for current user
                //you should append
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreateConversation(name: name,
                                                   conversationId: conversationId, firstMessage: firstMessage, completion: completion)
                }
            } else {
                //conversation array doesnt exists - create it
                
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreateConversation(name: name,
                                                   conversationId: conversationId, firstMessage: firstMessage, completion: completion)
                    
                }
            }
        }
    }
    
    private func finishCreateConversation(name: String, conversationId: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
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
     
        guard let rawCurrenUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAdress: rawCurrenUserEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationId)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Fetches and return all conversations for the user passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
        database.child("\(safeEmail)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap { dictionaty in
                guard let conversationID = dictionaty["id"] as? String,
                      let name = dictionaty["name"] as? String,
                      let otherUserEmail = dictionaty["other_user_email"] as? String,
                      let latestMessage = dictionaty["latest_message"] as? [String: Any],
                let date = latestMessage["date"] as? String,
                let message = latestMessage["message"] as? String,
                let isRead = latestMessage["is_read"] as? Bool else {
                    print("2")
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationID, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        }
        
    }
    /// Gets all messages for given conversation
    public func getAllMesagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { dictionaty in
                guard let name = dictionaty["name"] as? String,
                      let isRead = dictionaty["is_read"] as? Bool,
                      let messageId = dictionaty["id"] as? String,
                      let content = dictionaty["content"] as? String,
                      let senderEmail = dictionaty["sender_email"] as? String,
                      let type = dictionaty["type"] as? String,
                      let dateString = dictionaty["date"] as? String,
                      let date = ChatViewController.dateFormater.date(from: dateString) else {
                          return nil
                      }
                var kind: MessageKind?
                        
                if type == "photo" {
                    guard let imageUrl = URL(string: content), let placeholer = UIImage(systemName: "plus") else { return nil }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeholer, size: CGSize(width: 300, height: 300))
                    kind  = .photo(media)
                } else if type == "video" {
                    guard let videoUrl = URL(string: content), let placeholder = UIImage(systemName: "play.rectangle.fill") else { return nil }
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind  = .video(media)
                } else if type == "location" {
                    let locationComponent = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponent[0]),
                          let latitude = Double(locationComponent[1]) else {
                        return nil
                    }
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    kind  = .location(location)
                    
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date,
                               kind: finalKind)
            }
            completion(.success(messages))
        }
        
    }
    /// Sends a message with targer conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        // add new message to messages
        // update sender lates message
        // update recipient latest message
        guard let rawCurrentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAdress: rawCurrentEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                print("Failed to get currentMessages")
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
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                
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
         
            guard let rawCurrenUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAdress: rawCurrenUserEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    print(error)
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message,
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]]  {
                        
                        
                        var targerConversation: [String: Any]?
                        var position = 0
                        
                        for oneConversation in currentUserConversations {
                            if let currentId = oneConversation["id"] as? String, currentId == conversation {
                                targerConversation = oneConversation
                             break
                            }
                            position += 1
                        }
                        
                        if var targerConversation = targerConversation {
                            targerConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targerConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": otherUserEmail,
                                "name": name,
                                "latest_message" : updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                        
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": otherUserEmail,
                            "name": name,
                            "latest_message" : updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    
                    
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                    }
                    
                }
                
                //Update latest for recipient user
                
                strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message,
                    ]
                    var databaseEntryConversations = [[String: Any]]()
                    guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                        return
                    }

                    if var otherUserConversations = snapshot.value as? [[String: Any]]  {
                        var targerConversation: [String: Any]?
                        var position = 0
                        
                        for oneConversation in otherUserConversations {
                            if let currentId = oneConversation["id"] as? String, currentId == conversation {
                                targerConversation = oneConversation
                             break
                            }
                            position += 1
                        }
                        
                        if var targerConversation = targerConversation {
                            targerConversation["latest_message"] = updatedValue
                            otherUserConversations[position] = targerConversation
                            databaseEntryConversations = otherUserConversations
                            
                        } else {
                            // failed to find in current collection
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": currentUserEmail,
                                "name": currentName,
                                "latest_message" : updatedValue
                            ]
                            otherUserConversations.append(newConversationData)
                            databaseEntryConversations = otherUserConversations
                        }
                        
                        
                    } else {
                        //current collection doesnt exist
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": currentEmail,
                            "name": currentName,
                            "latest_message" : updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                   
                   
                    
                    strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                    }
                    completion(true)
                }
            }
        }
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
        let ref =  database.child("\(safeEmail)/conversations")
       ref.observeSingleEvent(of: .value) { snapshot in
           if var conversations = snapshot.value as? [[String: Any]] {
               var positionToRemove = 0
               for conversation in conversations {
                   if let id = conversation["id"] as? String,
                      id == conversationId {
                       break
                   }
                   positionToRemove += 1
               }
               conversations.remove(at: positionToRemove)
               ref.setValue(conversations) { error, _ in
                   guard error == nil else {
                       print("Failed to writr new conversation array")
                       completion(false)
                       return
                   }
                   print("deleted conversation::  \(conversations)")
                   completion(true)
               }
           }
        }
    }
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAdress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAdress: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            if let conversation = collection.first(where: {
                guard  let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get id convo
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        
        }
    }
    
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAdress: String
    
    
    var safeEmail: String {
        var safeEmail = emailAdress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
