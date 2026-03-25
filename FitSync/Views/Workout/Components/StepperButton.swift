import SwiftUI

struct StepperButton: View {
    let systemName: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(size > 50 ? .title : .title2)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: 16)
                )
        }
    }
}
