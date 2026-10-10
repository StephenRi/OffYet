import SwiftUI

struct Palette {
    let bgGradient: LinearGradient
    let card: Color
    let border: Color
    let text: Color
    let text2: Color
    let accent: Color
    let accent2: Color
    let money: Color
    let moneyBadge: Color
    let track: Color
    let error: Color
    let calendarIcon: Color
    let calendarBg: Color
    let walletIcon: Color
    let walletBg: Color
    let hourglassIcon: Color
    let hourglassBg: Color

    static func palette(_ dark: Bool) -> Palette {
        if dark {
            return Palette(
                bgGradient: LinearGradient(colors: [Color(hex: 0x1B1B24), Color(hex: 0x17181F), Color(hex: 0x161D1A)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                card: Color(hex: 0x232328),
                border: Color.white.opacity(0.10),
                text: Color(hex: 0xF5F5F7),
                text2: Color(hex: 0x9D9DA3),
                accent: Color(hex: 0x409CFF),
                accent2: Color(hex: 0x9D7CFF),
                money: Color(hex: 0x30D158),
                moneyBadge: Color(hex: 0x30D158).opacity(0.16),
                track: Color.white.opacity(0.12),
                error: Color(hex: 0xE5484D),
                calendarIcon: Color(hex: 0x409CFF), calendarBg: Color(hex: 0x409CFF).opacity(0.16),
                walletIcon: Color(hex: 0x64D2FF), walletBg: Color(hex: 0x64D2FF).opacity(0.16),
                hourglassIcon: Color(hex: 0x9D7CFF), hourglassBg: Color(hex: 0x9D7CFF).opacity(0.16))
        }
        return Palette(
            bgGradient: LinearGradient(colors: [Color(hex: 0xEEF0FE), Color(hex: 0xE6F0FD), Color(hex: 0xE8F8EF)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
            card: .white,
            border: Color.black.opacity(0.08),
            text: Color(hex: 0x1D1D1F),
            text2: Color(hex: 0x6E6E73),
            accent: Color(hex: 0x0A84FF),
            accent2: Color(hex: 0x7A5CFF),
            money: Color(hex: 0x1D9D54),
            moneyBadge: Color(hex: 0x1D9D54).opacity(0.12),
            track: Color.black.opacity(0.08),
            error: Color(hex: 0xE5484D),
            calendarIcon: Color(hex: 0x0A84FF), calendarBg: Color(hex: 0x0A84FF).opacity(0.12),
            walletIcon: Color(hex: 0x32ADE6), walletBg: Color(hex: 0x32ADE6).opacity(0.14),
            hourglassIcon: Color(hex: 0x7A5CFF), hourglassBg: Color(hex: 0x7A5CFF).opacity(0.12))
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
