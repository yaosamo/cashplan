import SwiftUI
import CoreMotion

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var tilt: CGSize = .zero

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            self?.tilt = CGSize(
                width:  CGFloat(data.gravity.x) * 14,
                height: CGFloat(data.gravity.z) * 10
            )
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}
