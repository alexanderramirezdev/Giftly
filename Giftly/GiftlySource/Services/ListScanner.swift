//
//  ListScanner.swift
//  Giftly
//
//  Reads text off photos of a wish list, on device. Apple's Vision text
//  recognizer (accurate mode handles handwriting) pulls the raw lines, top to
//  bottom; GiftIntelligence.parseWishList then turns them into clean wishes.
//  Nothing leaves the phone.
//
//  Also hosts the document camera (VisionKit), which auto crops and
//  flattens the page. Requires NSCameraUsageDescription in Info.plist.
//

import SwiftUI
import UIKit
import Vision
import VisionKit

enum ListScanner {

    /// All recognized lines across the pages, in reading order.
    static func recognizeText(in images: [UIImage]) async -> String {
        var lines: [String] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let orientation = cgOrientation(for: image.imageOrientation)
            let pageLines = await Task.detached(priority: .userInitiated) {
                ListScanner.recognize(cgImage, orientation: orientation)
            }.value
            lines.append(contentsOf: pageLines)
        }
        return lines.joined(separator: "\n")
    }

    /// Runs Vision on one page. Sorted top to bottom so the list keeps its order.
    nonisolated static func recognize(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations: [VNRecognizedTextObservation] = request.results ?? []
        let sorted = observations.sorted { a, b in
            a.boundingBox.minY > b.boundingBox.minY   // Vision's origin is bottom left
        }
        var lines: [String] = []
        for observation in sorted {
            if let best = observation.topCandidates(1).first {
                lines.append(best.string)
            }
        }
        return lines
    }

    // MARK: Text message screenshots

    /// What a texted wish list looks like after reading the screenshots.
    struct Conversation {
        /// Lines tagged "Them:" (left bubbles) or "Me:" (right bubbles).
        var transcript: String
        /// The name shown at the top of the thread, if one was readable.
        var contactName: String
    }

    /// Reads screenshots of a Messages thread. Bubbles on the left are the
    /// other person, on the right are you; times, "Delivered", the status bar
    /// and other chrome are dropped.
    static func readConversation(in images: [UIImage]) async -> Conversation {
        var lines: [String] = []
        var contact = ""
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let orientation = cgOrientation(for: image.imageOrientation)
            let page = await Task.detached(priority: .userInitiated) {
                ListScanner.recognizeConversation(cgImage, orientation: orientation)
            }.value
            lines.append(contentsOf: page.lines)
            if contact.isEmpty { contact = page.contact }
        }
        return Conversation(transcript: lines.joined(separator: "\n"), contactName: contact)
    }

    nonisolated static func recognizeConversation(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) -> (lines: [String], contact: String) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do { try handler.perform([request]) } catch { return ([], "") }

        let observations: [VNRecognizedTextObservation] = (request.results ?? [])
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var lines: [String] = []
        var contact = ""
        var lastSide = ""
        var lastBottom: CGFloat = 2
        for o in observations {
            guard let text = o.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else { continue }
            let box = o.boundingBox            // normalized, origin bottom left
            // Status bar: the very top of the screen.
            if box.minY > 0.94 { continue }
            // Thread header: a short centered name near the top.
            if box.minY > 0.80 {
                if contact.isEmpty, abs(box.midX - 0.5) < 0.15, text.count <= 30, !isChrome(text) {
                    contact = text
                }
                continue
            }
            // Keyboard or the "iMessage" field at the bottom.
            if box.maxY < 0.07 { continue }
            if isChrome(text) { continue }

            let side: String
            if box.minX > 0.30 && box.midX > 0.55 { side = "Me" }
            else if box.maxX < 0.75 && box.midX < 0.48 { side = "Them" }
            else { side = lastSide.isEmpty ? "Them" : lastSide }

            // A bubble that wraps onto a second line continues the same message.
            let gap = lastBottom - box.maxY
            if side == lastSide, gap < 0.02, var previous = lines.popLast() {
                previous += " " + text
                lines.append(previous)
            } else {
                lines.append("\(side): \(text)")
            }
            lastSide = side
            lastBottom = box.minY
        }
        return (lines, contact)
    }

    /// Times, read receipts and other Messages labels that aren't anything anyone said.
    nonisolated static func isChrome(_ text: String) -> Bool {
        let t = text.lowercased()
        let exact: Set<String> = ["delivered", "read", "imessage", "text message", "today", "yesterday",
                                  "edited", "sent", "not delivered", "sms", "rcs", "keep", "copy",
                                  "reply", "more", "undo send", "message", "details", "<", "‹"]
        if exact.contains(t) { return true }
        if t.hasPrefix("read ") || t.hasPrefix("delivered ") || t.hasPrefix("today ") || t.hasPrefix("yesterday ") { return true }
        if t.hasPrefix("text message ") || t.hasPrefix("imessage ") { return true }
        if t.range(of: #"^\d{1,2}:\d{2}\s?(am|pm)?$"#, options: .regularExpression) != nil { return true }
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        if days.contains(where: { t.hasPrefix($0) }) && t.contains(":") { return true }
        if t.range(of: #"^[a-z]{3}, [a-z]{3} \d{1,2}"#, options: .regularExpression) != nil { return true }
        return false
    }

    nonisolated static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}

// MARK: - Document camera

/// VisionKit's document scanner: finds the page edges, crops and flattens.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        init(_ parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
