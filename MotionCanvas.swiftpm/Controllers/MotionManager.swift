import CoreMotion
import SwiftUI

// MARK: - MotionManager


@MainActor
class MotionManager: ObservableObject {
    nonisolated(unsafe) private let manager = CMMotionManager()
    nonisolated(unsafe) private let queue   = OperationQueue()

    @Published var pitch: Double = 0   // x-axis tilt (forward/back)
    @Published var roll:  Double = 0   // y-axis tilt (left/right)
    @Published var yaw:   Double = 0   // z-axis rotation

    @Published var accelX: Double = 0
    @Published var accelY: Double = 0
    @Published var accelZ: Double = 0

    @Published var shakeIntensity: Double = 0

    /// Smoothed tilt values — ideal for painting (removes jitter).
    @Published var smoothPitch: Double = 0
    @Published var smoothRoll:  Double = 0

    private var smoothingFactor  = 0.15
    private var rawAccelHistory: [Double] = []

    var combinedTiltMagnitude: Double { sqrt(pitch * pitch + roll * roll) }

    // MARK: - Start / Stop

    nonisolated func startUpdates() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let pitchVal = motion.attitude.pitch
            let rollVal  = motion.attitude.roll
            let yawVal   = motion.attitude.yaw
            let ax = motion.userAcceleration.x
            let ay = motion.userAcceleration.y
            let az = motion.userAcceleration.z
            let accelMag = sqrt(ax * ax + ay * ay + az * az)

            Task { @MainActor in
                self.pitch  = pitchVal
                self.roll   = rollVal
                self.yaw    = yawVal
                self.accelX = ax
                self.accelY = ay
                self.accelZ = az

                self.smoothPitch += (self.pitch - self.smoothPitch) * self.smoothingFactor
                self.smoothRoll  += (self.roll  - self.smoothRoll)  * self.smoothingFactor

                self.rawAccelHistory.append(accelMag)
                if self.rawAccelHistory.count > 10 { self.rawAccelHistory.removeFirst() }
                self.shakeIntensity = self.rawAccelHistory.max() ?? 0
            }
        }
    }

    nonisolated func startAccelerometerUpdates() {
        guard manager.isAccelerometerAvailable else { return }
        manager.accelerometerUpdateInterval = 1.0 / 60.0
        manager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let ax = data.acceleration.x
            let ay = data.acceleration.y
            let az = data.acceleration.z
            Task { @MainActor in
                self.accelX = ax
                self.accelY = ay
                self.accelZ = az
            }
        }
    }

    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
        manager.stopAccelerometerUpdates()
    }
}
