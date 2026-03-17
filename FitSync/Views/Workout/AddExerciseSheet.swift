import SwiftUI

struct AddExerciseSheet: View {
    @Bindable var workoutState: WorkoutState
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private let strengthExercises = [
        "杠铃卧推", "哑铃卧推", "上斜哑铃卧推", "绳索飞鸟",
        "引体向上", "高位下拉", "坐姿划船", "杠铃划船",
        "杠铃深蹲", "腿举", "腿屈伸", "腿弯举",
        "坐姿肩推", "侧平举", "绳索下压", "哑铃弯举"
    ]

    private let cardioExercises = [
        "跑步机", "跑步机爬坡", "椭圆机", "划船机", "动感单车"
    ]

    private let cardioKeywords = ["跑步", "椭圆", "划船", "单车", "游泳", "骑行", "有氧"]

    private func isCardio(_ name: String) -> Bool {
        cardioKeywords.contains { name.contains($0) } || cardioExercises.contains(name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        TextField("搜索或输入动作名称", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            guard !searchText.isEmpty else { return }
                            let type = isCardio(searchText) ? "cardio" : "strength"
                            workoutState.addExercise(name: searchText, type: type)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(searchText.isEmpty)
                    }

                    Text("力量训练").font(.headline)
                    FlowLayout(spacing: 8) {
                        ForEach(strengthExercises, id: \.self) { name in
                            Button(name) {
                                workoutState.addExercise(name: name, type: "strength")
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Text("有氧训练").font(.headline)
                    FlowLayout(spacing: 8) {
                        ForEach(cardioExercises, id: \.self) { name in
                            Button(name) {
                                workoutState.addExercise(name: name, type: "cardio")
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.orange)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("追加训练项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
