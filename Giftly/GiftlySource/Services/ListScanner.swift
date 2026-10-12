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
