import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save<T: Encodable>(_ item: T, service: String, account: String) {
        do {
            let data = try JSONEncoder().encode(item)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]

            // First try to delete existing item
            SecItemDelete(query as CFDictionary)

            // Then add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                print("Error saving to Keychain: \(status)")
            }
        } catch {
            print("Error encoding data for Keychain: \(error)")
        }
    }

    func read<T: Decodable>(service: String, account: String, type: T.Type) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Error decoding data from Keychain: \(error)")
            return nil
        }
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
