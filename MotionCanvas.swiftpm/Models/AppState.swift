import SwiftUI

// MARK: - AppState


class AppState: ObservableObject {
    @Published var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @Published var highScores: [String: Int] = [:]

    func completeOnboarding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }

    @discardableResult
    func saveHighScore(mode: String, score: Int) -> Bool {
        let current = highScores[mode] ?? 0
        if score > current {
            highScores[mode] = score
            var all = (UserDefaults.standard.dictionary(forKey: "highScores") as? [String: Int]) ?? [:]
            all[mode] = score
            UserDefaults.standard.set(all, forKey: "highScores")
            return true
        }
        return false
    }

    func loadHighScores() {
        highScores = (UserDefaults.standard.dictionary(forKey: "highScores") as? [String: Int]) ?? [:]
    }
}
