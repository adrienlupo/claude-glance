import SwiftUI

struct PillView: View {
    let store: SessionStore
    @Binding var isExpanded: Bool
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            pillContent
                .frame(height: 36)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                SessionDetailView(store: store)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        if store.sessions.isEmpty {
            HStack(spacing: 6) {
                Circle()
                    .fill(SessionStatus.disconnected.color)
                    .frame(width: 8, height: 8)
                Text("No sessions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .opacity(0.6)
        } else {
            HStack(spacing: 12) {
                ForEach(store.countsByStatus) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.status.color)
                            .frame(width: 8, height: 8)
                            .opacity(item.status == .busy ? pulseOpacity : 1.0)
                        Text("\(item.count) \(item.status.label)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }
        }
    }
}
