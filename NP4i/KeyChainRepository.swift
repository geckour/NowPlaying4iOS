//
//  KeyChainRepository.swift
//  NP4i
//
//  Created by geckour on 2023/04/15.
//

import Foundation

class KeyChainRepository {
    
    static let standard = KeyChainRepository()
    
    func getFromKeyChainOrNull(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as [String:Any]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        return result as? Data
    }

    func setIntoKeyChain(value: String, service: String, account: String) -> Bool {
        let query = [
            kSecValueData: value.data(using: .utf8)!,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as [String:Any]
        let match = SecItemCopyMatching(query as CFDictionary, nil)
        switch match {
        case errSecItemNotFound:
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == noErr
        case errSecSuccess:
            SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: value] as CFDictionary
            )
            return true
        default:
            print("Error: failed to save \(service) into Keychain: \(match)")
            return false
        }
    }
    
    func deleteFromKeyChain(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as [String:Any]
        SecItemDelete(query as CFDictionary)
    }
}
