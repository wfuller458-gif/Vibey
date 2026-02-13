//
//  UpdateBanner.swift
//  Vibey
//
//  Full-width yellow banner shown when a new version is available
//

import SwiftUI

struct UpdateBanner: View {
    let version: String
    @Environment(\.openURL) var openURL

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.black)

            Text("Update available (v\(version))")
                .font(.atkinsonRegular(size: 14, comicSans: false))
                .foregroundColor(.black)

            Spacer()

            Button("Download") {
                if let url = URL(string: "https://vibey.codes") {
                    openURL(url)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
            .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.yellow)
    }
}
