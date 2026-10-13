import SwiftUI

struct PaywallView: View {
    @Environment(\.container) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var options: [PurchaseOption] = []
    @State private var selectedId: String?
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var selected: PurchaseOption? { options.first { $0.id == selectedId } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    LogoView(size: 76, animateLogo: false)
                        .padding(.top, 20)
                    VStack(spacing: 8) {
                        Text("\(container.config.appName) Pro").font(.largeTitle.bold())
                        Text("Full-resolution exports. Your colors.").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(["paywall.benefit.1", "paywall.benefit.2"], id: \.self) { key in
                            Label(String(localized: String.LocalizationValue(key)), systemImage: "checkmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                    if isLoading {
                        ProgressView("Loading plans…").padding()
                    } else if options.isEmpty {
                        VStack(spacing: 12) {
                            Text("Plans are temporarily unavailable").font(.headline)
                            Text("You can keep using the free features and try again later.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") { Task { await load() } }
                        }.padding(.vertical)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(options) { option in
                                Button { selectedId = option.id } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedId == option.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedId == option.id ? DS.accent : .secondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(option.displayName).font(.headline)
                                            if let cadence = option.pricePerPeriod { Text(cadence).font(.subheadline).foregroundStyle(.secondary) }
                                        }
                                        Spacer()
                                        Text(option.price).font(.title3.bold())
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(18)
                                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedId == option.id ? DS.accent : .white.opacity(0.15), lineWidth: selectedId == option.id ? 2 : 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedId == option.id ? .isSelected : [])
                            }
                        }

                        Button(action: purchase) {
                            HStack {
                                if isBusy { ProgressView().tint(.black) }
                                Text(selected.map { "Subscribe for \($0.price)" } ?? "Select a plan").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(.black)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isBusy || selected == nil)

                        Text("Payment is charged to your Apple Account. Subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Manage or cancel in App Store settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases", action: restore).disabled(isBusy)
                    HStack(spacing: 24) {
                        Link("Terms", destination: container.config.legal.termsURL)
                        Link("Privacy", destination: container.config.legal.privacyPolicyURL)
                    }.font(.footnote)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Close Pro plans")
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .tint(DS.accent)
        .presentationDetents([.large])
        .task { await load() }
        .alert("Purchases", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { notification in
            if notification.userInfo?["hasActiveEntitlement"] as? Bool == true { dismiss() }
        }
    }

    private func load() async {
        isLoading = true
        options = await container.purchasesService.loadOfferings(includeAll: false)
        selectedId = options.first?.id
        isLoading = false
    }

    private func purchase() {
        guard let selectedId, !isBusy else { return }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                try await container.purchasesService.purchase(packageIdentifier: selectedId)
                dismiss()
            } catch PurchaseFriendlyError.cancelled {
                // The system purchase sheet already acknowledges cancellation.
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func restore() {
        guard !isBusy else { return }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                try await container.purchasesService.restorePurchases()
                dismiss()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
