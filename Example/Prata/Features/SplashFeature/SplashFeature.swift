//
//  File.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-08-31.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import P2PConnection
import P2PModels


public struct Splash: ReducerProtocol {
    @Dependency(\.userDefaultsClient) var userDefaultsClient
}

public extension Splash {
    struct State: Sendable & Equatable {}
}

public extension Splash {
    enum Action: Sendable & Equatable {
        case viewDidAppear
        case loadedPersistedPassword(ConnectionPassword?)
    }
}
public extension Splash {
    struct View: SwiftUI.View {
        public let store: StoreOf<Splash>
        public var body: some SwiftUI.View {
            WithViewStore(self.store) { viewStore in
                VStack {
                    Text("Checking for saved password...")
                }
                .onAppear {
                    viewStore.send(.viewDidAppear)
                }
            }
        }
    }
}
public extension Splash {

    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action, Never> {
        switch action {
        case .viewDidAppear:
            return .run { send in
//                let maybePassword = userDefaultsClient.connectionPassword
                await send(.loadedPersistedPassword(nil))
            }
        case .loadedPersistedPassword:
            return .none
        }
    }
}
