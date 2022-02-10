//
//  ViewController.swift
//  FirebaseChatExample
//
//  Created by Иван Тиминский on 24.01.2022.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class ConversationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation] ()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self , forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()

    private let noConversationLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTappedComposeButton))
        view.addSubview(tableView)
        setupTableView()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification,
                                               object: nil,
                                               queue: .main) { [weak self]_ in
            guard let strongSelf = self else { return }
            
            strongSelf.startListeningForConversations()
        }
        
    }
    
    private func startListeningForConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAdress: email)
        
        if let loginObserver = loginObserver {
            NotificationCenter.default.removeObserver(loginObserver)
        }
      
        DatabaseManager.shared.getAllConversations(for: safeEmail) { [weak self] result in
            switch result {
            case .success(let conversations):
                guard !conversations.isEmpty else {
                    self?.tableView.isHidden = true
                    self?.noConversationLabel.isHidden = false
                    return
                }
                self?.noConversationLabel.isHidden = true
                self?.tableView.isHidden = false
                self?.conversations = conversations
                print("GET ALL CONVERSATIONS hehrehrhehrhehr")
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationLabel.isHidden = false
                print("failed to get convos: \(error)")
            }
        }
    }
    
    @objc private func didTappedComposeButton() {
        let vc = NewCoversationViewController()
        vc.completion = {  [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentConversations = strongSelf.conversations
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAdress: result.email)
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            } else {
            strongSelf.createNewConversation(result: result)
            }
        
        }
        let navVc = UINavigationController(rootViewController: vc)
        present(navVc, animated: true, completion: nil)
    }
    
    private func createNewConversation(result: SearchResult) {   //  чтобы при создании чата заного не отображались старые собщения, надо добавить новое поле, которое будет отображать время создания сообщения и фильтровать его по времени открытия старого(удаленного чата)
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAdress: result.email) 
        // Check in database if conversation with this two users exists
        // if it does, reuse convId
        
        DatabaseManager.shared.conversationExists(with: email) { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                        vc.isNewConversation = false
                        vc.title = name
                        vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                        vc.isNewConversation = true
                        vc.title = name
                        vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        }
        
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationLabel.frame = CGRect(x: 10, y: (view.height-100)/2, width: view.width-20, height: 100)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        validateAuth()
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false, completion: nil)
            
        }
    }
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
   
    
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for:  indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
    }

    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.isNewConversation = false
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            DatabaseManager.shared.deleteConversation(conversationId: conversationId ) { success in
                if !success {
                  // add model and row back and show error alert
                }
            }
            
            
            tableView.endUpdates()
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
}

