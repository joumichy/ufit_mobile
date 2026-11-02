import Foundation

enum OnboardingSlide: Int, CaseIterable, Identifiable {
    case discovery, creators, pieces, saved
    var id: Self { self }
    var imageName: String {
        switch self {
        case .discovery: "unsplash-09"
        case .creators: "unsplash-08"
        case .pieces: "unsplash-04"
        case .saved: "unsplash-05"
        }
    }
    var title: String {
        switch self {
        case .discovery: String(localized: "Votre prochaine inspiration.")
        case .creators: String(localized: "Des regards singuliers.")
        case .pieces: String(localized: "Retrouvez chaque pièce.")
        case .saved: String(localized: "Gardez ce qui vous inspire.")
        }
    }
    var description: String {
        switch self {
        case .discovery: String(localized: "Découvrez des tenues composées par des créateurs et des marques sélectionnés.")
        case .creators: String(localized: "Explorez les univers des créateurs et retrouvez leurs pièces préférées.")
        case .pieces: String(localized: "Dans une tenue, ouvrez le sac puis choisissez une icône pour voir l’article et sa marque.")
        case .saved: String(localized: "Enregistrez vos tenues et retrouvez-les à votre rythme.")
        }
    }
}

enum UFitOnboarding {
    // A product introduction belongs to the installation, independently of the signed-in account.
    static let completionPreference = "ufit.onboarding.completed"
    static let skipArgument = "--skip-onboarding"
    static let showArgument = "--show-onboarding"
    static var shouldPresent: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains(showArgument) { return true }
        #endif
        return !UserDefaults.standard.bool(forKey: completionPreference) && !arguments.contains(skipArgument)
    }
    static let initialIndex = OnboardingSlide.discovery.rawValue
    static let positionStep = 1
    static let slides = OnboardingSlide.allCases
}
