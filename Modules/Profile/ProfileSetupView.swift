//
//  ProfileSetupView.swift
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfileSetupView: View {
    @Environment(\.container) private var container

    let user: User
    var onComplete: () -> Void

    @State private var name: String = ""
    @State private var gender: Gender = .unspecified
    @State private var contact: String = ""
    @State private var avatarImage: Image?
    @State private var avatarData: Data?
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section(header: Text("Profile")) {
                HStack(spacing: 16) {
                    ZStack {
                        if let avatarImage { avatarImage.resizable().scaledToFill() }
                        else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary) }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        TextField("Full Name", text: $name)
                        Picker("Gender", selection: $gender) {
                            ForEach(Gender.allCases, id: \.self) { g in
                                Text(g.rawValue.capitalized).tag(g)
                            }
                        }
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose Profile Picture", systemImage: "photo.on.rectangle")
                }
            }

            Section(header: Text("Contact")) {
                TextField("Contact Info (email, phone, etc.)", text: $contact)
                    .textInputAutocapitalization(.never)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(.red) }
            }

            Section {
                Button(action: save) {
                    if isSaving { ProgressView() } else { Text("Save Profile") }
                }
                .disabled(!isFormValid || isSaving)
            }
        }
        .navigationTitle("Set up your profile")
        .onChange(of: photoItem) { newValue in
            guard let newValue else { return }
            Task { await loadImage(from: newValue) }
        }
        .task { await loadExistingProfileIfAny() }
    }
}

private extension ProfileSetupView {
    var isFormValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                self.avatarData = data
                if let uiImage = UIImage(data: data) {
                    self.avatarImage = Image(uiImage: uiImage)
                }
            }
        } catch {
            self.errorMessage = "Failed to load image"
        }
    }

    func loadExistingProfileIfAny() async {
        do {
            if let profile = try await container.profileRepository.fetchProfile(for: user.id) {
                self.name = profile.name
                self.gender = profile.gender
                self.contact = profile.contact
            }
        } catch {
            // Non-fatal; keep form empty
        }
    }

    func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                var avatarURL: URL? = nil
                if let data = avatarData {
                    avatarURL = try await container.profileRepository.uploadAvatar(data: data, for: user.id, contentType: "image/jpeg")
                }
                let profile = Profile(id: user.id, name: name, gender: gender, contact: contact, avatarURL: avatarURL, updatedAt: Date())
                try await container.profileRepository.upsertProfile(profile)
                isSaving = false
                onComplete()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
