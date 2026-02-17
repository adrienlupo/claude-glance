import SwiftUI

struct PillView: View {
    let store: SessionStore
    @Binding var widgetState: WidgetState
    var onHidePanel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            pillHeader
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())

            if widgetState == .expanded {
                if store.sessions.isEmpty {
                    noSessionDetail
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    SessionDetailView(store: store)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pillHeaderTapped)) { _ in
            withAnimation(.spring(duration: 0.2)) {
                switch widgetState {
                case .empty, .collapsed:
                    widgetState = .expanded
                case .expanded:
                    widgetState = store.sessions.isEmpty ? .empty : .collapsed
                }
            }
        }
        .contextMenu {
            Button("Hide") {
                onHidePanel?()
            }
        }
        .onChange(of: store.sessions.isEmpty) { _, isEmpty in
            withAnimation(.spring(duration: 0.2)) {
                if isEmpty {
                    widgetState = .empty
                } else if widgetState == .empty {
                    widgetState = .collapsed
                }
            }
        }
    }

    private var noSessionDetail: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            Text("No session")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .padding(.bottom, 6)
        }
    }

    @MainActor @ViewBuilder
    private var pillHeader: some View {
        switch widgetState {
        case .empty:
            LogoView(isActive: false)
                .frame(width: 20, height: 20)
                .opacity(0.7)
        case .collapsed, .expanded:
            HStack(spacing: 8) {
                LogoView(isActive: !store.sessions.isEmpty)
                    .frame(width: 20, height: 20)

                ForEach(store.countsByStatus) { item in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(item.status.color)
                            .frame(width: 8, height: 8)
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
    }
}
