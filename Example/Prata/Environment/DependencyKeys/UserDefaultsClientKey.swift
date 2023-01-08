//
//  UserDefaultsClientKey.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-01.
//

import Foundation
import ComposableArchitecture

private enum UserDefaultsClientKey: DependencyKey {
    typealias Value = UserDefaultsClient
    static let liveValue = UserDefaultsClient.live()
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClientKey.self] }
        set { self[UserDefaultsClientKey.self] = newValue }
    }
}

