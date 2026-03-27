//
//  PaywallView.swift
//
//  Generic paywall — edit `benefits` to match your app's value proposition.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.container) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var options: [PurchaseOption] = []
    @State private var selectedId: String? = nil
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showAllPlans: Bool = false

    // ─────────────────────────────────────────────────────────
    // EDIT THESE to match your app's subscription benefits.
    // ─────────────────────────────────────────────────────────
    static let benefits: [String] = [
        String(localized: "paywall.benefit.1"),
        String(localized: "paywall.benefit.2"),
        String(localized: "paywall.benefit.3"),
        String(localized: "paywall.benefit.4"),
        String(localized: "paywall.benefit.5"),
    ]

    var body: some View {
        ZStack {
            AnimatedBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding([.top, .horizontal], DS.Spacing.lg)

                Spacer(minLength: 0)

                LogoView(size: 84)
                    .padding(.bottom, DS.Spacing.lg)

                Text(String(localized: "paywall.title"))
                    .font(AppTypography.title)
                    .foregroundStyle(titleColor)
                    .padding(.bottom, DS.Spacing.md)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(Self.benefits, id: \.self) { text in
                        FeatureRow(text: text)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)

                VStack(spacing: DS.Spacing.md) {
                    ForEach(options) { opt in
                        PlanOptionRow(
                            title: opt.displayName,
                            price: opt.price,
                            perUnit: opt.pricePerPeriod,
                            isSelected: selectedId == opt.id,
                            badge: opt.badge
                        ) { selectedId = opt.id }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
                .animation(.easeInOut(duration: DS.Motion.normal), value: options)

                Button(action: toggleAllPlans) {
                    HStack {
                        Spacer()
                        Text(showAllPlans
                             ? String(localized: "paywall.fewerplans")
                             : String(localized: "paywall.allplans"))
                            .font(AppTypography.custom(size: 15, weight: .semibold, relativeTo: .subheadline))
                            .foregroundColor(DS.accent)
                        Spacer()
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)

                Button(action: purchase) {
                    HStack {
                        Spacer()
                        Text(ctaTitle)
                            .appFont(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .foregroundColor(DS.Colors.buttonPrimaryFg)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
                .disabled(isPurchasing || selectedId == nil)
                .opacity((isPurchasing || selectedId == nil) ? 0.6 : 1.0)

                HStack(spacing: DS.Spacing.md) {
                    Button(action: restore) {
                        Text(String(localized: "paywall.restore"))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    Spacer()
                    Link("Terms", destination: container.config.legal.termsURL)
                        .foregroundColor(DS.Colors.textSecondary)
                    Link("Privacy", destination: container.config.legal.privacyPolicyURL)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .task { await load() }
        .alert("Purchase Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var ctaTitle: String {
        if let selected = options.first(where: { $0.id == selectedId }), let text = selected.ctaText, !text.isEmpty {
            return text
        }
        return String(localized: "paywall.continue")
    }

    @Environment(\.colorScheme) private var colorScheme
    private var titleColor: Color { colorScheme == .dark ? .white : DS.Colors.textPrimary }

    private func load() async {
        let opts = await container.purchasesService.loadOfferings(includeAll: showAllPlans)
        await MainActor.run {
            self.options = opts
            self.selectedId = opts.first?.id
        }
    }

    private func toggleAllPlans() {
        withAnimation(.easeInOut(duration: DS.Motion.normal)) {
            showAllPlans.toggle()
        }
        Task { await load() }
    }

    private func purchase() {
        guard let id = selectedId else { return }
        isPurchasing = true
        Task { @MainActor in
            do {
                try await container.purchasesService.purchase(packageIdentifier: id)
                isPurchasing = false
                dismiss()
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        Task {
            do { try await container.purchasesService.restorePurchases() }
            catch let e as PurchaseFriendlyError { await MainActor.run { errorMessage = e.localizedDescription } }
            catch { await MainActor.run { errorMessage = error.localizedDescription } }
        }
    }
}

private struct FeatureRow: View {
    var text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.accent)
            Text(text)
                .foregroundColor(featureTextColor)
        }
    }
    @Environment(\.colorScheme) private var colorScheme
    private var featureTextColor: Color { colorScheme == .dark ? .white : DS.Colors.textPrimary }
}

private struct PlanOptionRow: View {
    var title: String
    var price: String
    var perUnit: String?
    var isSelected: Bool
    var badge: String?
    var tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(isSelected ? DS.accent : Color.white.opacity(0.15), lineWidth: 2)
                    )
                HStack(alignment: .center) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? DS.accent : DS.Colors.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).appFont(.headline)
                        Text(price).appFont(.title3)
                    }
                    Spacer()
                    if let perUnit { Text(perUnit).foregroundColor(DS.Colors.textSecondary) }
                }
                .padding()

                if let badge {
                    Text(badge)
                        .appFont(.captionBold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(DS.accent, in: Capsule())
                        .foregroundColor(DS.Colors.buttonPrimaryFg)
                        .offset(x: -12, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
            .preferredColorScheme(.dark)
    }
}
