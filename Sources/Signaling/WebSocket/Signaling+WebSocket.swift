//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation
import AsyncExtensions
import P2PModels
import SignalingServerClient

extension URL: Sendable {}

// MARK: WebSocketActor
public actor WebSocketActor {
    public typealias IncomingMessage = URLSessionWebSocketTask.Message
    
    private var task: Task<Void, Never>?
    private let webSocketTask: URLSessionWebSocketTask
    
    private let readyStateUpdates: AsyncStream<WebSocketState>
    private let incomingMessageAsyncStream: AsyncStream<IncomingMessage>
    private let incomingMessageAsyncContinuation: AsyncStream<IncomingMessage>.Continuation
    
    private let delegate: WSDelegate
    
    public init(
        url: URL
    ) {
        let webSocketTask = URLSession.shared.webSocketTask(with: url)
        let (readyStateUpdates, statusAsyncContinuation) = AsyncStream.streamWithContinuation(WebSocketState.self)
        self.delegate = .init(taskIdentifier: webSocketTask.taskIdentifier, statusAsyncContinuation: statusAsyncContinuation)
        self.readyStateUpdates = readyStateUpdates
        self.webSocketTask = webSocketTask
        (incomingMessageAsyncStream, incomingMessageAsyncContinuation) = AsyncStream.streamWithContinuation()
        
        Task {
            await connect()
        }
    }
}

// MARK: Private
private extension WebSocketActor {
    func connect() {
        webSocketTask.resume()
        self.task = Task { [unowned self] in
            await withThrowingTaskGroup(of: Void.self) { group in
                _ = group.addTaskUnlessCancelled {
                    await self.ping()
                }
                _ = group.addTaskUnlessCancelled {
                    await self.receive()
                }
            }
        }
    }
    
    func ping() {
        webSocketTask.sendPing { maybeError in
            Task { [unowned self] in
                if let error = maybeError {
                    debugPrint("Ping failed, closing due to error: \(String(describing: error))")
                    await self._close(code: .abnormalClosure)
                } else {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 sec
                    try Task.checkCancellation()
                    await self.ping()
                }
            }
        }
    }
    
    func receive() {
        webSocketTask.receive { result in
            Task { [unowned self] in
                switch result {
                case let .failure(error):
                    debugPrint("Receive failed, closing due to error: \(String(describing: error))")
                    self._close(code: .abnormalClosure)
                case let .success(message):
                    self.incomingMessageAsyncContinuation.yield(message)
                    self.receive()
                }
            }
        }
    }
    
    func _close(code: URLSessionWebSocketTask.CloseCode) {
        task?.cancel()
        webSocketTask.cancel(with: code, reason: nil)
        task = nil
    }
}

// MARK: WSDelegate
private extension WebSocketActor {
    final class WSDelegate: NSObject, URLSessionWebSocketDelegate {
        fileprivate let statusAsyncContinuation: AsyncStream<WebSocketState>.Continuation
        private let taskIdentifier: Int
        init(taskIdentifier: Int, statusAsyncContinuation: AsyncStream<WebSocketState>.Continuation) {
            self.taskIdentifier = taskIdentifier
            self.statusAsyncContinuation = statusAsyncContinuation
            super.init()
        }
    }
}


extension URLSessionWebSocketTask.CloseCode {
    func swiftify() -> WebSocketCloseCode {
        switch self {
        case .abnormalClosure:
            return .abnormalClosure
        case .invalid:
            return .invalid
        case .normalClosure:
            return .normalClosure
        case .goingAway:
            return .goingAway
        case .protocolError:
            return .protocolError
        case .unsupportedData:
            return .unsupportedData
        case .noStatusReceived:
            return .noStatusReceived
        case .invalidFramePayloadData:
            return .invalidFramePayloadData
        case .policyViolation:
            return .policyViolation
        case .messageTooBig:
            return .messageTooBig
        case .mandatoryExtensionMissing:
            return .mandatoryExtensionMissing
        case .internalServerError:
            return .internalServerError
        case .tlsHandshakeFailure:
            return .tlsHandshakeFailure
        @unknown default:
            fatalError("unknown unsupported WebSocketCloseCode: \(String(describing: self))")
        }
    }
}

extension WebSocketActor.WSDelegate {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        guard task.taskIdentifier == taskIdentifier else { return }
        statusAsyncContinuation.yield(.connecting)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard webSocketTask.taskIdentifier == taskIdentifier else { return }
        statusAsyncContinuation.yield(.connected)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask.taskIdentifier == taskIdentifier else { return }
        let reason = closeCode.swiftify()
        statusAsyncContinuation.yield(.closed(reason))
    }
}

// MARK: Public
public extension WebSocketActor {
    func close() {
        _close(code: .goingAway)
    }
    
    func send(data: Data) async throws {
        try await webSocketTask.send(.data(data))
    }
    
    // FIXME: Is this Intra-Task safe (or must we use an AsyncExtensions.Async(Throwing)BufferChannel?
    // FIXME: Are we sure to ONLY have one SINGLE CONSUMER? Else we must multicast!
    func readyStateAsyncSequence() -> AnyAsyncSequence<WebSocketState> {
        readyStateUpdates.eraseToAnyAsyncSequence()
    }
    
    // FIXME: Is this Intra-Task safe (or must we use an AsyncExtensions.Async(Throwing)BufferChannel?
    // FIXME: Are we sure to ONLY have one SINGLE CONSUMER? Else we must multicast!
    func incomingMessageAsyncSequence() -> AnyAsyncSequence<IncomingMessage> {
        incomingMessageAsyncStream.eraseToAnyAsyncSequence()
    }
}
