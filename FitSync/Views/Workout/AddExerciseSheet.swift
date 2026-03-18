import SwiftUI

struct AddExerciseSheet: View {
    @Bindable var workoutState: WorkoutState
    var batchMode: Bool = false
    @State private var searchText = ""
    @State private var addedCount = 0
    @Environment(\.dismiss) private var dismiss

    private static let splitCategories: [(label: String, items: [String])] = [
        ("胸 + 三头", ["杠铃卧推", "上斜哑铃卧推", "器械夹胸", "绳索飞鸟", "绳索下压", "仰卧臂屈伸"]),
        ("背 + 二头", ["引体向上", "杠铃划船", "坐姿划船", "高位下拉", "哑铃弯举", "锤式弯举"]),
        ("肩 + 核心", ["哑铃推肩", "哑铃侧平举", "面拉", "杠铃耸肩", "卷腹", "悬垂举腿"]),
        ("腿 + 臀", ["杠铃深蹲", "腿举", "罗马尼亚硬拉", "腿弯举", "保加利亚分腿蹲", "臀推"]),
    ]

    private static let cardioExercises = ["跑步机爬坡", "椭圆机", "划船机", "动感单车"]
    private static let cardioKeywords = ["跑步", "椭圆", "划船", "单车", "游泳", "骑行", "有氧", "爬坡"]

    private func guessType(_ name: String) -> String {
        Self.cardioKeywords.contains(where: { name.contains($0) }) ? "cardio" : "strength"
    }

    private var recentExercises: [String] {
        let names = WorkoutStore.shared.recentExerciseNames(limit: 6)
        return names.isEmpty ? ["绳索飞鸟", "引体向上", "坐姿划船", "哑铃侧平举"] : names
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FLColor.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        searchBar
                        recentSection
                        ForEach(Self.splitCategories, id: \.label) { cat in
                            categorySection(cat.label, items: cat.items, type: "strength")
                        }
                        categorySection("有氧训练", items: Self.cardioExercises, type: "cardio")
                    }
                    .padding(20)
                }
            }
            .navigationTitle(batchMode ? "选择训练动作" : "追加训练项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(FLColor.text60)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if batchMode && addedCount > 0 {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成选择（已添加 \(addedCount) 个）")
                    }
                    .buttonStyle(GreenButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                    .background(FLColor.bg.opacity(0.8).background(.ultraThinMaterial))
                }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("搜索或自定义动作名称", text: $searchText)
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FLColor.cardBorder))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("添加") {
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let name = searchText.trimmingCharacters(in: .whitespaces)
                addExercise(name: name, type: guessType(name))
                searchText = ""
            }
            .buttonStyle(GreenButtonStyle(fullWidth: false))
            .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(searchText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近使用")
                .font(.caption.weight(.medium))
                .foregroundStyle(FLColor.text30)
                .tracking(1)
                .textCase(.uppercase)
            FlowLayout(spacing: 8) {
                ForEach(recentExercises, id: \.self) { name in
                    chipButton(name) { addExercise(name: name, type: guessType(name)) }
                }
            }
        }
    }

    // MARK: - Category

    private func categorySection(_ label: String, items: [String], type: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(FLColor.text30)
                .tracking(1)
                .textCase(.uppercase)
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { name in
                    chipButton(name, accent: type == "cardio" ? FLColor.amber : nil) {
                        addExercise(name: name, type: type)
                    }
                }
            }
        }
    }

    private func chipButton(_ text: String, accent: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(accent ?? .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(FLColor.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper

    private func addExercise(name: String, type: String) {
        workoutState.addExercise(name: name, type: type)
        addedCount += 1
        if !batchMode { dismiss() }
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
