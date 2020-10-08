//
//  WalletManagerViewController.swift
//  BitSense
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var walletTable: UITableView!
    var didChange = Bool()
    let connectingView = ConnectingView()
    var activeWallets = [String]()
    var inactiveWallets = [String]()
    var wallets = [[String:Any]]()
    var walletsToUnload:[String] = []
    
    let ud = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        walletTable.delegate = self
        walletTable.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        refresh()
    }
    
    @IBAction func addWallet(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "addWallet", sender: self)
        }
    }
    
    @IBAction func unloadAction(_ sender: Any) {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        Reducer.makeCommand(command: .listwallets, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let loadedWallets = response as? NSArray else {
                self.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them: \(errorMessage ?? "")")
                return
            }
            
            for (i, w) in loadedWallets.enumerated() {
                if (w as! String) != "" {
                    self.walletsToUnload.append(w as! String)
                }
                if i + 1 == loadedWallets.count {
                    guard self.walletsToUnload.count > 0 else {
                        self.connectingView.removeConnectingView()
                        showAlert(vc: self, title: "Only the Default Wallet is loaded", message: "You can not unload the default wallet.")
                        return
                    }
                    
                    self.goUnload()
                }
            }
        }
    }
    
    
    
    func refresh() {
        connectingView.addConnectingView(vc: self, description: "getting wallets...")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.activeWallets.removeAll()
            self.inactiveWallets.removeAll()
            self.wallets.removeAll()
            self.walletTable.reloadData()
            Reducer.makeCommand(command: .listwalletdir, param: "") { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let dict = response as? NSDictionary else {
                    DispatchQueue.main.async { [weak self] in
                         guard let self = self else { return }
                        
                        self.connectingView.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: "error getting wallets: \(errorMessage ?? "")")
                    }
                    return
                }
                
                self.parseWallets(walletDict: dict)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        let toggle = cell.viewWithTag(2) as! UISwitch
        let dict = wallets[indexPath.section]
        let isActive = dict["isActive"] as! Bool
        let name = dict["name"] as! String
        label.text = name
        toggle.setOn(isActive, animated: true)
        toggle.restorationIdentifier = "\(indexPath.section)"
        toggle.addTarget(self, action: #selector(toggleAction(_:)), for: .valueChanged)
        if isActive {
            label.textColor = .white
        } else {
            label.textColor = .darkGray
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    @objc func toggleAction(_ sender: UISwitch) {
        if sender.restorationIdentifier != nil {
            if let index = Int(sender.restorationIdentifier!) {
                let wallet = (wallets[index]["name"] as! String)
                if sender.isOn {
                    if wallet != "Default Wallet" {
                        UserDefaults.standard.set(wallet, forKey: "walletName")
                        wallets.removeAll()
                        didChange = true
                        refresh()
                    } else {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        getAllActiveWallets()
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
            }
        }
    }
    
    private func getAllActiveWallets() {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        Reducer.makeCommand(command: .listwallets, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let loadedWallets = response as? NSArray else {
                self.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them: \(errorMessage ?? "")")
                return
            }
            
            guard loadedWallets.count > 1 else {
                self.connectingView.removeConnectingView()
                return
            }
            
            for (i, w) in loadedWallets.enumerated() {
                if (w as! String) != "" {
                    self.walletsToUnload.append(w as! String)
                }
                if i + 1 == loadedWallets.count {
                    guard self.walletsToUnload.count > 0 else {
                        self.connectingView.removeConnectingView()
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        return
                    }
                    
                    self.promptToUnloadWallets()
                }
            }
        }
    }
    
    private func goUnload() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToUnloadWallets", sender: self)
        }
    }
    
    private func promptToUnloadWallets() {
        connectingView.removeConnectingView()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "In order to use the default wallet you need to unload all loaded wallets.", message: "In the next view you can tap each wallet to unload them, ensure you unload them all.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.wallets.removeAll()
                self.walletTable.reloadData()
                self.goUnload()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func parseWallets(walletDict: NSDictionary) {
        
        let walletArr = walletDict["wallets"] as! NSArray
        let activeWallet = UserDefaults.standard.object(forKey: "walletName") as? String ?? ""
        var activeIndex = -1
        for (i, wallet) in walletArr.enumerated() {
            let walletDict = wallet as! NSDictionary
            let walletName = walletDict["name"] as! String
            var isActive = false
            var dictName = walletName
            if walletName == activeWallet {
                isActive = true
                activeIndex = i
            }
            if walletName == "" {
                dictName = "Default Wallet"
                if isActive && !didChange {
                    getAllActiveWallets()
                }
            }
            let dict = ["name":dictName, "isActive":isActive] as [String : Any]
            wallets.append(dict)
            if i + 1 == walletArr.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if activeIndex > 0 {
                        self.wallets.swapAt(0, activeIndex)
                    }
                    self.connectingView.removeConnectingView()
                    self.walletTable.reloadData()
                    if self.didChange {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                        self.didChange = false
                        displayAlert(viewController: self, isError: false, message: "Wallet set to active, refreshing home screen...")
                    }
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let id = segue.identifier
        switch id {
        case "segueToUnloadWallets":
            if let vc = segue.destination as? ActiveWalletsViewController {
                vc.activeWallets = walletsToUnload
                walletsToUnload.removeAll()
            }
        default:
            break
        }
    }

}
