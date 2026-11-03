import CodyncKit
import CodyncUI
import SwiftUI

struct TestTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader {
                EmptyView()
            } title: {
                Text("测试").font(.body.weight(.semibold)).foregroundStyle(Palette.text)
            } trailing: {
                EmptyView()
            }

            VStack(spacing: 16) {
                RemixIcon("flask-fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Palette.secondary)
                Text("第四个导航已就位")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text("这是你的第一个自定义页面。")
                    .font(.body)
                    .foregroundStyle(Palette.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.background)
    }
}
