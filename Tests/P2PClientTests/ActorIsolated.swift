/*
 MIT License

 Copyright (c) 2020 Point-Free, Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

// FROM: https://github.com/pointfreeco/swift-composable-architecture/blob/53ddc5904c065190d05c035ca0e4589cb6d45d61/Sources/ComposableArchitecture/Effects/ConcurrencySupport.swift

/// A generic wrapper for isolating a mutable value to an actor.
///
/// This type is most useful when writing tests for when you want to inspect what happens inside
/// an effect. For example, suppose you have a feature such that when a button is tapped you
/// track some analytics:
///
/// ```swift
/// @Dependency(\.analytics) var analytics
///
/// func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
///   switch action {
///   case .buttonTapped:
///     return .fireAndForget { try await self.analytics.track("Button Tapped") }
///   }
/// }
/// ```
///     
/// Then, in tests we can construct an analytics client that appends events to a mutable array
/// rather than actually sending events to an analytics server. However, in order to do this in
/// a safe way we should use an actor, and ``ActorIsolated`` makes this easy:
///
/// ```swift
/// @MainActor
/// func testAnalytics() async {
///   let store = TestStore(…)
///
///   let events = ActorIsolated<[String]>([])
///   store.dependencies.analytics = AnalyticsClient(
///     track: { event in
///       await events.withValue { $0.append(event) }
///     }
///   )
///
///   await store.send(.buttonTapped)
///
///   await events.withValue { XCTAssertEqual($0, ["Button Tapped"]) }
/// }
/// ```
@dynamicMemberLookup
public final actor ActorIsolated<Value: Sendable> {
  /// The actor-isolated value.
  public var value: Value

  /// Initializes actor-isolated state around a value.
  ///
  /// - Parameter value: A value to isolate in an actor.
  public init(_ value: Value) {
    self.value = value
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  /// Perform an operation with isolated access to the underlying value.
  ///
  /// Useful for inspecting an actor-isolated value for a test assertion:
  ///
  /// ```swift
  /// let didOpenSettings = ActorIsolated(false)
  /// store.dependencies.openSettings = { await didOpenSettings.setValue(true) }
  ///
  /// await store.send(.settingsButtonTapped)
  ///
  /// await didOpenSettings.withValue { XCTAssertTrue($0) }
  /// ```
  ///
  /// - Parameters: operation: An operation to be performed on the actor with the underlying value.
  /// - Returns: The result of the operation.
  public func withValue<T: Sendable>(
    _ operation: @Sendable (inout Value) async throws -> T
  ) async rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try await operation(&value)
  }

  /// Overwrite the isolated value with a new value.
  ///
  /// Useful for setting an actor-isolated value when a tested dependency runs.
  ///
  /// ```swift
  /// let didOpenSettings = ActorIsolated(false)
  /// store.dependencies.openSettings = { await didOpenSettings.setValue(true) }
  ///
  /// await store.send(.settingsButtonTapped)
  ///
  /// await didOpenSettings.withValue { XCTAssertTrue($0) }
  /// ```
  ///
  /// - Parameter newValue: The value to replace the current isolated value with.
  public func setValue(_ newValue: Value) {
    self.value = newValue
  }
}

/// A generic wrapper for turning any non-`Sendable` type into a `Sendable` one, in an unchecked
/// manner.
///
/// Sometimes we need to use types that should be sendable but have not yet been audited for
/// sendability. If we feel confident that the type is truly sendable, and we don't want to blanket
/// disable concurrency warnings for a module via `@preconcurrency import`, then we can selectively
/// make that single type sendable by wrapping it in ``UncheckedSendable``.
///
/// > Note: By wrapping something in ``UncheckedSendable`` you are asking the compiler to trust
/// you that the type is safe to use from multiple threads, and the compiler cannot help you find
/// potential race conditions in your code.
@dynamicMemberLookup
@propertyWrapper
public struct UncheckedSendable<Value>: @unchecked Sendable {
  /// The unchecked value.
  public var value: Value

  public init(_ value: Value) {
    self.value = value
  }

  public init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  public var wrappedValue: Value {
    _read { yield self.value }
    _modify { yield &self.value }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> Subject {
    self.value[keyPath: keyPath]
  }

  public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Subject {
    _read { yield self.value[keyPath: keyPath] }
    _modify { yield &self.value[keyPath: keyPath] }
  }
}
