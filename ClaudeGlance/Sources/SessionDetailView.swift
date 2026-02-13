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

                                Text(session.status.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
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
