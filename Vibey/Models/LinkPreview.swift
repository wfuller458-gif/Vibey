//
//  LinkPreview.swift
//  Vibey
//
//  Model and service for fetching Open Graph link previews
//

import Foundation
import AppKit

// MARK: - Link Preview Data

struct LinkPreviewData: Codable, Equatable {
    let url: String
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let domain: String

    init(url: String, title: String? = nil, description: String? = nil, imageURL: String? = nil, siteName: String? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName

        // Extract domain from URL
        if let urlObj = URL(string: url), let host = urlObj.host {
            self.domain = host.replacingOccurrences(of: "www.", with: "")
        } else {
            self.domain = url
        }
    }
}

// MARK: - Open Graph Fetcher

class LinkPreviewService {
    static let shared = LinkPreviewService()

    private var cache: [String: LinkPreviewData] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    /// Fetch Open Graph metadata for a URL
    func fetchPreview(for urlString: String, completion: @escaping (LinkPreviewData?) -> Void) {
        // Check cache first
        if let cached = cache[urlString] {
            completion(cached)
            return
        }

        // Normalize URL
        var normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedURL.lowercased().hasPrefix("www.") {
            normalizedURL = "https://" + normalizedURL
        }
        if !normalizedURL.lowercased().hasPrefix("http://") && !normalizedURL.lowercased().hasPrefix("https://") {
            normalizedURL = "https://" + normalizedURL
        }

        guard let url = URL(string: normalizedURL) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let preview = self?.parseOpenGraph(html: html, originalURL: urlString)

            // Cache the result
            if let preview = preview {
                self?.cache[urlString] = preview
            }

            DispatchQueue.main.async {
                completion(preview)
            }
        }.resume()
    }

    /// Parse Open Graph meta tags from HTML
    private func parseOpenGraph(html: String, originalURL: String) -> LinkPreviewData {
        let title = extractMetaContent(html: html, property: "og:title")
            ?? extractMetaContent(html: html, name: "title")
            ?? extractTitleTag(html: html)

        let description = extractMetaContent(html: html, property: "og:description")
            ?? extractMetaContent(html: html, name: "description")

        let imageURL = extractMetaContent(html: html, property: "og:image")
            ?? extractMetaContent(html: html, name: "twitter:image")

        let siteName = extractMetaContent(html: html, property: "og:site_name")

        return LinkPreviewData(
            url: originalURL,
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName
        )
    }

    /// Extract content from meta tag with property attribute
    private func extractMetaContent(html: String, property: String) -> String? {
        // Match: <meta property="og:title" content="...">
        let pattern = "<meta[^>]*property=[\"']\(property)[\"'][^>]*content=[\"']([^\"']*)[\"']"
        let altPattern = "<meta[^>]*content=[\"']([^\"']*)[\"'][^>]*property=[\"']\(property)[\"']"

        if let match = html.range(of: pattern, options: .regularExpression) {
            let matchString = String(html[match])
            return extractContentValue(from: matchString)
        }

        if let match = html.range(of: altPattern, options: .regularExpression) {
            let matchString = String(html[match])
            return extractContentValue(from: matchString)
        }

        return nil
    }

    /// Extract content from meta tag with name attribute
    private func extractMetaContent(html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=[\"']\(name)[\"'][^>]*content=[\"']([^\"']*)[\"']"
        let altPattern = "<meta[^>]*content=[\"']([^\"']*)[\"'][^>]*name=[\"']\(name)[\"']"

        if let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let matchString = String(html[match])
            return extractContentValue(from: matchString)
        }

        if let match = html.range(of: altPattern, options: [.regularExpression, .caseInsensitive]) {
            let matchString = String(html[match])
            return extractContentValue(from: matchString)
        }

        return nil
    }

    /// Extract <title> tag content
    private func extractTitleTag(html: String) -> String? {
        let pattern = "<title[^>]*>([^<]*)</title>"
        if let match = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let matchString = String(html[match])
            // Extract content between tags
            if let start = matchString.range(of: ">"),
               let end = matchString.range(of: "</", options: .backwards) {
                let content = String(matchString[start.upperBound..<end.lowerBound])
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Extract content attribute value from meta tag string
    private func extractContentValue(from metaTag: String) -> String? {
        let pattern = "content=[\"']([^\"']*)[\"']"
        if let match = metaTag.range(of: pattern, options: .regularExpression) {
            let matchString = String(metaTag[match])
            // Remove content=" and trailing "
            let value = matchString
                .replacingOccurrences(of: "content=\"", with: "")
                .replacingOccurrences(of: "content='", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : decodeHTMLEntities(value)
        }
        return nil
    }

    /// Decode common HTML entities
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " "
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    /// Fetch image from URL
    func fetchImage(from urlString: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}
