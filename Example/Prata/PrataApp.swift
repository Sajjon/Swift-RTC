//
//  PrataApp.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-08-31.
//

import SwiftUI
import ComposableArchitecture
typealias AppProtocol = SwiftUI.App

@main
struct PrataApp: AppProtocol {
    var body: some Scene {
        WindowGroup {
            App.View(
                store: Store(
                    initialState: App.State(),
                    reducer: AnyReducer(
                        App() //._printChanges()
                    ),
                    environment: ()
                )
            )
            #if os(macOS)
            .frame(minWidth: 1024, minHeight: 768)
            .fixedSize(horizontal: false, vertical: false)
            #endif // macOS
            .padding()
            .textFieldStyle(.roundedBorder)
            .buttonStyle(.borderedProminent)
        }
    }
}
