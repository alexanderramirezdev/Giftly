//
//  SwipeToDelete.swift
//  Giftly
//
//  Swipe left to delete for rows that live in cards (not a List, where
//  swipeActions would do this). A confirmation guards the delete, and a long
//  press offers the same Delete for anyone who doesn't swipe.
//

import SwiftUI

struct SwipeToDelete<Content: View>: View {
    let itemName: String
    var detail: String = ""
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var confirming = false

    private let revealWidth: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    confirming = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Delete").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .transition(.opacity)
            }

            content()
                .offset(x: offset)
                .overlay {
                    // While open, a tap anywhere on the row just closes it.
                    if offset < 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { close() }
                    }
                }
                .simultaneousGesture(drag)
        }
        .clipped()
        .contextMenu {
            Button(role: .destructive) {
                confirming = true
            } label: {
                Label("Delete \(itemName)", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Delete \(itemName)") { confirming = true }
        .confirmationDialog("Delete \(itemName)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                Haptics.success()
                onDelete()
            }
            Button("Cancel", role: .cancel) { close() }
        } message: {
            if !detail.isEmpty { Text(detail) }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let dx = value.translation.width
                // Only horizontal swipes; vertical drags keep scrolling the page.
                guard abs(dx) > abs(value.translation.height) * 1.5 else { return }
                offset = min(0, max(-revealWidth - 30, startOffset + dx))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    offset = offset < -revealWidth / 2 ? -revealWidth : 0
                }
                startOffset = offset
                if offset < 0 { Haptics.tap() }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
        startOffset = 0
    }
}
