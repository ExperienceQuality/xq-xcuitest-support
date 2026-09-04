import SwiftUI

@main
struct InteractionFixtureApp: App {
    var body: some Scene { WindowGroup { FixtureRootView() } }
}

private struct FixtureRootView: View {
    private let mode: String = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--fixture"), arguments.indices.contains(index + 1) else {
            return "scroll"
        }
        return arguments[index + 1]
    }()

    var body: some View {
        switch mode {
        case "swipe": SwipeRecorderView()
        case "covered": CoveredReferenceView()
        default: ScrollAndDragView()
        }
    }
}

private struct SwipeRecorderView: View {
    @State private var direction = "none"
    @State private var percentage = 0

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(direction).accessibilityIdentifier("gesture.direction")
                Text("\(percentage)").accessibilityIdentifier("gesture.percentage")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.blue.opacity(0.2))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1).onEnded { value in
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    if horizontal {
                        direction = value.translation.width < 0 ? "left" : "right"
                        percentage = Int((abs(value.translation.width) / geometry.size.width * 100).rounded())
                    } else {
                        direction = value.translation.height < 0 ? "up" : "down"
                        percentage = Int((abs(value.translation.height) / geometry.size.height * 100).rounded())
                    }
                }
            )
        }
        .ignoresSafeArea()
    }
}

private struct ScrollAndDragView: View {
    @State private var transientVisible = false
    @State private var horizontalTargetVisible = false
    @State private var dropCount = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 8) {
                    Text("Visible")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("vertical.visible")
                    if transientVisible {
                        Text("Transient")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("vertical.transient")
                    }
                    Color.clear
                        .frame(height: geometry.size.height + 100)
                        .accessibilityHidden(true)
                    Text("One swipe target")
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .accessibilityIdentifier("vertical.one-swipe")
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(0..<8) { index in
                                Group {
                                    if index == 2, horizontalTargetVisible {
                                        Text("Horizontal target")
                                            .accessibilityIdentifier("horizontal.target")
                                    } else {
                                        Text("Column \(index)")
                                            .accessibilityIdentifier("horizontal.\(index)")
                                    }
                                }
                                .frame(width: geometry.size.width * 0.4, height: 80)
                            }
                        }
                    }
                    .accessibilityIdentifier("horizontal.container")
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1).onEnded { _ in
                            horizontalTargetVisible = true
                        }
                    )
                    HStack {
                        Text("Drag source")
                            .frame(width: 120, height: 60)
                            .background(.blue)
                            .accessibilityIdentifier("drag.source")
                            .draggable("fixture-item")
                        Text("Drop target")
                            .frame(width: 120, height: 60)
                            .background(.green)
                            .accessibilityIdentifier("drag.target")
                            .dropDestination(for: String.self) { _, _ in
                                dropCount += 1
                                return true
                            }
                    }
                    Text("drop-count-\(dropCount)").accessibilityIdentifier("drop.result")
                    Color.clear.frame(height: geometry.size.height)
                    Text("Offscreen source").accessibilityIdentifier("offscreen.source")
                }
            }
            .accessibilityIdentifier("vertical.container")
            .simultaneousGesture(
                DragGesture(minimumDistance: 1).onEnded { _ in
                    transientVisible = true
                }
            )
        }
    }
}

private struct CoveredReferenceView: View {
    var body: some View {
        ZStack {
            ScrollView {
                Text("Covered target")
                    .frame(height: 300)
                    .accessibilityIdentifier("covered.target")
            }
            .accessibilityIdentifier("covered.container")
            Color.black.accessibilityIdentifier("cover.overlay")
        }
    }
}
