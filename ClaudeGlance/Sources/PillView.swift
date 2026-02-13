import SwiftUI

struct PillView: View {
    let store: SessionStore
    @Binding var widgetState: WidgetState
    @State private var pulseOpacity: Double = 1.0
    var onHidePanel: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            pillHeader
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) {
                        switch widgetState {
                        case .empty, .collapsed:
                            widgetState = .expanded
                        case .expanded:
                            widgetState = store.sessions.isEmpty ? .empty : .collapsed
                        }
                    }
                }

            if widgetState == .expanded {
                SessionDetailView(store: store)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

    @ViewBuilder
    private var pillHeader: some View {
        switch widgetState {
        case .empty:
            LogoView(isActive: false)
                .frame(width: 20, height: 20)
                .opacity(0.7)
        case .collapsed, .expanded:
            HStack(spacing: 8) {
                LogoView(isActive: true)
                    .frame(width: 20, height: 20)

                ForEach(store.countsByStatus) { item in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(item.status.color)
                            .frame(width: 8, height: 8)
                            .opacity(item.status == .busy ? pulseOpacity : 1.0)
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .onAppear {
                pulseOpacity = 1.0
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }
        }
    }
}
