//
//  QuickConnect.swift
//  BitSense
//
//  Created by Peter on 28/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class QuickConnect {
    
    // MARK: QuickConnect uri examples
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:8332/?label=Node%20Name
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18332/?
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18443
    /// clightning-rpc://rpcuser:rpcpassword@kjhfefe.onion:1312?label=BTCPay%20C-Lightning
    
    static var uncleJim = false
    
    class func addNode(uncleJim: Bool, url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        var label = "Node"
        
        guard var host = URLComponents(string: url)?.host,
            let port = URLComponents(string: url)?.port,
            let rpcPassword = URLComponents(string: url)?.password,
            let rpcUser = URLComponents(string: url)?.user else {
                completion((false, "invalid url"))
                return
        }
        
        host += ":" + String(port)
        
        if let labelCheck = URL(string: url)?.value(for: "label") {
            label = labelCheck
        }
        
        guard host != "", rpcUser != "", rpcPassword != "" else {
            completion((false, "either the hostname, rpcuser or rpcpassword is empty"))
            return
        }
                
        // Encrypt credentials
        guard let torNodeHost = Crypto.encrypt(host.dataUsingUTF8StringEncoding),
            let torNodeRPCPass = Crypto.encrypt(rpcPassword.dataUsingUTF8StringEncoding),
            let torNodeRPCUser = Crypto.encrypt(rpcUser.dataUsingUTF8StringEncoding) else {
                completion((false, "error encrypting your credentials"))
                return
        }
        
        // Set node data for storage
        var newNode = [String:Any]()
        newNode["id"] = UUID()
        newNode["onionAddress"] = torNodeHost
        newNode["label"] = label
        newNode["rpcuser"] = torNodeRPCUser
        newNode["rpcpassword"] = torNodeRPCPass
        newNode["uncleJim"] = uncleJim
        
        if !url.hasPrefix("clightning-rpc") {
            newNode["isActive"] = true
            newNode["isLightning"] = false
        } else {
            newNode["isLightning"] = true
            newNode["isActive"] = false
        }
        
        processNode(newNode, url, completion: completion)
    }
    
    private class func processNode(_ newNode: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        if url.hasPrefix("clightning-rpc") {
            saveNode(newNode, url, completion: completion)
            
        } else {
            // Deactivate existing nodes
            CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
                guard let nodes = nodes, nodes.count > 0 else { saveNode(newNode, url, completion: completion); return }
                
                for (i, node) in nodes.enumerated() {
                    let nodeStruct = NodeStruct(dictionary: node)
                    guard let id = nodeStruct.id else { return }
                    
                    CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                    
                    if i + 1 == nodes.count {
                        saveNode(newNode, url, completion: completion)
                    }
                }
            }
        }
    }
    
    private class func saveNode(_ node: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.saveEntity(dict: node, entityName: .newNodes) { success in
            if success {
                if !url.hasPrefix("clightning-rpc") && !uncleJim {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
                
                completion((true, nil))
            } else {
                completion((false, "error saving your node to core data"))
            }
        }
    }
    
}

extension URL {
    func value(for paramater: String) -> String? {
        let queryItems = URLComponents(string: self.absoluteString)?.queryItems
        let queryItem = queryItems?.filter({$0.name == paramater}).first
        let value = queryItem?.value
        return value
    }
}
