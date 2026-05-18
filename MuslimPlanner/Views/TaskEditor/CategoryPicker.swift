import SwiftUI
import SwiftData

struct CategoryPicker: View {
    @Binding var selected: Category?
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var ctx

    @State private var showingNew = false
    @State private var newName    = ""
    @State private var newColor   = "007AFF"
    @State private var newSymbol  = "tag.fill"

    private let presetColors = [
        ("Blue",   "007AFF"), ("Green",  "34C759"), ("Orange", "FF9500"),
        ("Red",    "FF3B30"), ("Purple", "AF52DE"), ("Pink",   "FF2D55"),
        ("Teal",   "5AC8FA"), ("Yellow", "FFCC00"),
    ]

    private let presetSymbols = [
        "tag.fill", "book.fill", "briefcase.fill", "heart.fill",
        "star.fill", "flame.fill", "bolt.fill", "house.fill",
        "figure.walk", "dumbbell.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // None chip
                    chip(label: "None", color: "8E8E93", symbol: "xmark", isSelected: selected == nil) {
                        selected = nil
                    }

                    ForEach(categories) { cat in
                        chip(label: cat.name, color: cat.colorHex, symbol: cat.symbolName,
                             isSelected: selected?.persistentModelID == cat.persistentModelID) {
                            selected = cat
                        }
                    }

                    // Add new
                    Button {
                        newName = ""
                        newColor = "007AFF"
                        newSymbol = "tag.fill"
                        showingNew = true
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showingNew) {
            newCategorySheet
                .presentationDetents([.medium])
        }
    }

    private func chip(label: String, color: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption2)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: color) : Color(hex: color).opacity(0.15))
            .foregroundStyle(isSelected ? .white : Color(hex: color))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var newCategorySheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Coursework", text: $newName)
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 12) {
                        ForEach(presetColors, id: \.0) { _, hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(newColor == hex ? Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) : nil)
                                .onTapGesture { newColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                        ForEach(presetSymbols, id: \.self) { sym in
                            Image(systemName: sym)
                                .font(.title3)
                                .foregroundStyle(newSymbol == sym ? Color(hex: newColor) : .secondary)
                                .frame(width: 44, height: 44)
                                .background(newSymbol == sym ? Color(hex: newColor).opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { newSymbol = sym }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingNew = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let cat = Category(name: newName.trimmingCharacters(in: .whitespaces),
                                           colorHex: newColor, symbolName: newSymbol)
                        ctx.insert(cat)
                        selected = cat
                        showingNew = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
