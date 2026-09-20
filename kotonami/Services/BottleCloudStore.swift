//
//  BottleCloudStore.swift
//  kotonami
//

import FirebaseFirestore
import Foundation

struct BottleCloudStore {
    private let database = Firestore.firestore()

    func loadBottles(for userID: String) async throws -> [BottleMessage]? {
        let snapshot = try await storeDocument(for: userID).getDocument()
        guard let bottlesJSON = snapshot.data()?["bottlesJSON"] as? String,
              let data = bottlesJSON.data(using: .utf8) else {
            return nil
        }

        return try JSONDecoder().decode([BottleMessage].self, from: data)
    }

    func saveBottles(_ bottles: [BottleMessage], for userID: String) async throws {
        let data = try JSONEncoder().encode(bottles)
        guard let bottlesJSON = String(data: data, encoding: .utf8) else { return }

        try await storeDocument(for: userID).setData([
            "bottlesJSON": bottlesJSON,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func storeDocument(for userID: String) -> DocumentReference {
        database
            .collection("users")
            .document(userID)
            .collection("private")
            .document("bottleStore")
    }
}
