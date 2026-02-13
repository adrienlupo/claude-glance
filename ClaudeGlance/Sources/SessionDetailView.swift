import SwiftUI

struct SessionDetailView: View {
    let store: SessionStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.sessions) { session in
                        Button {
                            ITerm.focusSession(tty: session.tty)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(session.status.color)
                                    .frame(width: 6, height: 6)

                                Text(session.projectName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                ContextBar(percentage: session.contextPercentage)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: CGFloat(min(store.sessions.count, 5)) * 26)
        }
        .padding(.bottom, 6)
    }
}

private struct ContextBar: View {
    let percentage: Int?

    private var barColor: Color {
        guard let pct = percentage else { return .clear }
        switch pct {
        case 80...: return Color(red: 1.0, green: 0.271, blue: 0.227)
        case 50..<80: return Color(red: 0.988, green: 0.816, blue: 0.145)
        default: return Color(red: 0.204, green: 0.780, blue: 0.349)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 60, height: 3)
                if let pct = percentage, pct > 0 {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor)
                        .frame(width: 60 * CGFloat(pct) / 100, height: 3)
                }
            }

            Text(percentage.map { "\($0)%" } ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}
