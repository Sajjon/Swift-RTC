public extension AsyncStream {
    
    /// Constructs and returns a stream along with its backing continuation.
    ///
    /// This is handy for immediately escaping the continuation from an async stream, which typically
    /// requires multiple steps:
    ///
    /// ```swift
    /// var _continuation: AsyncStream<Int>.Continuation!
    /// let stream = AsyncStream<Int> { continuation = $0 }
    /// let continuation = _continuation!
    ///
    /// // vs.
    ///
    /// let (stream, continuation) = AsyncStream<Int>.streamWithContinuation()
    /// ```
    ///
    /// This tool is usually used for tests where we need to supply an async sequence to a dependency
    /// endpoint and get access to its continuation so that we can emulate the dependency
    /// emitting data. For example, suppose you have a dependency exposing an async sequence for
    /// listening to notifications. To test this you can use `streamWithContinuation`:
    ///
    /// ```swift
    /// let notifications = AsyncStream<Void>.streamWithContinuation()
    ///
    /// let store = TestStore(
    ///   initialState: Feature.State(),
    ///   reducer: Feature()
    /// )
    ///
    /// store.dependencies.notifications = { notifications.stream }
    ///
    /// await store.send(.task)
    /// notifications.continuation.yield("Hello")  // Simulate notification being posted
    /// await store.receive(.notification("Hello")) {
    ///   $0.message = "Hello"
    /// }
    /// ```
    ///
    /// > Warning: ⚠️ `AsyncStream` does not support multiple subscribers, therefore you can only use
    /// > this helper to test features that do not subscribe multiple times to the dependency
    /// > endpoint.
    ///
    /// - Parameters:
    ///   - elementType: The type of element the `AsyncStream` produces.
    ///   - limit: A Continuation.BufferingPolicy value to set the stream’s buffering behavior. By
    ///   default, the stream buffers an unlimited number of elements. You can also set the policy to
    ///   buffer a specified number of oldest or newest elements.
    /// - Returns: An `AsyncStream`.
    static func streamWithContinuation(
      _ elementType: Element.Type = Element.self,
      bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: Self, continuation: Continuation) {
      var continuation: Continuation!
      return (Self(elementType, bufferingPolicy: limit) { continuation = $0 }, continuation)
    }
}
