import CodyncKit
import CodyncUI
import SwiftUI

/// Settings → 来源外观: the face each conversation source shows. One shape and one colour per source,
/// kept on this device, shared by every conversation from it.
struct SourceAppearanceView: View {
    @AppStorage(SourceAppearance.shapeKey(.dsh)) private var dshShape = SourceAppearance.defaultShape
    @AppStorage(SourceAppearance.colorKey(.dsh)) private var dshColor = SourceAppearance.defaultColor
    @AppStorage(SourceAppearance.shapeKey(.dsBot)) private var dsBotShape = SourceAppearance.defaultShape
    @AppStorage(SourceAppearance.colorKey(.dsBot)) private var dsBotColor = SourceAppearance.defaultColor

    var body: some View {
        List {
            section("DSH 编程", kind: .dsh, shape: $dshShape, color: $dshColor)
            section("DS Bot", kind: .dsBot, shape: $dsBotShape, color: $dsBotColor)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("来源外观")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, kind: SourceKind,
                         shape: Binding<String>, color: Binding<String>) -> some View {
        Section {
            HStack(spacing: 14) {
                CharacterAvatar(shape: shape.wrappedValue, color: color.wrappedValue, size: 48)
                    .overlay(alignment: .bottomTrailing) {
                        if let dot = kind.dot { SourceDot(color: dot, size: 8) }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.text)
                    Text("这个来源下所有会话都用它")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            AvatarPicker(shape: shape, color: color)
                .padding(.vertical, 6)
        } header: {
            Text(title)
        }
    }
}
