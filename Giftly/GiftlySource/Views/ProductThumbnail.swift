//
//  ProductThumbnail.swift
//  Giftly
//
//  Shows a product image from either a normal http(s) URL (via AsyncImage) or
//  a base64 "data:" URI (which AsyncImage can't load, so we decode it here).
//  Falls back to a gift-box placeholder when there's no image.
//

import SwiftUI

struct ProductThumbnail: View {
    let urlString: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let dataImage {
                Image(uiImage: dataImage).resizable().scaledToFill()
            } else if let url = httpURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: placeholder
                    case .empty: ProgressView()
                    @unknown default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }

    private var placeholder: some View {
        Image(systemName: "gift")
            .font(.system(size: size * 0.4))
            .foregroundStyle(.secondary)
    }

    // A "data:image/...;base64,...." URI → UIImage.
    private var dataImage: UIImage? {
        guard urlString.hasPrefix("data:"),
              let commaIdx = urlString.firstIndex(of: ","),
              case let b64 = String(urlString[urlString.index(after: commaIdx)...]),
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private var httpURL: URL? {
        guard urlString.hasPrefix("http") else { return nil }
        return URL(string: urlString)
    }
}
