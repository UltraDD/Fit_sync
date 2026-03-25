import SwiftUI

struct RPESelectorView: View {
    let onSelect: (Double?) -> Void

    private let rpeValues: [(Double, String, String)] = [
        (6, "很轻松", "还能做4+次"), (7, "轻松", "还能做3次"),
        (7.5, "较轻松", "还能做2-3次"), (8, "有挑战", "还能做2次"),
        (8.5, "较吃力", "还能做1-2次"), (9, "很吃力", "还能做1次"),
        (9.5, "极吃力", "勉强再挤半次"), (10, "力竭", "做不动了"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("RPE 自觉用力程度（可选）")
                .font(.subheadline).foregroundStyle(FLColor.text40)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(rpeValues, id: \.0) { value, label, desc in
                    Button { onSelect(value) } label: {
                        HStack(spacing: 8) {
                            Text(value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value))
                                .font(.headline.monospacedDigit())
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text(label).font(.caption.bold())
                                Text(desc).font(.caption2).foregroundStyle(FLColor.text40)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(FLColor.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("跳过") { onSelect(nil) }
                .font(.subheadline).foregroundStyle(FLColor.text30)
        }
        .glassCard()
    }
}
