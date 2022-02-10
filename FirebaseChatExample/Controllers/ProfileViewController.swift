//
//  ProfileViewController.swift
//  FirebaseChatExample
//
//  Created by Иван Тиминский on 24.01.2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage


final class ProfileViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var data = [ProfileViewModel]()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        data.append(ProfileViewModel(viewModelType: .info, title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "noName")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No email")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            guard let strongSelf = self else { return }
            let actionSheet = UIAlertController(title: "",
                                                message: "",
                                                preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Log Out",
                                                style: .destructive, handler: { [weak self] _ in
        
                guard let strongSelf = self else { return }
                
                UserDefaults.standard.setValue(nil, forKey: "email")
                UserDefaults.standard.setValue(nil, forKey: "name")
                
                
                // Log out Facebook
                FBSDKLoginKit.LoginManager().logOut()
                
                // Log out google
                
                GIDSignIn.sharedInstance.signOut()
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true, completion: nil)
                } catch {
                    print("Failed to log out")
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            strongSelf.present(actionSheet, animated: true)
            
        }))
        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            print("Create tableview Header error")
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/"+fileName
        
        
        let headerView = UIView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: self.view.width,
                                        height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (headerView.width-150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.cornerRadius = imageView.width/2
        imageView.layer.masksToBounds = true
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        }
        return headerView
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}

final class ProfileTableViewCell: UITableViewCell {
    static let identifier = "ProfileTableViewCell"
    
    public func setUp(with viewModel: ProfileViewModel) {
        textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .center
        }
    }
}
