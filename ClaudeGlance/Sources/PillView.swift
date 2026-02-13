import SwiftUI

struct PillView: View {
    let store: SessionStore
    @Binding var widgetState: WidgetState
    @State private var pulsing = false
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
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.status == .busy && pulsing ? Color(red: 1.0, green: 0.72, blue: 0.15) : item.status.color)
                            .frame(width: 8, height: 8)
                            .scaleEffect(item.status == .busy && pulsing ? 1.3 : 1.0)
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
        }
    }
}
