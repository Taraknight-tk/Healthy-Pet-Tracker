import SwiftUI

// MARK: - Themed Navigation
struct ThemedNavigation<Content: View>: View {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    @ViewBuilder var content: () -> Content

    init(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode = .inline, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.displayMode = displayMode
        self.content = content
    }

    var body: some View {
        content()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
            .tint(.primary)
            .background(Color.bgPrimary)
    }
}

// MARK: - Themed Form
struct ThemedForm<Content: View>: View {
    @ViewBuilder var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Form {
            content()
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
    }
}

// MARK: - Section Styling Modifier
struct ThemedSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.bgTertiary)
            .listRowSeparatorTint(Color.borderSubtle)
    }
}

extension View {
    func themedSection() -> some View { self.modifier(ThemedSectionModifier()) }

    // Apply primary text foreground style
    func primaryText() -> some View { self.foregroundStyle(Color.textPrimary) }

    // Apply secondary text foreground style
    func secondaryText() -> some View { self.foregroundStyle(Color.textSecondary) }
    
    // Apply tertiary text foreground style
    func tertiaryText() -> some View { self.foregroundStyle(Color.textTertiary) }
}

