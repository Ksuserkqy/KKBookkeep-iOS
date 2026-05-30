import CoreLocation
import Combine
import Foundation

@MainActor
final class CurrentLocationProvider: NSObject, ObservableObject {
    enum ProviderError: Error {
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<CapturedLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func captureLocation() async throws -> DraftLocation {
        let capturedLocation = try await requestCurrentLocation()
        let location = CLLocation(latitude: capturedLocation.latitude, longitude: capturedLocation.longitude)
        let address = await resolvedAddress(for: location)
        let displayName = address ?? Self.coordinateText(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        return DraftLocation(
            displayName: displayName,
            address: address ?? "",
            latitude: capturedLocation.latitude,
            longitude: capturedLocation.longitude,
            horizontalAccuracy: capturedLocation.horizontalAccuracy,
            capturedAt: Date()
        )
    }

    private func requestCurrentLocation() async throws -> CapturedLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw ProviderError.unavailable
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            return try await waitForLocation {
                manager.requestWhenInUseAuthorization()
            }
        case .restricted, .denied:
            throw ProviderError.denied
        case .authorizedAlways, .authorizedWhenInUse:
            return try await waitForLocation {
                manager.requestLocation()
            }
        @unknown default:
            throw ProviderError.unavailable
        }
    }

    private func waitForLocation(start: () -> Void) async throws -> CapturedLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(throwing: ProviderError.unavailable)
            self.continuation = continuation
            start()
        }
    }

    private func resolvedAddress(for location: CLLocation) async -> String? {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }

        let address = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
        .compactMap { item in
            let trimmed = item?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .removingDuplicates()
        .joined(separator: " ")

        return address.isEmpty ? nil : address
    }

    private static func coordinateText(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }

    private func finish(with result: Result<CapturedLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension CurrentLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                if continuation != nil {
                    self.manager.requestLocation()
                }
            case .restricted, .denied:
                finish(with: .failure(ProviderError.denied))
            case .notDetermined:
                break
            @unknown default:
                finish(with: .failure(ProviderError.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let capturedLocation = locations.last.map { location in
            CapturedLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy
            )
        }

        Task { @MainActor in
            guard let capturedLocation else {
                finish(with: .failure(ProviderError.unavailable))
                return
            }

            finish(with: .success(capturedLocation))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(with: .failure(error))
        }
    }
}

private struct CapturedLocation: Sendable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
