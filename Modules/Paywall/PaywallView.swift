//
//  PaywallView.swift
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
                .padding([.top, .horizontal], DesignTokens.Spacing.lg)

                Spacer(minLength: 0)

                LogoView(size: 84)
                    .padding(.bottom, DesignTokens.Spacing.lg)

                Text("Pick your plan")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(titleColor)
                    .padding(.bottom, DesignTokens.Spacing.md)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    FeatureRow(text: "500 credits per month")
                    FeatureRow(text: "Latest AI models access")
                    FeatureRow(text: "Script-to-Video with Voiceover")
                    FeatureRow(text: "Full HD exports")
                    FeatureRow(text: "100+ voice styles")
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl)

                VStack(spacing: DesignTokens.Spacing.md) {
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
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.lg)
                .animation(.easeInOut(duration: 0.25), value: options)

                Button(action: toggleAllPlans) {
                    HStack {
                        Spacer()
                        Text(showAllPlans ? "Show fewer plans" : "Show all plans")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignTokens.accentColor)
                        Spacer()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.md)

                Button(action: purchase) {
                    HStack {
                        Spacer()
                        Text(ctaTitle)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(DesignTokens.accentColor, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    .foregroundColor(.black)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.md)
                .disabled(isPurchasing || selectedId == nil)
                .opacity((isPurchasing || selectedId == nil) ? 0.6 : 1.0)

                HStack(spacing: DesignTokens.Spacing.md) {
                    Button(action: restore) {
                        Text("Restore Purchases")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Link("Terms", destination: container.config.legal.termsURL)
                        .foregroundColor(.secondary)
                    Link("Privacy", destination: container.config.legal.privacyPolicyURL)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.lg)
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
        return "Continue"
    }

    @Environment(\.colorScheme) private var colorScheme
    private var titleColor: Color { colorScheme == .dark ? .white : .primary }

    private func load() async {
        let opts = await container.purchasesService.loadOfferings(includeAll: showAllPlans)
        await MainActor.run {
            self.options = opts
            self.selectedId = opts.first?.id
        }
    }

    private func toggleAllPlans() {
        withAnimation(.easeInOut(duration: 0.25)) {
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
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.accentColor)
            Text(text)
                .foregroundColor(featureTextColor)
        }
    }
    @Environment(\.colorScheme) private var colorScheme
    private var featureTextColor: Color { colorScheme == .dark ? .white : .primary }
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
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                            .stroke(isSelected ? DesignTokens.accentColor : Color.white.opacity(0.15), lineWidth: 2)
                    )
                HStack(alignment: .center) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? DesignTokens.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(price).font(.title3.bold())
                    }
                    Spacer()
                    if let perUnit { Text(perUnit).foregroundColor(.secondary) }
                }
                .padding()

                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(DesignTokens.accentColor, in: Capsule())
                        .foregroundColor(.black)
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
