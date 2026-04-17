import Foundation

public extension Track {
    /// A canned ~30-point track from a test sail around the San Francisco
    /// Bay. Good enough for SwiftUI previews and early map styling work
    /// without any network.
    static let preview: Track = {
        let start = ISO8601DateFormatter().date(from: "2026-04-17T14:00:00Z")!
        let coords: [(lat: Double, lon: Double)] = [
            (37.8080, -122.4420), (37.8090, -122.4410), (37.8100, -122.4400),
            (37.8110, -122.4390), (37.8118, -122.4378), (37.8124, -122.4365),
            (37.8128, -122.4350), (37.8131, -122.4335), (37.8133, -122.4320),
            (37.8134, -122.4305), (37.8135, -122.4290), (37.8136, -122.4275),
            (37.8138, -122.4260), (37.8141, -122.4245), (37.8145, -122.4230),
            (37.8150, -122.4216), (37.8156, -122.4204), (37.8163, -122.4193),
            (37.8170, -122.4184), (37.8176, -122.4176), (37.8180, -122.4169),
            (37.8182, -122.4163), (37.8181, -122.4157), (37.8178, -122.4151),
            (37.8172, -122.4146), (37.8164, -122.4143), (37.8155, -122.4143),
            (37.8145, -122.4148), (37.8136, -122.4157), (37.8130, -122.4170),
        ]
        let coordinates = coords.map { TrackCoordinate(latitude: $0.lat, longitude: $0.lon) }
        let timestamps = (0..<coordinates.count).map {
            start.addingTimeInterval(Double($0) * 10)
        }
        return Track(sessionId: 1, coordinates: coordinates, timestamps: timestamps)
    }()
}
