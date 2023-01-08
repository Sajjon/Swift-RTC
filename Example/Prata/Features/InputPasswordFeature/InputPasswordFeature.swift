//
//  InputPasswordFeature.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-08-31.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import CodeScanner
import P2PConnection
import P2PModels

public struct InputPassword: ReducerProtocol {
    public init() {}
}

public extension InputPassword {
    struct State: Equatable {
        public var connectionPasswordInput: String
        public var connectionPassword: ConnectionPassword?
        public var alert: AlertState<Action>?
        public init(
            connectionPasswordInput: String = "",
            alert: AlertState<Action>? = nil
        ) {
            self.connectionPasswordInput = connectionPasswordInput
            self.alert = alert
        }
    }
}

public extension InputPassword {
    enum Action: Sendable, Equatable {
        case `internal`(InternalAction)
        case delegate(DelegateAction)
    }
}
public extension InputPassword.Action {
    enum InternalAction: Sendable, Equatable {
        case connectionPasswordChanged(String)
        case connectButtonPressed
        case connect(ConnectionPassword)
        
        case failedToScanQRCode(reason: String)
        case scannedQRCode(String)
        case alertDismissed
    }
}
public extension InputPassword.Action {
    enum DelegateAction: Sendable, Equatable {
        case connect(ConnectionPassword)
    }
}

public extension InputPassword {
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action, Never> {
        switch action {
      
        case let .internal(.failedToScanQRCode(reason)):
            state.alert = .init(
                title: .init("Failed to scan QR - \(reason), try again or input connection password manually.")
            )
            return .none
        
        case let .internal(.scannedQRCode(scannedQR)):
            return .run { send in
                await send(.internal(.connectionPasswordChanged(scannedQR)))
            }
      
        case let .internal(.connectionPasswordChanged(connectionPasswordInput)):
            state.connectionPasswordInput = connectionPasswordInput
            print("connectionPasswordInput: \(state.connectionPasswordInput)")
            do {
                let connectionPassword = try ConnectionPassword(hex: connectionPasswordInput)
                state.connectionPassword = connectionPassword
            } catch {
                state.connectionPassword = nil
            }
            return .none
            
        case .internal(.connectButtonPressed):
            guard let password = state.connectionPassword else {
                fatalError("Bad logic, should have password, did you forget to disable button if no password?")
            }
            return .run { send in
                await send(.internal(.connect(password)))
            }
        
        case let .internal(.connect(password)):
            return .run { send in
                await send(.delegate(.connect(password)))
            }
       
        case .internal(.alertDismissed):
            state.alert = nil
            return .none
       
        case .delegate(_):
            return .none
        }
    }
}

public extension InputPassword {
    struct View: SwiftUI.View {
        public let store: StoreOf<InputPassword>
        public init(store: StoreOf<InputPassword>) {
            self.store = store
        }
        public var body: some SwiftUI.View {
            WithViewStore(self.store) { viewStore in
                VStack {
                    
                    scanQRCode(viewStore: viewStore)
                    
                    TextField(
                        "P2PConnection Password",
                        text: viewStore.binding(
                            get: \.connectionPasswordInput,
                            send: { Action.internal(.connectionPasswordChanged($0)) }
                        )
                    )
                    .submitLabel(.send)
                    .onSubmit {
                        if viewStore.connectionPassword != nil {
                            viewStore.send(.internal(.connectButtonPressed))
                        }
                    }
                    
                    if let connectionPassword = viewStore.connectionPassword {
                        ConnectionPasswordView(connectionPassword: connectionPassword)
                    }
                    
                    Button("Connect") {
                        viewStore.send(.internal(.connectButtonPressed))
                    }
                    .disabled(viewStore.connectionPassword == nil)
                }
                .alert(store.scope(state: \.alert), dismiss: Action.internal(.alertDismissed))
            }
        }
    }
}

public struct ConnectionPasswordView: View {
    let connectionPassword: ConnectionPassword
    public init(connectionPassword: ConnectionPassword) {
        self.connectionPassword = connectionPassword
    }
    private var hex: String {
        connectionPassword.hex()
    }
    /// number of chars in the end that should always be visible
    private let suffixCount = 8
    public var body: some View {
        HStack(spacing: 0) {
            Text(hex.prefix(hex.count - suffixCount))
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            Text(hex.suffix(suffixCount))
                .fixedSize()
        }
        .lineLimit(1)
    }
}

// MARK: Private Views
private extension InputPassword.View {
    
    @ViewBuilder
    func scanQRCode(
        viewStore: ViewStore<InputPassword.State, InputPassword.Action>
    ) -> some View {
#if os(iOS) && !targetEnvironment(simulator)
        CodeScannerView(config: .init(
            codeTypes: [.qr],
            scanMode: .oncePerCode,
            completion: { result in
                switch result {
                case .failure(let error):
                    viewStore.send(.internal(.failedToScanQRCode(reason: String(describing: error))
                    ))
                case .success(let qrScanResult):
                    viewStore.send(.internal(.scannedQRCode(qrScanResult.string)))
                }
            }
        ))
#else
        EmptyView()
#endif // os(iOS) && !TARGET_OS_SIMULATOR
    }
    
}
