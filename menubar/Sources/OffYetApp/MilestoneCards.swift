import SwiftUI

struct MilestoneCard: View {
    let label: String
    let valueText: String
    let sub: String
    let icon: String      // SF Symbol 名
    let tint: Color
    let tintBg: Color
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tintBg)
                .cornerRadius(11)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).tracking(1).foregroundColor(palette.text2)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(valueText)
                        .font(.system(size: 21, weight: .bold)).monospacedDigit()
                    Text("天").font(.system(size: 11)).foregroundColor(palette.text2)
                }
                Text(sub).font(.system(size: 11)).foregroundColor(palette.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(palette.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.border))
    }
}
