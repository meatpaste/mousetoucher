import Foundation

/// User-adjustable settings, persisted in UserDefaults.
enum Preferences {
    static let rightClickThresholdKey = "rightClickThreshold"

    /// Fraction of the mouse surface (0-1) to the left of which taps count as a left click.
    /// A tap with normalized x above this value is a right click.
    static let defaultRightClickThreshold: Float = 0.6

    /// Values offered in the menu bar. Anything set outside this list (e.g. via
    /// `defaults write com.mousetoucher.app rightClickThreshold 0.75`) is still honoured.
    static let rightClickThresholdChoices: [Float] = [0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

    static let minRightClickThreshold: Float = 0.1
    static let maxRightClickThreshold: Float = 0.95

    static var rightClickThreshold: Float {
        get {
            guard UserDefaults.standard.object(forKey: rightClickThresholdKey) != nil else {
                return defaultRightClickThreshold
            }
            return clamp(UserDefaults.standard.float(forKey: rightClickThresholdKey))
        }
        set {
            UserDefaults.standard.set(clamp(newValue), forKey: rightClickThresholdKey)
        }
    }

    static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return defaultRightClickThreshold }
        return min(max(value, minRightClickThreshold), maxRightClickThreshold)
    }
}
