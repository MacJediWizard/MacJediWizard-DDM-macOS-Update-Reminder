//
//  URLValidationTests.swift
//  DDMmacOSUpdateReminderTests
//
//  Unit tests for URL validation (security-critical)
//
//  Copyright (c) 2025 MacJediWizard. MIT License.
//

import XCTest
@testable import DDMNotifier

final class URLValidationTests: XCTestCase {

    // MARK: - Valid URLs

    func testValidHTTPSURLs() {
        let validURLs = [
            "https://example.com/icon.png",
            "https://ics.services.jamfcloud.com/icon/hash_abc123",
            "https://cdn.example.org/images/banner.jpg",
            "https://example.com:8443/path/to/image.png",
            "https://sub.domain.example.com/image.png"
        ]

        for url in validURLs {
            XCTAssertTrue(isValidURL(url), "URL should be valid: \(url)")
        }
    }

    func testValidHTTPURLs() {
        let validURLs = [
            "http://example.com/icon.png",
            "http://internal.corp/images/logo.png"
        ]

        for url in validURLs {
            XCTAssertTrue(isValidURL(url), "HTTP URL should be valid (for compatibility): \(url)")
        }
    }

    // MARK: - Invalid URLs

    func testInvalidSchemes() {
        let invalidURLs = [
            "file:///etc/passwd",
            "file:///Library/icons/icon.png",
            "ftp://example.com/icon.png",
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "ssh://user@host.com"
        ]

        for url in invalidURLs {
            XCTAssertFalse(isValidURL(url), "URL should be invalid (bad scheme): \(url)")
        }
    }

    func testShellMetacharacterInjection() {
        let maliciousURLs = [
            "https://example.com/icon.png; rm -rf /",
            "https://example.com/icon.png | cat /etc/passwd",
            "https://example.com/icon.png & whoami",
            "https://example.com/$(whoami)/icon.png",
            "https://example.com/`id`/icon.png",
            "https://example.com/icon.png\necho pwned",
            "https://example.com/icon.png\recho pwned",
            "https://example.com/'icon'.png",
            "https://example.com/\"icon\".png",
            "https://example.com/icon{}.png",
            "https://example.com/icon[].png",
            "https://example.com/<script>.png",
            "https://example.com/icon>.png"
        ]

        for url in maliciousURLs {
            XCTAssertFalse(isValidURL(url), "URL should be invalid (shell metacharacters): \(url)")
        }
    }

    func testEmptyAndMalformedURLs() {
        let invalidURLs = [
            "",
            "not-a-url",
            "://missing-scheme",
            "https://",  // No host
            "https:///path/only"
        ]

        for url in invalidURLs {
            XCTAssertFalse(isValidURL(url), "URL should be invalid (malformed): \(url)")
        }
    }

    // MARK: - Edge Cases

    func testURLsWithQueryStrings() {
        // Query strings without dangerous characters should be OK
        XCTAssertTrue(isValidURL("https://example.com/icon.png?size=256"))
        XCTAssertTrue(isValidURL("https://example.com/icon.png?v=1.0.0"))
    }

    func testURLsWithFragments() {
        XCTAssertTrue(isValidURL("https://example.com/page#section"))
    }

    func testURLsWithEncodedCharacters() {
        XCTAssertTrue(isValidURL("https://example.com/icon%20name.png"))
    }

    // MARK: - Helper Function

    /// Reimplementation of DialogController.isValidURL for testing
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return false
        }

        // Check for shell metacharacters that could be dangerous
        let dangerousChars = CharacterSet(charactersIn: ";|&`$(){}[]<>\\'\"\n\r")
        return urlString.rangeOfCharacter(from: dangerousChars) == nil
    }
}
