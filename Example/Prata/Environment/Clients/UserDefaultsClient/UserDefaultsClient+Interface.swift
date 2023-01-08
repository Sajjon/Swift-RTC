import ComposableArchitecture
import Foundation
import P2PConnection
import P2PModels

// MARK: - UserDefaultsClient
public struct UserDefaultsClient {
	public var boolForKey: @Sendable (String) -> Bool
	public var dataForKey: @Sendable (String) -> Data?
	public var doubleForKey: @Sendable (String) -> Double
	public var integerForKey: @Sendable (String) -> Int
	public var remove: @Sendable (String) async -> Void
	public var setBool: @Sendable (Bool, String) async -> Void
	public var setData: @Sendable (Data?, String) async -> Void
	public var setDouble: @Sendable (Double, String) async -> Void
	public var setInteger: @Sendable (Int, String) async -> Void
}

private extension UserDefaultsClient {
    func _setConnectionPassword(_ connectionPassword: ConnectionPassword?) async {
        await setData(
            connectionPassword?.data.data,
            connectionPasswordKey
        )
    }
    
}

public extension UserDefaultsClient {
 
    func setConnectionPassword(_ connectionPassword: ConnectionPassword) async {
        await _setConnectionPassword(connectionPassword)
    }
    
    func deleteConnectionPassword() async {
        await remove(connectionPasswordKey)
    }
	
	var connectionPassword: ConnectionPassword? {
        guard let connectionPasswordHex = dataForKey(connectionPasswordKey) else {
            return nil
        }
        return try? ConnectionPassword(data: connectionPasswordHex)
	}
}

let connectionPasswordKey = "connectionPasswordKey"
