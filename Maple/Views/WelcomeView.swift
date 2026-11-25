//
//  WelcomeView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct WelcomeView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 80, height: 80)

            Text("AnyGit")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Open a Git repository to get started")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Open Repository...") {
                openFolderPicker(state: state)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
