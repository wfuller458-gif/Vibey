//
//  VibeyLogo.swift
//  Vibey
//
//  Reusable logo component matching Figma design
//  Shows the blue icon + "Vibey.code" text
//

import SwiftUI

struct VibeyLogo: View {
    var body: some View {
        // Use actual Vibey logo from assets
        Image("VibeyLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 44.308)
    }
}

#Preview {
    VibeyLogo()
        .padding()
        .background(Color.vibeyBackground)
}
