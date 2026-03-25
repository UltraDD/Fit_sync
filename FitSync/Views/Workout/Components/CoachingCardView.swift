import SwiftUI

struct CoachingCardView: View {
    let coaching: ExerciseCoaching
    let collapsed: Bool
    @Binding var showDetail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let keyCues = coaching.key_cues, !keyCues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "key.fill").foregroundStyle(FLColor.amberLight)
                        Text("核心口诀").font(.subheadline.bold()).foregroundStyle(FLColor.amberLight)
                    }
                    ForEach(keyCues, id: \.self) { cue in
                        Text("• \(cue)").font(.subheadline).foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 4)
            }

            if collapsed {
                Button { showDetail.toggle() } label: {
                    HStack {
                        Image(systemName: "book.fill").foregroundStyle(FLColor.text40)
                        Text("详细动作教学").font(.subheadline.bold()).foregroundStyle(FLColor.text40)
                        Spacer()
                        Text(showDetail ? "收起" : "展开")
                            .font(.caption).foregroundStyle(FLColor.text30)
                        Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(FLColor.text30)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Image(systemName: "book.fill").foregroundStyle(FLColor.text40)
                    Text("详细动作教学").font(.subheadline.bold()).foregroundStyle(FLColor.text40)
                }
            }

            if !collapsed || showDetail {
                detailContent
            }
        }
        .glassCard(padding: 16)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let setup = coaching.setup {
                coachingItem("起始姿势", setup)
            }
            if let execution = coaching.execution {
                coachingItem("动作过程", execution)
            }
            if let breathing = coaching.breathing {
                HStack(alignment: .top, spacing: 8) {
                    Text("呼吸").font(.caption.bold()).foregroundStyle(FLColor.text40)
                    Text(breathing).font(.caption).foregroundStyle(FLColor.text60)
                }
            }
            if let tips = coaching.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("安全提示").font(.caption.bold()).foregroundStyle(FLColor.green.opacity(0.8))
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "checkmark").font(.caption2).foregroundStyle(FLColor.green.opacity(0.8))
                            Text(tip).font(.caption).foregroundStyle(FLColor.text60)
                        }
                    }
                }
            }
            if let mistakes = coaching.mistakes, !mistakes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("常见错误").font(.caption.bold()).foregroundStyle(FLColor.red.opacity(0.8))
                    ForEach(mistakes, id: \.self) { m in
                        Text("• \(m)").font(.caption).foregroundStyle(FLColor.text60)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func coachingItem(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(FLColor.text40)
            Text(text).font(.caption).foregroundStyle(FLColor.text60).lineSpacing(3)
        }
    }

    static func hasContent(_ coaching: ExerciseCoaching?) -> Bool {
        guard let c = coaching else { return false }
        return c.setup != nil || c.execution != nil || c.breathing != nil
            || (c.tips != nil && !(c.tips!.isEmpty))
            || (c.mistakes != nil && !(c.mistakes!.isEmpty))
            || (c.key_cues != nil && !(c.key_cues!.isEmpty))
    }
}
