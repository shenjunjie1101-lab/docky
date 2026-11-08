//
//  SpacerTileView.swift
//  Docky
//

import SwiftUI
import Perception

struct SpacerTileView: View {
    var body: some View {
        WithPerceptionTracking {
            Color.clear
                .contentShape(.rect)
        }
    }
}
