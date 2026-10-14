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
            content()
                .offset(x: offset)
                .simultaneousGesture(drag)

            // While open: the Delete button sits on top, and the rest of the
            // row is a tap catcher that just closes it. (Before, the tap
            // catcher covered the button too, so Delete only closed the row.)
            if offset < 0 {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .gesture(drag)
                    deleteButton
                }
                .transition(.opacity)
            }
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
                Haptics.success()
                offset = 0
                startOffset = 0
                onDelete()
            }
            Button("Cancel", role: .cancel) { close() }
        } message: {
            if !detail.isEmpty { Text(detail) }
        }
    }

    private var deleteButton: some View {
        Button {
            Haptics.tap()
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityLabel("Delete \(itemName)")
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
