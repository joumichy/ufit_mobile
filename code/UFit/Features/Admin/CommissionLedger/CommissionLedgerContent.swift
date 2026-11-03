import SwiftUI

struct UFitCommissionLedgerContent: View {
  let rows: [UFitCommissionEntry]
  @Binding var visibleRowID: String?
  let messageAtEnd: Bool
  @Binding var search: String
  @Binding var state: UFitCommissionRelease.State?
  @Binding var currency: String?
  let currencies: [String]
  let totalCount: Int?
  let asOf: UFitTimestamp?
  let isLoading: Bool
  let hasLoaded: Bool
  let hasMore: Bool
  let isFiltered: Bool
  let message: String?
  let onBack: () -> Void
  let onRefresh: () -> Void
  let onRetry: () -> Void
  let onReset: () -> Void
  let onOpen: (String) -> Void
  let onMore: () -> Void
  var body: some View {
    VStack(spacing: .zero) {
      DetailHeader(title: UFitCommissionLedgerCopy.title, onBack: onBack) {
        if !isLoading {
          UFitButton(action: onRefresh) {
            UFitIcon(systemName: UFitCommissionLedgerCopy.refreshIcon)
          }.accessibilityLabel(UFitCommissionLedgerCopy.refresh)
        }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
          UFitSearchField(query: $search, prompt: UFitCommissionLedgerCopy.search).onSubmit(
            onRefresh)
          ViewThatFits(in: .horizontal) {
            HStack(spacing: UFitSpace.sm) {
              stateFilter
              currencyFilter
            }
            VStack(spacing: UFitSpace.sm) {
              stateFilter
              currencyFilter
            }
          }
          if !messageAtEnd || rows.isEmpty { feedback }
          if let totalCount {
            Text(UFitCommissionLedgerCopy.count(totalCount)).font(UFitTypography.subheadline)
              .foregroundStyle(Color.ufitSecondaryText)
          }
          if let asOf {
            Text(UFitCommissionLedgerCopy.asOf(asOf)).font(UFitTypography.caption).foregroundStyle(
              Color.ufitSecondaryText)
          }
          if rows.isEmpty {
            if isLoading || (!hasLoaded && message == nil) {
              UFitLoading(UFitCommissionLedgerCopy.loading).frame(maxWidth: .infinity).padding(
                .vertical, UFitSpace.xl)
            } else if hasLoaded && message == nil {
              UFitEmptyState(
                title: isFiltered
                  ? UFitCommissionLedgerCopy.noMatches : UFitCommissionLedgerCopy.empty,
                symbol: UFitCommissionLedgerCopy.icon,
                actionTitle: isFiltered ? UFitCommissionLedgerCopy.reset : nil,
                action: isFiltered ? onReset : nil)
            }
          } else {
            LazyVStack(spacing: .zero) {
              ForEach(rows) { entry in
                VStack(spacing: .zero) {
                  UFitButton {
                    onOpen(entry.id)
                  } label: {
                    HStack(alignment: .top, spacing: UFitSpace.md) {
                      VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(entry.productName).font(UFitTypography.headline)
                        Text(entry.creatorName).font(UFitTypography.subheadline).foregroundStyle(
                          Color.ufitSecondaryText)
                        Text(entry.brandName).font(UFitTypography.caption).foregroundStyle(
                          Color.ufitSecondaryText)
                        Text(entry.orderNumber).font(UFitTypography.caption).foregroundStyle(
                          Color.ufitSecondaryText)
                        Text(entry.net).font(UFitTypography.headline).monospacedDigit()
                        Text(entry.releaseSummary).font(UFitTypography.caption)
                      }.fixedSize(horizontal: false, vertical: true)
                      Spacer(minLength: UFitSpace.sm)
                      UFitIcon(systemName: UFitCommissionLedgerCopy.next).font(
                        UFitTypography.caption
                      ).accessibilityHidden(true)
                    }.padding(.vertical, UFitSpace.md).frame(
                      maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                  }
                  Divider()
                }.id(entry.id)
              }
            }.scrollTargetLayout()
            if messageAtEnd { feedback }
            if isLoading { UFitLoading().frame(maxWidth: .infinity) }
            if hasMore && message == nil {
              UFitButton(UFitCommissionLedgerCopy.more, action: onMore).ufitButtonStyle(.secondary)
                .disabled(isLoading)
            }
          }
        }.padding(.vertical, UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
      }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $visibleRowID, anchor: .top)
        .scrollDismissesKeyboard(.interactively)
    }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
  }
  @ViewBuilder private var feedback: some View {
    if let message {
      VStack(alignment: .leading, spacing: UFitSpace.md) {
        UFitNotice(message: message, kind: .error)
        UFitButton(UFitCommissionLedgerCopy.retry, action: onRetry).ufitButtonStyle(.secondary)
          .disabled(isLoading)
      }
    }
  }
  private var stateFilter: some View {
    UFitSelection(
      UFitCommissionLedgerCopy.state, selection: $state,
      options: [
        .init(
          value: Optional<UFitCommissionRelease.State>.none,
          title: UFitCommissionLedgerCopy.allStates)
      ]
        + UFitCommissionRelease.State.allCases.map {
          .init(value: Optional($0), title: UFitCommissionRelease.filterTitle($0))
        })
  }
  private var currencyFilter: some View {
    UFitSelection(
      UFitCommissionLedgerCopy.currency, selection: $currency,
      options: [.init(value: Optional<String>.none, title: UFitCommissionLedgerCopy.allCurrencies)]
        + currencies.map { .init(value: Optional($0), title: $0) })
  }
}

struct UFitCommissionLedgerDetailContent: View {
  let document: UFitCommissionLedgerDetail?
  let entry: UFitCommissionEntry?
  let rulePresentation: UFitCommissionRuleSnapshot?
  let isLoading: Bool
  let unavailable: Bool
  let message: String?
  let onBack: () -> Void
  let onRefresh: () -> Void
  let onRetry: () -> Void
  let onOrder: () -> Void
  let onReturns: () -> Void
  private enum Copy {
    static let creator = String(localized: "Créateur")
    static let created = String(localized: "Créée le")
    static let baseRate = String(localized: "Taux de base")
    static let bonusRate = String(localized: "Bonus")
    static let maximumRate = String(localized: "Plafond")
    static let brand = String(localized: "Marque")
    static let sale = String(localized: "Référence de vente")
    static let quantity = String(localized: "Quantité")
    static let calculation = String(localized: "Calcul à l’achat")
    static let base = String(localized: "Base de calcul")
    static let rate = String(localized: "Taux appliqué")
    static let original = String(localized: "Montant d’origine")
    static let adjustments = String(localized: "Ajustements")
    static let recovery = String(localized: "À récupérer sur le montant payé")
    static let due = String(localized: "Fin du délai de retour")
    static let rule = String(localized: "Règle enregistrée à l’achat")
    static let revision = String(localized: "Révision")
    static let grade = String(localized: "Grade enregistré")
    static let noRule = String(
      localized: "Aucune règle détaillée n’est enregistrée pour cette vente historique.")
    static let back = String(localized: "Revenir aux commissions")
  }
  var body: some View {
    VStack(spacing: .zero) {
      DetailHeader(title: UFitCommissionLedgerCopy.detail, onBack: onBack) {
        if !isLoading {
          UFitButton(action: onRefresh) {
            UFitIcon(systemName: UFitCommissionLedgerCopy.refreshIcon)
          }.accessibilityLabel(UFitCommissionLedgerCopy.refresh)
        }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
          if let message {
            UFitNotice(message: message, kind: .error)
            UFitButton(UFitCommissionLedgerCopy.retry, action: onRetry).ufitButtonStyle(.secondary)
          }
          if let document, let entry {
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
              Text(entry.productName).font(UFitTypography.title2.weight(.medium))
              Text(entry.net).font(UFitTypography.title.weight(.medium)).monospacedDigit()
              Text(entry.releaseSummary).font(UFitTypography.subheadline)
            }
            UFitLabeledValue(Copy.creator, value: entry.creatorName)
            UFitLabeledValue(Copy.brand, value: entry.brandName)
            UFitLabeledValue(Copy.sale, value: entry.orderNumber)
            UFitLabeledValue(Copy.quantity, value: entry.quantity.formatted())
            UFitLabeledValue(Copy.created, value: entry.date)
            UFitDisclosure(Copy.calculation) {
              VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitLabeledValue(Copy.base, value: entry.base)
                UFitLabeledValue(Copy.rate, value: entry.rate)
                UFitLabeledValue(Copy.original, value: entry.original)
                UFitLabeledValue(Copy.adjustments, value: entry.adjusted)
                if entry.hasPaidAdjustment {
                  UFitLabeledValue(Copy.recovery, value: entry.paidAdjustment)
                }
                if let date = entry.releaseDate { UFitLabeledValue(Copy.due, value: date) }
              }.padding(.top, UFitSpace.md)
            }
            UFitDisclosure(Copy.rule) {
              VStack(alignment: .leading, spacing: UFitSpace.md) {
                if let rule = document.rule, let values = rulePresentation {
                  UFitLabeledValue(Copy.revision, value: rule.revision.formatted())
                  UFitLabeledValue(Copy.grade, value: rule.creatorGradeCode)
                  UFitLabeledValue(Copy.baseRate, value: values.base)
                  UFitLabeledValue(Copy.bonusRate, value: values.bonus)
                  UFitLabeledValue(Copy.maximumRate, value: values.maximum)
                } else {
                  Text(Copy.noRule).font(UFitTypography.callout).foregroundStyle(
                    Color.ufitSecondaryText)
                }
              }.padding(.top, UFitSpace.md)
            }
            Divider()
            UFitButton(UFitCommissionLedgerCopy.order, action: onOrder).ufitButtonStyle(.secondary)
            if document.relatedReturnCount > .zero {
              UFitButton(
                String(localized: "Retours liés (\(document.relatedReturnCount))"),
                action: onReturns
              ).ufitButtonStyle(.secondary)
            }
            Text(UFitCommissionLedgerCopy.asOf(document.asOf)).font(UFitTypography.caption)
              .foregroundStyle(Color.ufitSecondaryText)
          } else if isLoading || (message == nil && !unavailable) {
            UFitLoading(UFitCommissionLedgerCopy.detailLoading).frame(maxWidth: .infinity)
          } else if unavailable {
            UFitEmptyState(
              title: UFitCommissionLedgerCopy.missing, symbol: UFitCommissionLedgerCopy.icon,
              actionTitle: Copy.back, action: onBack)
          }
        }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
      }
    }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
  }
}

struct UFitCommissionRelatedReturnsContent: View {
  let rows: [UFitCommissionRelatedReturn]
  @Binding var visibleRowID: String?
  let messageAtEnd: Bool
  let hasLoaded: Bool
  let isLoading: Bool
  let hasMore: Bool
  let asOf: UFitTimestamp?
  let message: String?
  let onBack: () -> Void
  let onRefresh: () -> Void
  let onRetry: () -> Void
  let onMore: () -> Void
  let onOpen: (UFitCommissionRelatedReturn) -> Void
  var body: some View {
    VStack(spacing: .zero) {
      DetailHeader(title: UFitCommissionLedgerCopy.returns, onBack: onBack) {
        if !isLoading {
          UFitButton(action: onRefresh) {
            UFitIcon(systemName: UFitCommissionLedgerCopy.refreshIcon)
          }.accessibilityLabel(UFitCommissionLedgerCopy.refreshReturns)
        }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
          if !messageAtEnd || rows.isEmpty { feedback }
          if let asOf {
            Text(UFitCommissionLedgerCopy.asOf(asOf)).font(UFitTypography.caption).foregroundStyle(
              Color.ufitSecondaryText)
          }
          LazyVStack(spacing: .zero) {
            ForEach(rows) { row in
              VStack(spacing: .zero) {
                UFitButton {
                  onOpen(row)
                } label: {
                  HStack(alignment: .top, spacing: UFitSpace.md) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                      Text(row.status.label).font(UFitTypography.headline)
                      Text(row.requestedAt.label).font(UFitTypography.subheadline).foregroundStyle(
                        Color.ufitSecondaryText)
                      Text(String(localized: "Quantité : \(row.quantity)")).font(
                        UFitTypography.caption)
                      Text(
                        String(
                          localized:
                            "Ajustement : \(UFitMoney.format(row.adjustedAmount, currency: row.currency))"
                        )
                      ).font(UFitTypography.caption)
                    }
                    Spacer(minLength: UFitSpace.sm)
                    UFitIcon(systemName: UFitCommissionLedgerCopy.next).font(UFitTypography.caption)
                      .accessibilityHidden(true)
                  }.padding(.vertical, UFitSpace.md).frame(
                    maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                }
                Divider()
              }.id(row.id)
            }
          }.scrollTargetLayout()
          if messageAtEnd && !rows.isEmpty { feedback }
          if isLoading || (!hasLoaded && message == nil) {
            UFitLoading(UFitCommissionLedgerCopy.returnsLoading).frame(maxWidth: .infinity)
          } else if rows.isEmpty && hasLoaded && message == nil {
            UFitEmptyState(
              title: UFitCommissionLedgerCopy.returnsEmpty, symbol: UFitCommissionLedgerCopy.icon)
          }
          if hasMore && message == nil {
            UFitButton(UFitCommissionLedgerCopy.moreReturns, action: onMore).ufitButtonStyle(
              .secondary
            ).disabled(isLoading)
          }
        }.padding(.vertical, UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
      }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $visibleRowID, anchor: .top)
    }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
  }
  @ViewBuilder private var feedback: some View {
    if let message {
      VStack(alignment: .leading, spacing: UFitSpace.md) {
        UFitNotice(message: message, kind: .error)
        UFitButton(UFitCommissionLedgerCopy.retry, action: onRetry).ufitButtonStyle(.secondary)
          .disabled(isLoading)
      }
    }
  }

}
