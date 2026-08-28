//
//  BottleExchangeService.swift
//  short_diary
//

import Foundation
import FirebaseAuth

struct BottleExchangeService {
    private let exchangeURL = URL(string: "https://exchangebottle-2c27cj2ouq-an.a.run.app")!
    private let reportURL = URL(string: "https://reportbottle-2c27cj2ouq-an.a.run.app")!
    private let blockURL = URL(string: "https://asia-northeast1-shortdiary-66f95.cloudfunctions.net/blockBottleSender")!
    private let returnURL = URL(string: "https://asia-northeast1-shortdiary-66f95.cloudfunctions.net/returnBottleToSea")!

    func exchange(bottle: BottleMessage, clientID: String) async throws -> ReceivedBottle {
        let requestBody = ExchangeBottleRequest(
            text: bottle.text,
            bottleColor: bottle.bottleColor.rawValue,
            driftedAt: ISO8601DateFormatter().string(from: Date())
        )

        let response: ExchangeBottleResponse = try await post(requestBody, to: exchangeURL)
        return response.deliveredBottle.receivedBottle
    }

    func report(bottle: ReceivedBottle, clientID: String) async throws {
        guard let serverID = bottle.serverID else { return }

        let requestBody = ReportBottleRequest(bottleID: serverID)
        let _: ReportBottleResponse = try await post(requestBody, to: reportURL)
    }

    func blockSender(of bottle: ReceivedBottle, clientID: String) async throws {
        guard let serverID = bottle.serverID else { return }

        let requestBody = BlockBottleSenderRequest(bottleID: serverID)
        let _: BlockBottleSenderResponse = try await post(requestBody, to: blockURL)
    }

    func returnToSea(_ bottle: ReceivedBottle, clientID: String) async throws {
        guard let serverID = bottle.serverID else { return }

        let requestBody = ReturnBottleRequest(bottleID: serverID)
        let _: ReturnBottleResponse = try await post(requestBody, to: returnURL)
    }

    private func post<Request: Encodable, Response: Decodable>(_ body: Request, to url: URL) async throws -> Response {
        guard let user = Auth.auth().currentUser else {
            throw BottleExchangeError.notSignedIn
        }

        let idToken = try await user.getIDToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BottleExchangeError.serverError
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let serverError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data),
               serverError.error == "unsafe-content" {
                throw BottleExchangeError.unsafeContent
            }
            throw BottleExchangeError.serverError
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum BottleExchangeError: Error {
    case notSignedIn
    case unsafeContent
    case serverError
}

private struct ServerErrorResponse: Decodable {
    var error: String
}

private struct ExchangeBottleRequest: Encodable {
    var text: String
    var bottleColor: String
    var driftedAt: String
}

private struct ExchangeBottleResponse: Decodable {
    var deliveredBottle: DeliveredBottleResponse
}

private struct DeliveredBottleResponse: Decodable {
    var serverID: String?
    var text: String
    var bottleColor: String?
    var driftedAt: String

    var receivedBottle: ReceivedBottle {
        let date = ISO8601DateFormatter().date(from: driftedAt) ?? Date()

        return ReceivedBottle(
            serverID: serverID,
            text: text,
            bottleColor: BottleColor(rawValue: bottleColor ?? "") ?? .seaGreen,
            driftedAt: date
        )
    }
}

private struct ReportBottleRequest: Encodable {
    var bottleID: String
}

private struct ReportBottleResponse: Decodable {
    var ok: Bool
}

private struct BlockBottleSenderRequest: Encodable {
    var bottleID: String
}

private struct BlockBottleSenderResponse: Decodable {
    var ok: Bool
}

private struct ReturnBottleRequest: Encodable {
    var bottleID: String
}

private struct ReturnBottleResponse: Decodable {
    var ok: Bool
    var redistributed: Bool?
    var reason: String?
}
