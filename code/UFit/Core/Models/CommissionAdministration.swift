import Foundation

enum UFitCommissionReferenceKind: CaseIterable, Identifiable {
    case brand, product, grade
    var id: Self { self }
    var title: String {
        switch self { case .brand: UFitCommissionAdminCopy.brand; case .product: UFitCommissionAdminCopy.product; case .grade: UFitCommissionAdminCopy.grade }
    }
    var unselectedTitle: String {
        switch self { case .brand: UFitCommissionAdminCopy.chooseBrand; case .product: UFitCommissionAdminCopy.allProducts; case .grade: UFitCommissionAdminCopy.allGrades }
    }
}
struct UFitCommissionReference: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
}
struct UFitCommissionRuleDraft: Equatable {
    var brand: UFitCommissionReference?
    var product: UFitCommissionReference?
    var grade: UFitCommissionReference?
    var baseRate = String()
    var bonusRate = String()
    var maximumRate = String()
    var active = true
    var reason = String()
}
enum UFitCommissionRuleField: Hashable { case brand, baseRate, bonusRate, maximumRate, reason }
struct UFitCommissionRuleRow: Identifiable {
    let id: String
    let brand: String
    let product: String?
    let grade: String?
    let rate: String
    let revision: Int
    let active: Bool
}
struct UFitCommissionRevisionRow: Identifiable {
    let id: String
    let revision: Int
    let rate: String
    let date: String
    let reason: String?
    let active: Bool
    let isCurrent: Bool
}
struct UFitCommissionRuleDocument {
    let rule: UFitCommissionRuleRow
    let baseRate: String
    let bonusRate: String
    let maximumRate: String?
}
enum UFitCommissionAdminCopy {
    static let title = String(localized: "Commissions")
    static let rules = String(localized: "Règles de commission")
    static let create = String(localized: "Nouvelle règle")
    static let edit = String(localized: "Modifier la règle")
    static let save = String(localized: "Créer la règle")
    static let revise = String(localized: "Enregistrer la révision")
    static let refresh = String(localized: "Actualiser les règles")
    static let reloadReference = String(localized: "Actualiser la référence")
    static let retry = String(localized: "Réessayer")
    static let more = String(localized: "Afficher la suite")
    static let loading = String(localized: "Chargement des règles")
    static let brand = String(localized: "Marque")
    static let product = String(localized: "Article")
    static let grade = String(localized: "Grade créateur")
    static let chooseBrand = String(localized: "Choisir une marque")
    static let allBrands = String(localized: "Toutes les marques")
    static let allProducts = String(localized: "Tous les articles")
    static let allGrades = String(localized: "Tous les grades")
    static let scope = String(localized: "Application")
    static let rates = String(localized: "Taux")
    static let rateFormula = String(localized: "Base + bonus, dans la limite du plafond choisi et de 100 %.")
    static let baseRate = String(localized: "Taux de base (%)")
    static let bonusRate = String(localized: "Bonus (%)")
    static let maximumRate = String(localized: "Plafond facultatif (%)")
    static let finalRate = String(localized: "Taux appliqué")
    static let reason = String(localized: "Motif")
    static let active = String(localized: "Active")
    static let inactive = String(localized: "Désactivée")
    static let activation = String(localized: "Règle active")
    static let current = String(localized: "Révision actuelle")
    static let history = String(localized: "Historique")
    static let version = String(localized: "Révision")
    static let empty = String(localized: "Aucune règle pour cette sélection.")
    static let missingRule = String(localized: "Une commission doit être configurée avant la vente d’un article attribué.")
    static let search = String(localized: "Rechercher")
    static let optionEmpty = String(localized: "Aucun résultat pour cette recherche.")
    static let searching = String(localized: "Chargement des choix")
    static let close = String(localized: "Fermer")
    static let discardTitle = String(localized: "Abandonner les modifications ?")
    static let discard = String(localized: "Abandonner")
    static let keepEditing = String(localized: "Continuer la modification")
    static let futurePurchases = String(localized: "Cette révision s’applique aux nouveaux achats. Les achats passés gardent leur règle.")
    static let priority = String(localized: "Priorité : article et grade, article, grade, puis marque.")
    static let noMaximum = String(localized: "Sans plafond spécifique")
}
