//
//  ViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import FirebaseAuth

struct Conversation {
    let id:String
    let name:String
    let other_user_email:String
    let latestMessage: LatestMessage
}
struct LatestMessage {
    let date:String
    let text:String
    let isRead:Bool
}
class ConversationViewController: UIViewController {
    
    private var conversations = [Conversation]()
    private var loginObserver:NSObjectProtocol?
    
    private let tableVieview:UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.identifier)
        return tableView
    }()
    private let noConversationLabel: UILabel = {
        let label = UILabel()
        label.text = "No conversation!"
        label.textColor = .gray
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .compose,
                                                                 target: self,
                                                                 action: #selector(didTabCompose))
        
        self.view.addSubview(tableVieview)
        self.view.addSubview(noConversationLabel)
        self.setupTableView()
        startListingForConversation()
       
        
        loginObserver =  NotificationCenter.default.addObserver(forName: .didLoginNotification, object: nil, queue: .main, using: {[weak self] _ in
           
            guard let strongSelf = self else {
                return
            }
            strongSelf.startListingForConversation()
        })
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableVieview.frame = self.view.bounds
        self.noConversationLabel.textAlignment = .center
        self.noConversationLabel.frame = CGRect(x: 10, y: (view.height-100)/2, width: view.width-20, height: 100)
    }
    
    private func startListingForConversation() {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        if let loginObserver = loginObserver {
            NotificationCenter.default.removeObserver(loginObserver)
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversation(with: safeEmail, completion: { [weak self] result in
            
            switch result {
            case .failure(let error) :
                self?.tableVieview.isHidden = true
                self?.noConversationLabel.isHidden = false
                print("failed to get conversation for user with error: \(error)")
            case .success(let conversations) :
                guard !conversations.isEmpty else {
                    self?.tableVieview.isHidden = true
                    self?.noConversationLabel.isHidden = false
                    return
                }
                self?.noConversationLabel.isHidden = true
                self?.tableVieview.isHidden = false
                self?.conversations = conversations
                DispatchQueue.main.async {
                    self?.tableVieview.reloadData()
                }
            }
            
        })
    }
    @objc private func didTabCompose() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentConversations = strongSelf.conversations
           if let targerConversation = currentConversations.first(where: {
                $0.other_user_email == DatabaseManager.getSafeEmail(emailAddress: result.email)
            }) {
               let vc = ChatViewController(with: targerConversation.other_user_email, id: targerConversation.id)
               vc.isNewConversation = false
               vc.title = targerConversation.name
               vc.navigationItem.largeTitleDisplayMode = .never
               strongSelf.navigationController?.pushViewController(vc, animated: true)
           } else {
               self?.createNewConversation(result: result)
           }
            
        }
        let navVC = UINavigationController(rootViewController: vc)
        self.present(navVC, animated: true, completion:nil)
    }
    func createNewConversation(result:SearchResult) {
        let name = result.name
        let email = result.email
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: email)
        DatabaseManager.shared.conversationExist(with: safeEmail, completion: { [weak self]  result in
            switch result {
            case.success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                self?.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            
        })
        
        
    }
    func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let navigationVC = UINavigationController(rootViewController: vc)
            navigationVC.modalPresentationStyle = .fullScreen
            navigationVC.navigationBar.isHidden = false
            self.present(navigationVC, animated: false, completion: nil)
        }
    }
    private func setupTableView() {
        tableVieview.dataSource = self
        tableVieview.delegate = self
    }
   
}

extension ConversationViewController:UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.conversations.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.identifier, for: indexPath) as! ConversationCell
        cell.configure(with: self.conversations[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
       let model =  self.conversations[indexPath.row]
       openConversation(model)
    }
    func openConversation(_ model:Conversation) {
        let vc = ChatViewController(with: model.other_user_email, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.pushViewController(vc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if  editingStyle == .delete {
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            
            DatabaseManager.shared.deleteConversation(conversationId:conversationId , completion: { [weak self] success in
                if (success) {
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
                
            })
            
            
            tableView.endUpdates()
            
        }
    }
}
