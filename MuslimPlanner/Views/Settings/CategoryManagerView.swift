import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var ctx

    @State private var editingCat: Category?
    @State private var showingNew  = false

    var body: some View {
        List {
            ForEach(categories) { cat in
                Button {
                    editingCat = cat
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: cat.symbolName)
                            .foregroundStyle(Color(hex: cat.colorHex))
                            .frame(width: 28)
                        Text(cat.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { categories[$0] }.forEach { ctx.delete($0) }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNew = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(item: $editingCat) { cat in
            CategoryEditSheet(category: cat)
        }
        .sheet(isPresented: $showingNew) {
            CategoryEditSheet(category: nil)
        }
    }
}

// MARK: - Edit / Create Sheet

struct CategoryEditSheet: View {
    var category: Category?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var name   = ""
    @State private var color  = "007AFF"
    @State private var symbol = "tag.fill"

    private let presetColors: [(String, String)] = [
        ("Blue",   "007AFF"), ("Green",  "34C759"), ("Orange", "FF9500"),
        ("Red",    "FF3B30"), ("Purple", "AF52DE"), ("Pink",   "FF2D55"),
        ("Teal",   "5AC8FA"), ("Yellow", "FFCC00"),
    ]
    private let presetSymbols = [
        "tag.fill", "book.fill", "briefcase.fill", "heart.fill",
        "star.fill", "flame.fill", "bolt.fill", "house.fill",
        "figure.walk", "dumbbell.fill", "pencil", "tray.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 14) {
                        ForEach(presetColors, id: \.0) { _, hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay(color == hex ? Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) : nil)
                                .onTapGesture { color = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 10) {
                        ForEach(presetSymbols, id: \.self) { sym in
                            Image(systemName: sym)
                                .font(.title3)
                                .foregroundStyle(symbol == sym ? Color(hex: color) : .secondary)
                                .frame(width: 44, height: 44)
                                .background(symbol == sym ? Color(hex: color).opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { symbol = sym }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let cat = category {
                    name   = cat.name
                    color  = cat.colorHex
                    symbol = cat.symbolName
                }
            }
        }
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        if let cat = category {
            cat.name       = clean
            cat.colorHex   = color
            cat.symbolName = symbol
        } else {
            ctx.insert(Category(name: clean, colorHex: color, symbolName: symbol))
        }
        dismiss()
    }
}
