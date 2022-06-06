//
//  NewConversationViewController.swift
//  Messanger
//
//  Created by Developer on 11/05/2022.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult)->Void)?
    private let spinner = JGProgressHUD(style: .dark)
    private var users = [[String:String]]()
    private var results = [SearchResult]()
    private var hasFetched = false
    private  var searchBar:UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return tableView
    }()
    private let noResultLabel: UILabel = {
        let label = UILabel()
        label.text = "No Results!"
        label.textColor = .green
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultLabel)
        view.addSubview(tableView)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.frame = self.view.bounds
        noResultLabel.frame = CGRect(x: 0, y: self.view.height/2, width: self.view.width, height: 20)
        
        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "Cancel",
                                                                 style: .done,
                                                                 target: self,
                                                                 action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
}
extension NewConversationViewController:UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell:NewConversationCell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    
}

extension NewConversationViewController:UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text , !text.replacingOccurrences(of: "", with: "").isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: self.view)
        self.searchUser(query: text)
    }
    func searchUser(query:String) {
        if (hasFetched) {
            self.filterUsers(with: query)
        } else {
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let users):
                    self?.hasFetched = true
                    self?.users = users
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("failed to get user: \(error)")
                }
                
            })
        }
    }
    func filterUsers(with terms:String) {
        
        guard  let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String ,hasFetched else {
            return
        }
        let safeEmail = DatabaseManager.getSafeEmail(emailAddress: currentUserEmail)
        
        let result:[SearchResult] = self.users.filter({
            guard let email = $0["email"],
                  email != safeEmail else {
                      return false
                  }
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            return name.hasPrefix(terms.lowercased())
        }).compactMap({
            guard let email = $0["email"], let name = $0["name"] else {
                return nil
            }
            return SearchResult(name:name , email: email)
        })
        self.results = result
        self.updateUI()
    }
    func updateUI() {
        self.spinner.dismiss(animated: true)
        if (results.isEmpty) {
            self.noResultLabel.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noResultLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetUser = self.results[indexPath.row]
        self.dismiss(animated: true, completion: { [weak self] in
            if (self?.completion != nil) {
                self?.completion!(targetUser)
            }
        })
    }
}


struct SearchResult {
    let name:String
    let email:String
}
