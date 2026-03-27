//
//  LocalDataDemoView.swift
//

import SwiftUI

struct LocalDataDemoView: View {
    @StateObject private var repo = LocalCoreDataRepository()
    @State private var name: String = ""
    @State private var contact: String = ""

    var body: some View {
        Form {
            Section("Add Entry") {
                TextField("Name", text: $name)
                TextField("Contact", text: $contact)
                Button {
                    repo.add(name: name, contact: contact)
                    name = ""; contact = ""
                } label: { Label("Add", systemImage: "plus.circle.fill") }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Saved (Local)") {
                if repo.items.isEmpty {
                    Text("No items yet").foregroundColor(.secondary)
                } else {
                    ForEach(repo.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).appFont(.headline)
                            if !item.contact.isEmpty { Text(item.contact).foregroundColor(.secondary) }
                        }
                    }
                    .onDelete(perform: repo.delete)
                }
            }
        }
        .navigationTitle("Local DB Demo")
    }
}

// Repository implemented with Core Data is defined in LocalCoreDataRepository.swift
