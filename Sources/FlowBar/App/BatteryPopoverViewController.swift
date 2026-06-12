import AppKit
import SwiftUI

final class BatteryPopoverViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 276, height: 390)
    static let cornerRadius: CGFloat = 22

    private let viewModel: FlowBarPopoverViewModel
    private let hostingController: NSHostingController<FlowBarPopoverRootView>

    init(launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()) {
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: launchAtLoginController)
        self.viewModel = viewModel
        hostingController = NSHostingController(rootView: FlowBarPopoverRootView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        addChild(hostingController)
        hostingController.view.frame = NSRect(origin: .zero, size: Self.preferredContentSize)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        view = hostingController.view
    }

    func update(snapshot: MetricsSnapshot) {
        viewModel.update(snapshot: snapshot)
    }
}

final class FlowBarPopoverViewModel: ObservableObject {
    @Published var rows: [FlowBarMetricRow] = []
    @Published var launchAtLoginEnabled: Bool

    private let launchAtLoginController: LaunchAtLoginController

    init(launchAtLoginController: LaunchAtLoginController) {
        self.launchAtLoginController = launchAtLoginController
        launchAtLoginEnabled = launchAtLoginController.isEnabled
        update(snapshot: .unavailable)
    }

    func update(snapshot: MetricsSnapshot) {
        rows = [
            FlowBarMetricRow(symbolName: "arrow.down.circle", title: "下载速度", value: MetricFormatters.downloadSpeed(snapshot.downloadBytesPerSecond), tint: Color(red: 0.43, green: 0.39, blue: 0.96)),
            FlowBarMetricRow(symbolName: "thermometer", title: "电池温度", value: MetricFormatters.temperature(snapshot.battery.temperatureCelsius), tint: .red),
            FlowBarMetricRow(symbolName: "bolt.fill", title: "充电功率", value: MetricFormatters.chargingPower(snapshot.battery.chargingWatts), tint: .green),
            FlowBarMetricRow(symbolName: "battery.75", title: "电池电量", value: MetricFormatters.batteryLevel(snapshot.battery.levelPercent), tint: .green),
            FlowBarMetricRow(symbolName: "powerplug", title: "电源状态", value: MetricFormatters.powerState(snapshot.battery.powerState), tint: .blue)
        ]
        launchAtLoginEnabled = launchAtLoginController.isEnabled
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginController.setEnabled(enabled)
        launchAtLoginEnabled = launchAtLoginController.isEnabled
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

struct FlowBarMetricRow: Identifiable {
    let id = UUID()
    var symbolName: String
    var title: String
    var value: String
    var tint: Color
}

struct FlowBarPopoverRootView: View {
    private enum Layout {
        static let width: CGFloat = 276
        static let height: CGFloat = 378
        static let arrowHeight: CGFloat = 16
        static let cornerRadius: CGFloat = 22
    }

    @ObservedObject var viewModel: FlowBarPopoverViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bubble = FlowBarBubbleShape(arrowWidth: 28, arrowHeight: Layout.arrowHeight, cornerRadius: Layout.cornerRadius)

        ZStack {
            bubble
                .fill(Color.clear)
                .background {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(bubble)
                }
                .overlay { bubble.fill(glassTint) }
                .overlay { bubble.stroke(Color.white.opacity(outerHighlightOpacity), lineWidth: 1) }
                .overlay { bubble.inset(by: 1.2).stroke(Color.white.opacity(innerHighlightOpacity), lineWidth: 0.5) }
                .overlay(alignment: .bottom) {
                    bubble
                        .stroke(Color.black.opacity(bottomEdgeOpacity), lineWidth: 0.7)
                        .blur(radius: 0.4)
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("设备状态")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(textOpacity))
                    .padding(.top, 34)

                FlowBarMetricCard(rows: viewModel.rows)

                FlowBarLaunchCard(isEnabled: viewModel.launchAtLoginEnabled, onChange: viewModel.setLaunchAtLoginEnabled)

                FlowBarQuitCard(action: viewModel.quit)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .frame(width: Layout.width, height: Layout.height, alignment: .topLeading)
        }
        .frame(width: Layout.width, height: Layout.height)
        .background(Color.clear)
    }

    private var glassTint: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.92, green: 0.96, blue: 1.0).opacity(colorScheme == .dark ? 0.10 : 0.26),
                Color(red: 0.84, green: 0.91, blue: 1.0).opacity(colorScheme == .dark ? 0.07 : 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var outerHighlightOpacity: Double { colorScheme == .dark ? 0.28 : 0.66 }
    private var innerHighlightOpacity: Double { colorScheme == .dark ? 0.12 : 0.26 }
    private var bottomEdgeOpacity: Double { colorScheme == .dark ? 0.20 : 0.10 }
    private var textOpacity: Double { colorScheme == .dark ? 0.90 : 0.78 }
}

private struct FlowBarMetricCard: View {
    let rows: [FlowBarMetricRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                FlowBarMetricLine(row: row)
                    .frame(height: 38)

                if index < rows.count - 1 {
                    Divider()
                        .opacity(0.32)
                        .padding(.leading, 46)
                }
            }
        }
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 0.5)
        }
    }

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color(red: 0.84, green: 0.92, blue: 1.0).opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct FlowBarMetricLine: View {
    let row: FlowBarMetricRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbolName)
                .font(.system(size: 20, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(row.tint.opacity(0.88))
                .frame(width: 28)

            Text(row.title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.78))

            Spacer(minLength: 10)

            Text(row.value)
                .font(.system(size: 15, weight: .regular).monospacedDigit())
                .foregroundStyle(Color.secondary.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
    }
}

private struct FlowBarLaunchCard: View {
    var isEnabled: Bool
    var onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color.blue.opacity(0.88))
                .frame(width: 28)

            Text("登录时启动")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.78))

            Spacer()

            Toggle("", isOn: Binding(get: { isEnabled }, set: onChange))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(height: 42)
        .padding(.horizontal, 14)
        .background(smallCardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 0.5)
        }
    }
}

private struct FlowBarQuitCard: View {
    var action: () -> Void
    @ObservedObject private var hoverState = FlowBarHoverState()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "power")
                    .font(.system(size: 23, weight: .regular))
                    .frame(width: 28)

                Text("退出")
                    .font(.system(size: 15, weight: .regular))

                Spacer()
            }
            .foregroundStyle(Color.red.opacity(0.90))
            .frame(height: 42)
            .padding(.horizontal, 14)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay {
            CursorTrackingView()
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(smallCardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(hoverState.isHovering ? 0.08 : 0))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 0.5)
        }
        .onHover { hovering in
            hoverState.isHovering = hovering
        }
    }
}

private final class FlowBarHoverState: ObservableObject {
    @Published var isHovering = false
}

private struct CursorTrackingView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        CursorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class CursorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

private var smallCardFill: LinearGradient {
    LinearGradient(
        colors: [
            Color.white.opacity(0.16),
            Color(red: 0.84, green: 0.92, blue: 1.0).opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct FlowBarBubbleShape: InsettableShape {
    var arrowWidth: CGFloat
    var arrowHeight: CGFloat
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> FlowBarBubbleShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let top = rect.minY + arrowHeight
        let radius = max(0, cornerRadius - insetAmount)
        let center = rect.midX
        let halfArrow = max(0, (arrowWidth - insetAmount) / 2)
        let baseRadius: CGFloat = 5
        let tipRadius: CGFloat = 3.5

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: top))
        path.addLine(to: CGPoint(x: center - halfArrow - baseRadius, y: top))
        path.addQuadCurve(to: CGPoint(x: center - halfArrow + baseRadius * 0.45, y: top - baseRadius * 0.75), control: CGPoint(x: center - halfArrow, y: top))
        path.addLine(to: CGPoint(x: center - tipRadius, y: rect.minY + tipRadius))
        path.addQuadCurve(to: CGPoint(x: center + tipRadius, y: rect.minY + tipRadius), control: CGPoint(x: center, y: rect.minY - tipRadius * 0.45))
        path.addLine(to: CGPoint(x: center + halfArrow - baseRadius * 0.45, y: top - baseRadius * 0.75))
        path.addQuadCurve(to: CGPoint(x: center + halfArrow + baseRadius, y: top), control: CGPoint(x: center + halfArrow, y: top))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + radius), control: CGPoint(x: rect.maxX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: top), control: CGPoint(x: rect.minX, y: top))
        path.closeSubpath()
        return path
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
