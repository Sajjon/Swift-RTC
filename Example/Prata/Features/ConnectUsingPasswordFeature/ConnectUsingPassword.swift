//
//  ConnectUsingPassword.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-08-31.
//

import SwiftUI
import ComposableArchitecture
import P2PConnection
import P2PModels

public struct ConnectUsingPassword: ReducerProtocol {
    public init() {}
}

public extension ConnectUsingPassword {
    struct State: Equatable {

        public let connectionPassword: ConnectionPassword
        public var connectionID: P2PConnectionID?
        public var connectionStatus: ConnectionStatus
        public var dataChannelStatus: DataChannelState
        public var webSocketStatus: WebSocketState
        
        public var alert: AlertState<Action>?

        public init(
            connectionPassword: ConnectionPassword,
            connectionStatus: ConnectionStatus = .new,
            dataChannelStatus: DataChannelState = .closed,
            webSocketState: WebSocketState = .new,
            alert: AlertState<Action>? = nil
        ) {
            self.connectionStatus = connectionStatus
            self.connectionPassword = connectionPassword
            self.webSocketStatus = webSocketState
            self.dataChannelStatus = dataChannelStatus
            self.alert = alert
        }
    }
}
public extension ConnectUsingPassword {
    enum Action: Sendable & Equatable {
        case `internal`(InternalAction)
        case delegate(DelegateAction)
    }
}
public extension ConnectUsingPassword.Action {
    enum InternalAction: Sendable, Equatable {
        case system(SystemAction)
        case user(UserAction)
    }
    enum DelegateAction: Sendable, Equatable {
        case establishConnectionResult(TaskResult<P2PConnectionID>)
        case deleteConnectionPassword
    }
}
public extension ConnectUsingPassword.Action.InternalAction {
    enum SystemAction: Sendable, Equatable {
        case task
        case viewDidAppear
        case connectionStatusChanged(ConnectionStatus)
        case establishConnectionResult(TaskResult<P2PConnectionID>)
        case webSocketStateChanged(WebSocketState)
        case dataChannelStateChanged(DataChannelState)
    }
    enum UserAction: Sendable, Equatable {
        case deleteConnectionPassword
        case dismissAlert
    }
}

public extension ConnectUsingPassword {
    private enum ConnectID: Hashable {}
    private enum StatusID: Hashable {}
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case let .internal(.system(.connectionStatusChanged(status))):
            state.connectionStatus = status
            return .none
            
        case let .internal(.system(.dataChannelStateChanged(status))):
            state.dataChannelStatus = status
            return .none
        case let .internal(.system(.webSocketStateChanged(status))):
            state.webSocketStatus = status
            return .none
            
        case .internal(.system(.task)):
            return .run { [connectionPassword = state.connectionPassword] send in
                let id = try! P2PConnectionID(password: connectionPassword)
                await withThrowingTaskGroup(of: Void.self) { group in
                    _ = group.addTaskUnlessCancelled {
                        for try await statusEvent in try await P2PConnections.shared.connectionStatusChangeEventAsyncSequence(for: id) {
                            guard !Task.isCancelled else { return }
                            await send(.internal(.system(.connectionStatusChanged(statusEvent.connectionStatus))))
                        }
                    }
                    _ = group.addTaskUnlessCancelled {
                        for try await wsState in try await P2PConnections.shared.debugWebSocketState(for: id) {
                            guard !Task.isCancelled else { return }
                            await send(.internal(.system(.webSocketStateChanged(wsState))))
                        }
                    }
                    _ = group.addTaskUnlessCancelled {
                        for try await dataChannelState in try await P2PConnections.shared.debugDataChannelState(for: id) {
                            guard !Task.isCancelled else { return }
                            await send(.internal(.system(.dataChannelStateChanged(dataChannelState))))
                        }
                    }
                }
            }
            .cancellable(id: StatusID.self, cancelInFlight: true)
        case .internal(.system(.viewDidAppear)):
            return .run { [connectionPassword = state.connectionPassword] send in
                do {
                    await send(.internal(.system(.establishConnectionResult(TaskResult {
                        let value = try await P2PConnections.shared.add(
                            connectionPassword: connectionPassword, connectMode: .connect(force: false, inBackground: false)
                        )
                        return value
                    } ))))
                }
            }
            .cancellable(id: ConnectID.self, cancelInFlight: true)
        case let .internal(.system(.establishConnectionResult(.success(connection)))):
            return .run { send in
                await send(.delegate(.establishConnectionResult(.success(connection))))
            }
        case .internal(.user(.deleteConnectionPassword)):
            return .run { send in
                await send(.delegate(.deleteConnectionPassword))
            }
        case let .internal(.system(.establishConnectionResult(.failure(error)))):
            state.alert = .init(
                title: .init("Failed to connect, failure: \(String(describing: error))"),
                primaryButton: .destructive(.init("Restart"), action:.send(.delegate(.establishConnectionResult(.failure(error))))),
                secondaryButton: .default(.init("Dismiss"), action: .send(.internal(.user(.dismissAlert))))
           )
            return .none
        case .internal(.user(.dismissAlert)):
            state.alert = nil
            return .none
        case .delegate(_):
            return .cancel(ids: [ConnectID.self, StatusID.self])
        }
    }
}

public extension ConnectUsingPassword {
    struct View: SwiftUI.View {
        public let store: StoreOf<ConnectUsingPassword>
        public init(store: StoreOf<ConnectUsingPassword>) {
            self.store = store
        }
        public var body: some SwiftUI.View {
            WithViewStore(self.store) { viewStore in
                VStack {
                    Button("Restart", role: .destructive) {
                        viewStore.send(.internal(.user(.deleteConnectionPassword)))
                    }

                    Spacer()
                    Text("Connecting status: \(viewStore.connectionStatus.rawValue)").font(.title)
                    Text("WS status: \(viewStore.webSocketStatus.description)").font(.title2)
                    Text("Data Channel status: \(viewStore.dataChannelStatus.description)").font(.title2)
                    LoadingView()
                        .padding(50)
                    Spacer()
                }
                .alert(store.scope(state: \.alert), dismiss: .internal(.user(.dismissAlert)))
                .onAppear {
                    viewStore.send(.internal(.system(.viewDidAppear)))
                }
               
            }
            .task { @MainActor in
                await ViewStore(store.stateless)
                    .send(.internal(.system(.task)))
                    .finish()
            }
        }
    }
}

public struct LoadingView: View {
 
    @State private var isLoading = false
 
    public init() {}
    public var body: some View {
        ZStack {
 
            Circle()
                .stroke(Color(.systemGray), lineWidth: 14)
                .frame(width: 100, height: 100)
 
            Circle()
                .trim(from: 0, to: 0.2)
                .stroke(Color.green, lineWidth: 7)
                .frame(width: 100, height: 100)
                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: self.isLoading)
                .onAppear() {
                    self.isLoading = true
            }
        }
    }
}
