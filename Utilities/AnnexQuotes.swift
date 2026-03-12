import Foundation

class AnnexQuotes {
    static let shared = AnnexQuotes()
    
    private let defaults = UserDefaults.standard
    private let personalityKey = "showAnnexPersonality"
    private var usedSyncCompleteIndices: Set<Int> = []
    
    var showPersonality: Bool {
        get {
            if defaults.object(forKey: personalityKey) == nil {
                return true
            }
            return defaults.bool(forKey: personalityKey)
        }
        set { defaults.set(newValue, forKey: personalityKey) }
    }
    
    private init() {}
    
    // MARK: - Quote Categories
    
    static let firstLaunchWelcome = "Welcome to The Annex. Don't worry, it's not as bad as it sounds."
    
    static let syncCompleteQuotes = [
        "That's what she synced.",
        "I am ready to sync. I am ready to sync.",
        "Another day, another file transferred.",
        "I knew exactly what to do. But in a much more real sense, I had no idea what to do. Until now.",
        "Would I rather be feared or loved? Easy. Both. I want people to be afraid of how much they love their backups.",
        "Sometimes I'll start a sync and I don't even know where it's going. I just hope I find it along the way.",
        "I'm not superstitious, but I am a little stitious... about how well that went.",
        "Boom. Synced it.",
    ]
    
    static let nasOffline = "The Annex is... unavailable right now."
    
    static let emptyActivityLog = "Not a lot going on at the moment."
    
    static let perfectSuccessRate = "I have a lot of questions. Number one: how dare you be this reliable."
    
    static let bandwidthLimitHit = "Why are you the way that you are?"
    
    static let firstNASAdded = "You have no idea how high I can fly."
    
    static let syncFailed = "I'm not superstitious, but I am a little stitious about this error."
    
    static let aboutFooter = "The Annex — where your files go to not be forgotten."
    
    static let aboutInspiration = "Inspired by a little office down the hall."
    
    static let tagline = "Your files are in The Annex."
    
    // MARK: - Non-repeating sync complete quote
    
    func nextSyncCompleteQuote() -> String? {
        guard showPersonality else { return nil }
        
        if usedSyncCompleteIndices.count >= AnnexQuotes.syncCompleteQuotes.count {
            usedSyncCompleteIndices.removeAll()
        }
        
        let available = Set(0..<AnnexQuotes.syncCompleteQuotes.count).subtracting(usedSyncCompleteIndices)
        guard let index = available.randomElement() else { return nil }
        
        usedSyncCompleteIndices.insert(index)
        return AnnexQuotes.syncCompleteQuotes[index]
    }
    
    func quote(_ text: String) -> String? {
        guard showPersonality else { return nil }
        return text
    }
}
