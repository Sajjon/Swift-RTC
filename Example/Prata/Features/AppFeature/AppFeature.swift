//
//  AppFeature.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-08-31.
//

import Foundation
import ComposableArchitecture
import P2PConnection
import SwiftUI

public struct App: ReducerProtocol {
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    /// For memoization
    @Dependency(\.loremIpsumGenerator) var loremIpsumGenerator
}
public extension App {
    enum State: Equatable {
        case splash(Splash.State)
        case inputPassword(InputPassword.State)
        case connectUsingPassword(ConnectUsingPassword.State)
        case chat(Chat.State)
    }
}
public extension App.State {
    init() {
        self = .splash(.init())
    }
}

public extension App {
    enum Action: Equatable {
        case splash(Splash.Action)
        case inputPassword(InputPassword.Action)
        case connectUsingPassword(ConnectUsingPassword.Action)
        case chat(Chat.Action)
        
        case `internal`(InternalAction)
    }
}
public extension App.Action {
    enum InternalAction: Equatable {
        case deleteConnectionPassword
        case viewWillAppear
        case viewWillDisappear
        
        case toConnect(ConnectionPassword)
        case toChat(P2PConnectionID)
        case toInputPassword
    }
}

public extension App {
    private enum MemoizeLoremIpsumID {}
    
    var body: some ReducerProtocolOf<Self> {
        CombineReducers {
            EmptyReducer()
                .ifCaseLet(
                    /State.splash,
                     action: /Action.splash
                ) {
                    Splash()
                }
                .ifCaseLet(
                    /State.inputPassword,
                     action: /Action.inputPassword
                ) {
                    InputPassword()
                }
                .ifCaseLet(
                    /State.connectUsingPassword,
                     action: /Action.connectUsingPassword
                ) {
                    ConnectUsingPassword()
                }
                .ifCaseLet(
                    /State.chat,
                     action: /Action.chat
                ) {
                    Chat()
                }
            
            Reduce(self.core)
        }
    }
    
    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .internal(.viewWillAppear):
            // Precalculate and cache large lorem ipsum messages
            return .run { _ in
                Task {
                    await self.loremIpsumGenerator.memoize()
                    loggerGlobal.info("Memoization of LoremIpsum for large messages done.")
                    // fire forget
                }
            }
            .cancellable(id: MemoizeLoremIpsumID.self)
            
        case .internal(.viewWillDisappear):
            return .cancel(id: MemoizeLoremIpsumID.self)
            
        case let .splash(.loadedPersistedPassword(maybePassword)):
            if let connectionPassword = maybePassword {
                return .task {
                    .internal(.toConnect(connectionPassword))
                }
            } else {
                return .task {
                    .internal(.toInputPassword)
                }
            }
        case .splash(_):
            return .none
            
        case let .inputPassword(.delegate(.connect(connectionPassword))):
            return .task {
                .internal(.toConnect(connectionPassword))
            }
            
        case .inputPassword(.internal(_)):
            return .none
            
        case .chat(.deleteConnectionPassword):
            return .task { .internal(.deleteConnectionPassword) }
            
        case .internal(.deleteConnectionPassword):
            return .run { [userDefaultsClient] send in
                await userDefaultsClient.deleteConnectionPassword()
                await send(.internal(.toInputPassword))
            }
            
        case let .internal(.toChat(connectionID)):
            state = .chat(.init(connectionID: connectionID))
            return .none
            
        case .chat(_):
            return .none
            
        case .connectUsingPassword(.delegate(.deleteConnectionPassword)):
            return .task { .internal(.deleteConnectionPassword) }
            
        case let .connectUsingPassword(.delegate(.establishConnectionResult(.success(connectionID)))):
            return .run { send in
                //                    await userDefaultsClient.setConnectionPassword(connectedPeer.config.connectionPassword)
                await send(.internal(.toChat(connectionID)))
            }
            
        case let .connectUsingPassword(.delegate(.establishConnectionResult(.failure(error)))):
            print("Failed to establish connection: \(String(describing: error))")
            return .none
            
        case .connectUsingPassword:
            return .none
            
        case .internal(.toInputPassword):
            state = .inputPassword(.init())
            return .none
            
        case let .internal(.toConnect(connectionPassword)):
            state = .connectUsingPassword(.init(connectionPassword: connectionPassword))
            return .none
        }
    }
}

public extension App {
    struct View: SwiftUI.View {
        public let store: StoreOf<App>
        public var body: some SwiftUI.View {
            VStack(spacing: 8) {
                Text("Version: \(Bundle.main.appVersionLong) build #\(Bundle.main.appBuild)")
                    .frame(maxWidth: .infinity, maxHeight: 20)
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                
                Spacer()
                
                WithViewStore(store) { viewStore in
                    SwitchStore(self.store) {
                        CaseLet(
                            state: /App.State.splash,
                            action: App.Action.splash,
                            then: Splash.View.init
                        )
                        CaseLet(
                            state: /App.State.inputPassword,
                            action: App.Action.inputPassword,
                            then: InputPassword.View.init
                        )
                        CaseLet(
                            state: /App.State.connectUsingPassword,
                            action: App.Action.connectUsingPassword,
                            then: ConnectUsingPassword.View.init
                        )
                        CaseLet(
                            state: /App.State.chat,
                            action: App.Action.chat,
                            then: Chat.View.init
                        )
                    }
                    .onAppear {
                        viewStore.send(.internal(.viewWillAppear))
                    }
                    .onDisappear {
                        viewStore.send(.internal(.viewWillDisappear))
                    }
                }
            }
        }
    }
}

extension Bundle {
    
    public var appBuild: String { getInfo("CFBundleVersion") }
    public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
    
    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}
