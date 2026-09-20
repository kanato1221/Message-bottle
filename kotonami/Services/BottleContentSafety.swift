//
//  BottleContentSafety.swift
//  kotonami
//

import Foundation

enum BottleContentSafety {
    private static let unsafePatterns = [
        #"(https?://|www\.|[\w.-]+@[\w.-]+|\d{2,4}[-\s]\d{2,4}[-\s]\d{3,4})"#,
        #"(?:line|instagram|insta|discord|telegram|twitter|tiktok|snapchat|kakao)(?:\s*[:：@＠_-]\s*|\s+id\s*)[a-z0-9._-]{2,}"#,
        #"(?:死ね|しね|殺す|ころす|消えろ|自殺|首をつる|リスカ)"#,
        #"(?:セックス|性交|裸|ヌード|エロ|猥褻|援助交際)"#,
        #"(?:覚醒剤|大麻|麻薬|ドラッグ|犯罪予告|爆破予告)"#,
        #"(?:家に来い|会おう|住所教え|連絡先教え)"#
    ]

    static func containsUnsafeContent(_ text: String) -> Bool {
        let normalized = text.precomposedStringWithCompatibilityMapping
        return unsafePatterns.contains { pattern in
            normalized.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }
}
