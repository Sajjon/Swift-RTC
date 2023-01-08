//
//  ChatFeature.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-02.
//

import ComposableArchitecture
import Logging
import SwiftUI
import P2PConnection

public extension LoremIpsumGenerator {
    static func live(
        userDefaultsClient: UserDefaultsClient = .live()
    ) -> Self {
        return Self { bytesToGenerate, cacheKey in
            let encoding: String.Encoding = .utf8

            if
                let cachedData = userDefaultsClient.dataForKey(cacheKey),
                let cached = String(data: cachedData, encoding: encoding)
            {
                loggerGlobal.debug("LoremIpsumGenerator - found cached for size: \(bytesToGenerate), key: \(cacheKey), actual size: \(cached.count)")
                return cached
            }

            let generated: String = await Task {
                do {
                    let newlyGenerated = try Lorem._bytes(
                        minByteCount: Int(0.8*Double(bytesToGenerate)),
                        maxByteCount: Int(1.2*Double(bytesToGenerate))
                    )
                    loggerGlobal.debug("LoremIpsumGenerator - generate LOREM of size: \(bytesToGenerate), actual size: \(newlyGenerated.count)")
                    return newlyGenerated
                } catch {
                    let repeated = "NoLorem"
                    let count = bytesToGenerate / repeated.count
                    let fallback = String(repeating: repeated, count: count)
                    loggerGlobal.debug("LoremIpsumGenerator - failed to generate LOREM of size: \(bytesToGenerate), using fallback string of size: \(fallback.count)")
                    return fallback
                }
            }.value

            if let toCache = generated.data(using: encoding) {
                await userDefaultsClient.setData(toCache, cacheKey)
            } else {
                loggerGlobal.debug("LoremIpsumGenerator - failed to create data from LOREM of size: \(bytesToGenerate), cacheKey: \(cacheKey)")
            }

            return generated
        }
    }
}

private enum LoremIpsumGeneratorKey: DependencyKey {
    typealias Value = LoremIpsumGenerator
    static let liveValue = LoremIpsumGenerator.live()
}

extension DependencyValues {
    var loremIpsumGenerator: LoremIpsumGenerator {
        get { self[LoremIpsumGeneratorKey.self] }
        set { self[LoremIpsumGeneratorKey.self] = newValue }
    }
}
public struct Chat: ReducerProtocol {
    @Dependency(\.loremIpsumGenerator) var loremIpsumGenerator
    public init() {}
}

public extension Chat {
    struct State: Equatable {
        
        /// The most important state of the whole app.
        public let connectionID: P2PConnectionID
        /// When connection has closed and `connection` is doing a retry,
        /// this is set to true
        public var connectionStatus: ConnectionStatus
        
        public var draft: String
        public var messages: [ChatMessage]
        public var alert: AlertState<Action>?
        public var confirmationDialog: ConfirmationDialogState<Action>?
        @BindableState public var focusedField: Field?
        
        public init(
            connectionID: P2PConnectionID,
            connectionStatus: ConnectionStatus = .new,
            draft: String = "",
            messages: [ChatMessage] = [],
            alert: AlertState<Action>? = nil,
            confirmationDialog: ConfirmationDialogState<Action>? = nil,
            focusedField: Field? = nil
        ) {
            self.connectionID = connectionID
            self.connectionStatus = connectionStatus
            
            self.draft = draft
            self.messages = messages
            self.alert = alert
            self.confirmationDialog = confirmationDialog
            self.focusedField = focusedField
        }
    }
}
public extension Chat {
    enum Action: Equatable, BindableAction {
        case webRTCConnectionStatusChanged(ConnectionStatus)
        case binding(BindingAction<State>)
        case task
        case viewTapped
        case generateAndSendLargeMessagesMenuButtonPressed
        case generateAndSend(kiloBytes: Int)
        case sendLargeGeneratedMessage(LargeMessageToSend)
        case confirmationDialogDismissed
        case closeButtonPressed; case finishedClosing
        case deleteConnectionPasswordButtonPressed
        case deleteConnectionPasswordConfirmed
        case cancelAllTasks
        case deleteConnectionPassword
        case draftChanged(String)
        case sendMessage(makeDraftEmpty: Bool)
        case alertDismissed
        case receivedMessage(P2PConnections.IncomingMessage)
        case sendMessageReceivedReceiptAndMarkAsHandledResult(TaskResult<P2PConnections.IncomingMessage>)
        case resultOfSending(failure: String?, msgID: ChatMessage.ID)
        case gotConfirmationOfOutgoingMessage(P2PConnections.SentReceipt)
    }
}

/// A simple wrapper type which overrides `CustomDumpStringConvertible`
/// and `CustomStringConvertible`, on order to not bloat logs with thousands of lines
/// of lorem ipsum.
public struct LargeMessageToSend: Sendable & Equatable, CustomStringConvertible, CustomDumpStringConvertible {
    public let largeMessage: String
}
public extension LargeMessageToSend {
    var description: String {
        "Large generated message to send: #\(largeMessage.count) bytes."
    }
    var customDumpDescription: String {
        description
    }
}

public extension Chat.State {
    enum Field: String, Hashable {
        case chat
    }
}

extension View {
    func synchronize<Value>(
        _ first: Binding<Value>,
        _ second: FocusState<Value>.Binding
    ) -> some View {
        self
            .onChange(of: first.wrappedValue) { second.wrappedValue = $0 }
            .onChange(of: second.wrappedValue) { first.wrappedValue = $0 }
    }
}

public extension Chat {
    private enum ReceiveIncomingOrConfirmationAndConnectionStatusID {}
    private enum SendID {}
    private enum GenerateLargeMsgID {}
    
    @ReducerBuilderOf<Self>
    var body: some ReducerProtocol<State, Action> {
        BindingReducer<State, Action>()
        
        Reduce<State, Action> { state, action in
            switch action {
            case let .webRTCConnectionStatusChanged(status):
                loggerGlobal.debug("webRTCConnectionStatusChanged: \(status)")
                state.connectionStatus = status
                return .none
                
            case .task:
                return .run { [connectionID = state.connectionID] send in
                    await withThrowingTaskGroup(of: Void.self) { group in
                        
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            for try await statusUpdateEvent in try await P2PConnections.shared.connectionStatusChangeEventAsyncSequence(for: connectionID) {
                                loggerGlobal.debug("connection.statusUpdateEvent => \(statusUpdateEvent)")
                                await send(.webRTCConnectionStatusChanged(statusUpdateEvent.connectionStatus))
                            }
                        }
                        
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            for try await incoming in try await P2PConnections.shared.incomingMessagesAsyncSequence(for: connectionID) {
                                await send(.receivedMessage(incoming))
                            }
                        }
                        
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            for try await msgSentConfirmation in try await P2PConnections.shared.sentReceiptsAsyncSequence(for: connectionID) {
                                await send(.gotConfirmationOfOutgoingMessage(msgSentConfirmation))
                            }
                        }
                    }
                }
                .cancellable(id: ReceiveIncomingOrConfirmationAndConnectionStatusID.self)
                
            case .viewTapped:
                state.focusedField = nil
                return .none
                
            case .binding(_):
                return .none
                
            case .generateAndSendLargeMessagesMenuButtonPressed:
                state.confirmationDialog = .init(
                    title: .init("Generate and send large messages"),
                    titleVisibility: .automatic,
                    buttons:
                        LoremIpsumGenerator.sizesInKB.map { kbCount in
                                .default(
                                    .init("\(kbCount)kb"),
                                    action: .send(.generateAndSend(kiloBytes: kbCount)))
                        }
                    
                )
                return .none
                
            case let .generateAndSend(kiloBytes):
                return .run { send in
                    let generated = await loremIpsumGenerator.generate(kiloBytes: kiloBytes)
                    await send(.sendLargeGeneratedMessage(.init(largeMessage: generated)))
                }
                .cancellable(id: GenerateLargeMsgID.self)
                
            case let .sendLargeGeneratedMessage(largeGeneratedMsg):
                let largeGeneratedMessage = largeGeneratedMsg.largeMessage
                
                let messageId = UUID().uuidString
                let messageDataToSend = largeGeneratedMessage.data(using: .utf8)!
                let chatMessage = ChatMessage(
                    type: .outgoing(.sending),
                    content: .largeMessage(.init(
                        size: messageDataToSend.count,
                        isLoremIpsum: true
                    )),
                    id: messageId
                )
                
                state.messages.append(chatMessage)
                
                return .task { [connectionID = state.connectionID] in
                    try await P2PConnections.shared.sendData(for: connectionID, data: messageDataToSend, messageID: messageId)
                    return .resultOfSending(failure: nil, msgID: messageId)
                } catch: { error in
                        .resultOfSending(failure: String(describing: error), msgID: messageId)
                }
                .cancellable(id: SendID.self, cancelInFlight: false)
                
            case .deleteConnectionPasswordButtonPressed:
                state.alert = .init(
                    title: .init("Are you sure you want to delete the current connection password and close the current P2P connnection?"),
                    primaryButton: .cancel(
                        .init(verbatim: "Keep current")
                    ),
                    secondaryButton: .destructive(
                        .init(verbatim: "Delete"),
                        action: .send(.deleteConnectionPasswordConfirmed)
                    )
                )
                
                return .none
                
            case .closeButtonPressed:
                return .run { [connectionID = state.connectionID] send in
                    try! await P2PConnections.shared.removeAndDisconnect(id: connectionID)
                    await send(.finishedClosing)
                }
            case .finishedClosing:
                print("finished closing")
                return .none
                
            case .deleteConnectionPasswordConfirmed:
                return .run { send in
                    await send(.cancelAllTasks)
                    await send(.deleteConnectionPassword)
                }
            case .deleteConnectionPassword:
                return .handleInParentReducer
                
            case let .draftChanged(updatedDraft):
                state.draft = updatedDraft
                return .none
                
            case let .sendMessage(makeDraftEmpty):
                guard !state.draft.isEmpty else { return .none }
                
                let messageId = UUID().uuidString
                let message = state.draft
                let messageDataToSend = message.data(using: .utf8)!
                
                let chatMessage = ChatMessage(
                    type: .outgoing(.sending),
                    content: .smallMessage(message),
                    id: messageId
                )
                
                state.messages.append(chatMessage)
                
                if makeDraftEmpty {
                    state.draft = ""
                }
                
                return .task { [connectionID = state.connectionID] in
                    try await P2PConnections.shared.sendData(for: connectionID, data: messageDataToSend, messageID: messageId)
                    return .resultOfSending(failure: nil, msgID: messageId)
                } catch: { error in
                        .resultOfSending(failure: String(describing: error), msgID: messageId)
                }
                .cancellable(id: SendID.self, cancelInFlight: false)
                
            case let .gotConfirmationOfOutgoingMessage(confirmedOutgoingMessage):
                if let msgIndex = state.messages.firstIndex(where: { $0.id == confirmedOutgoingMessage.messageSent.messageID }) {
                    state.messages[msgIndex] = state.messages[msgIndex].confirmed()
                }
                return .none
                
            case let .receivedMessage(receivedMsg):
                let stringMessage = String(data: receivedMsg.messagePayload, encoding: .utf8)!
                
                let receivedMessage = ChatMessage.receivedInferIfGenerated(
                    message: stringMessage,
                    id: receivedMsg.messageID
                )
                
                state.messages.append(receivedMessage)
                return .run { [connectionID = state.connectionID] send in
                    await send(.sendMessageReceivedReceiptAndMarkAsHandledResult(
                        TaskResult {
                            try await P2PConnections.shared.sendReceipt(for: connectionID, readMessage: receivedMsg, alsoMarkMessageAsHandled: true)
                            return receivedMsg
                        }
                    ))
                }
                
            case let .sendMessageReceivedReceiptAndMarkAsHandledResult(.success(confirmedAndHandledReceivedMsg)):
                if let msgIndex = state.messages.firstIndex(where: { $0.id == confirmedAndHandledReceivedMsg.messageID }) {
                    state.messages[msgIndex] = state.messages[msgIndex].finishedSendingMessageReceivedConfirmation()
                }
                return .none
                
            case let .sendMessageReceivedReceiptAndMarkAsHandledResult(.failure(error)):
                state.alert = .init(title: .init("Failed to send msg received confirmation, failure: \(String(describing: error))"))
                return .none
            case .cancelAllTasks:
                return .cancel(ids: [ReceiveIncomingOrConfirmationAndConnectionStatusID.self, SendID.self, GenerateLargeMsgID.self])
                
            case let .resultOfSending(.some(failureReason), msgId):
                state.alert = .init(title: .init("Failed to send, failure: \(failureReason)"))
                if let msgIndex = state.messages.firstIndex(where: { $0.id == msgId }) {
                    state.messages[msgIndex] = state.messages[msgIndex].failed()
                }
                return .none
                
            case let .resultOfSending(.none, msgId):
                if let msgIndex = state.messages.firstIndex(where: { $0.id == msgId }) {
                    state.messages[msgIndex] = state.messages[msgIndex].sendButNotConfirmed()
                }
                return .none
                
            case .alertDismissed:
                state.alert = nil
                return .none
                
            case .confirmationDialogDismissed:
                state.confirmationDialog = nil
                return .none
            }
        }
    }
}

public extension Chat {
    struct View: SwiftUI.View {
        public let store: StoreOf<Chat>
        @FocusState var focusedField: Chat.State.Field?
        
        public init(store: StoreOf<Chat>) {
            self.store = store
        }
    }
}

public extension Chat.View {
    var body: some SwiftUI.View {
        WithViewStore(self.store) { viewStore in
            VStack {
                header(viewStore)
                contentView(viewStore)
            }
            .onTapGesture {
                viewStore.send(.viewTapped)
            }
            .confirmationDialog(store.scope(state: \.confirmationDialog), dismiss: Chat.Action.confirmationDialogDismissed)
            .alert(store.scope(state: \.alert), dismiss: Chat.Action.alertDismissed)
        }
        .task { @MainActor in
            await ComposableArchitecture.ViewStore(store.stateless)
                .send(.task)
                .finish()
        }
    }
}

extension Chat.State {
    var shouldDisplayConnectingLoader: Bool {
        switch connectionStatus {
        case .connected: return false
        default: return true
        }
    }
}
// MARK: Subviews
private extension Chat.View {
    
    typealias ViewStore = ComposableArchitecture.ViewStore<Chat.State, Chat.Action>
    
    func header(_ viewStore: ViewStore) -> some View {
        VStack {
            Text("Chat").font(.largeTitle)
            Button("Close", role: .destructive) {
                viewStore.send(.closeButtonPressed)
            }
            
            Button("New Chat", role: .destructive) {
                viewStore.send(.deleteConnectionPasswordButtonPressed)
            }
        }
    }
    
    func contentView(_ viewStore: ViewStore) -> some View {
        ZStack {
            chatView(viewStore)
                .zIndex(0)
            if viewStore.shouldDisplayConnectingLoader {
                isReconnectingView(viewStore)
                    .zIndex(1)
            }
        }
    }
    
    
    func isReconnectingView(_ viewStore: ViewStore) -> some View {
        ZStack {
            Color.gray.opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack {
                    Text("\(viewStore.connectionStatus.rawValue)")
                        .foregroundColor(.red)
                        .font(.title2)
                    LoadingView()
                        .padding(10)
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(15)
        }
        .cornerRadius(20)
    }
    
    func chatView(_ viewStore: ViewStore) -> some View {
        VStack {
            messagesView(viewStore)
            textField(viewStore)
            sendMessageButtons(viewStore)
        }
        // Prevent hacky keyboard hide animation
        .transaction { $0.animation = nil }
    }
    
    func textField(_ viewStore: ViewStore) -> some View {
        TextField(
            "Message to browser...",
            text: viewStore.binding(
                get: \.draft,
                send: Chat.Action.draftChanged)
        )
        .focused($focusedField, equals: .chat)
        .synchronize(viewStore.binding(\.$focusedField), self.$focusedField)
        .submitLabel(.send)
        .onSubmit {
            if !viewStore.draft.isEmpty {
                viewStore.send(.sendMessage(makeDraftEmpty: true))
                self.focusedField = .chat
            }
        }
    }
    
    func sendMessageButtons(_ viewStore: ViewStore) -> some View {
        HStack {
            Button("Large msgs") {
                viewStore.send(.generateAndSendLargeMessagesMenuButtonPressed)
            }
            
            Button("Send") {
                viewStore.send(.sendMessage(makeDraftEmpty: true))
            }
            .disabled(viewStore.draft.isEmpty)
        }
    }
    
    func messagesView(_ viewStore: ViewStore) -> some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewStore.messages) { message in
                        MessageView(message: message)
                            .id(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .onChange(of: viewStore.messages.last) { msg in
                // Should this be done via Reducer somehow?
                scrollViewProxy.scrollTo(msg)
            }
        }
    }
}
