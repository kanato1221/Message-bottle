//
//  BottleMessage.swift
//  short_diary
//

import Foundation

enum BottleStatus: String, Codable {
    case waiting
    case drifted
    case kept
    case releasedAlone
}

enum BottleColor: String, CaseIterable, Codable, Identifiable, Hashable {
    case seaGreen
    case amber
    case skyBlue
    case smoke
    case rose

    var id: String { rawValue }
}

struct BottleMessage: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var text: String
    var bottleColor: BottleColor = .seaGreen
    var createdAt: Date
    var availableToDriftAt: Date
    var driftedAt: Date?
    var status: BottleStatus
    var receivedBottle: ReceivedBottle?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case bottleColor
        case createdAt
        case availableToDriftAt
        case driftedAt
        case status
        case receivedBottle
    }

    init(
        id: UUID = UUID(),
        text: String,
        bottleColor: BottleColor = .seaGreen,
        createdAt: Date,
        availableToDriftAt: Date,
        driftedAt: Date? = nil,
        status: BottleStatus,
        receivedBottle: ReceivedBottle? = nil
    ) {
        self.id = id
        self.text = text
        self.bottleColor = bottleColor
        self.createdAt = createdAt
        self.availableToDriftAt = availableToDriftAt
        self.driftedAt = driftedAt
        self.status = status
        self.receivedBottle = receivedBottle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        bottleColor = try container.decodeIfPresent(BottleColor.self, forKey: .bottleColor) ?? .seaGreen
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        availableToDriftAt = try container.decode(Date.self, forKey: .availableToDriftAt)
        driftedAt = try container.decodeIfPresent(Date.self, forKey: .driftedAt)
        status = try container.decode(BottleStatus.self, forKey: .status)
        receivedBottle = try container.decodeIfPresent(ReceivedBottle.self, forKey: .receivedBottle)
    }

    var isReadyToDrift: Bool {
        Date() >= availableToDriftAt && status == .waiting
    }

}

struct ReceivedBottle: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var serverID: String?
    var text: String
    var bottleColor: BottleColor = .seaGreen
    var driftedAt: Date
    var isFavorite = false

    enum CodingKeys: String, CodingKey {
        case id
        case serverID
        case text
        case bottleColor
        case driftedAt
        case isFavorite
    }

    init(
        id: UUID = UUID(),
        serverID: String? = nil,
        text: String,
        bottleColor: BottleColor = .seaGreen,
        driftedAt: Date,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.serverID = serverID
        self.text = text
        self.bottleColor = bottleColor
        self.driftedAt = driftedAt
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        serverID = try container.decodeIfPresent(String.self, forKey: .serverID)
        text = try container.decode(String.self, forKey: .text)
        bottleColor = try container.decodeIfPresent(BottleColor.self, forKey: .bottleColor) ?? .seaGreen
        driftedAt = try container.decode(Date.self, forKey: .driftedAt)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

struct ReportedBottle: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var receivedBottleID: UUID
    var serverID: String?
    var text: String
    var reportedAt: Date
}
