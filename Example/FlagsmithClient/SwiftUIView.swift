//
//  SwiftUIView.swift
//  FlagsmithClient_Example
//
//  Created by Gareth Reese on 16/09/2024.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

#if canImport(SwiftUI)
    import SwiftUI
#endif
import FlagsmithClient

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *)
struct SwiftUIView: View {
    @State private var flags: [Flag] = []
    @State private var isLoading = true

    let flagsmith = Flagsmith.shared

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                Text("Feature Flags")
                    .font(.title)
                    .padding()
                List(flags, id: \.feature.name) { flag in
                    HStack {
                        Text("\(flag.feature.name): \(flag.value)")
                        Spacer()
                        Text("\(flag.enabled ? "✅" : "❌")")
                    }
                }
            }
        }
        .onAppear {
            initializeFlagsmith()
            subscribeToFlagUpdates()
        }
    }

    func initializeFlagsmith() {
        // Fetch initial flags
        flagsmith.getFeatureFlags { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedFlags):
                    flags = fetchedFlags
                case .failure(let error):
                    print("Error fetching flags: \(error)")
                }
                isLoading = false
            }
        }
    }

    func subscribeToFlagUpdates() {
        Task {
            for await updatedFlags in flagsmith.flagStream {
                DispatchQueue.main.async {
                    flags = updatedFlags
                }
            }
        }
    }
}
