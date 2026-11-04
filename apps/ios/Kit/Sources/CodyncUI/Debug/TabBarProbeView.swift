import SwiftUI
import UIKit

/// A minimal TabView with the home's own modifiers, for working out why the search tab does not sit on
/// its own button. Debug only: reached from the Settings rows behind the version ten-tap.
///
/// Four variants, so one variable changes at a time:
/// - `minimal`: three tabs and nothing else.
/// - `minimize`: plus `.tabBarMinimizeBehavior(.onScrollDown)`.
/// - `accessory`: plus `.tabViewBottomAccessory`.
/// - `home`: everything the home's TabView carries, including a NavigationStack per tab.
public struct TabBarProbeView: View {
    enum Variant: String, CaseIterable, Identifiable {
        case minimal
        case minimize
        case accessory
        case home

        var id: String { rawValue }

        var title: String {
            switch self {
            case .minimal: return "最小版"
            case .minimize: return "V1 缩放"
            case .accessory: return "V2 附属栏"
            case .home: return "V3 全部"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var variant = Variant.minimal
    @State private var selection = 0
    @State private var path: [Int] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    /// What the probe is running on, and the variant switch.
    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text("TabBar 对照")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            Text("iOS \(UIDevice.current.systemVersion) · 构建 \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") · SDK 27.1")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("变体", selection: $variant) {
                ForEach(Variant.allCases) { variant in
                    Text(variant.title).tag(variant)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
    }

    @ViewBuilder private var content: some View {
        switch variant {
        case .minimal:
            bare
        case .minimize:
            bare.tabBarMinimizeBehavior(.onScrollDown)
        case .accessory:
            bare.tabViewBottomAccessory { Text("accessory") }
        case .home:
            homeLike
        }
    }

    /// Three tabs, no modifiers at all.
    private var bare: some View {
        TabView {
            Tab("A", systemImage: "pin") {
                List(0..<50, id: \.self) { Text("\($0)") }
            }
            Tab("B", systemImage: "cpu") {
                Text("B")
            }
            Tab(role: .search) {
                Text("search")
            }
        }
    }

    /// The home's TabView as it is built today: selection, a stack per tab, the accessory, the
    /// minimize behaviour, the tint.
    private var homeLike: some View {
        TabView(selection: $selection) {
            Tab("A", systemImage: "pin", value: 0) {
                stack { List(0..<50, id: \.self) { Text("\($0)") } }
            }
            Tab("B", systemImage: "cpu", value: 1) {
                stack { Text("B") }
            }
            Tab(value: 2, role: .search) {
                stack { Text("search") }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory { Text("accessory") }
        .tint(.primary)
    }

    private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack(path: $path) {
            content()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Image(systemName: "person.crop.circle") }
                    ToolbarItem(placement: .topBarTrailing) { Image(systemName: "plus") }
                }
        }
    }
}
