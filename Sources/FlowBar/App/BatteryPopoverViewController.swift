import AppKit
import SwiftUI

final class BatteryPopoverViewController: NSViewController {
    static let preferredContentSize = NSSize(width: FlowBarPopoverLayout.width, height: FlowBarPopoverLayout.height)

    private let viewModel: FlowBarPopoverViewModel
    private let hostingController: NSHostingController<FlowBarPopoverRootView>

    init(launchAtLoginController: LaunchAtLoginController? = nil) {
        let viewModel = FlowBarPopoverViewModel(launchAtLoginController: launchAtLoginController ?? LaunchAtLoginController())
        self.viewModel = viewModel
        hostingController = NSHostingController(rootView: FlowBarPopoverRootView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
        viewModel.onLaunchAtLoginNotice = { [weak self] notice in
            self?.presentLaunchAtLoginNotice(notice)
        }
    }

    func configureSelection(_ metric: MenuBarMetric, onChange: @escaping (MenuBarMetric) -> Void) {
        viewModel.selectedMetric = metric
        viewModel.onMetricChange = onChange
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

    func refreshLaunchAtLogin() {
        viewModel.refreshLaunchAtLogin()
    }

    private func presentLaunchAtLoginNotice(_ notice: LaunchAtLoginNotice) {
        let alert = NSAlert()
        switch notice {
        case .requiresApproval:
            alert.messageText = "请允许 FlowBar 登录时启动"
            alert.informativeText = "请在系统设置的登录项中允许 FlowBar，然后返回应用。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
        case .failed(let message):
            alert.messageText = "无法更改登录时启动设置"
            alert.informativeText = message
            alert.addButton(withTitle: "好")
        }

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard notice == .requiresApproval, response == .alertFirstButtonReturn else { return }
            self?.viewModel.openLoginItemSettings()
        }
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}

private enum FlowBarPopoverLayout {
    static let width: CGFloat = 276
    static let height: CGFloat = 493
    static let arrowHeight: CGFloat = 16
    static let cornerRadius: CGFloat = 22
}

struct FlowBarPopoverRootView: View {
    @ObservedObject var viewModel: FlowBarPopoverViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bubble = FlowBarBubbleShape(arrowWidth: 28, arrowHeight: FlowBarPopoverLayout.arrowHeight, cornerRadius: FlowBarPopoverLayout.cornerRadius)

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

                FlowBarMetricSelector(metric: viewModel.selectedMetric, onMove: viewModel.cycleMetric)

                FlowBarLaunchCard(isEnabled: viewModel.launchAtLoginEnabled) { [viewModel] enabled in
                    viewModel.setLaunchAtLoginEnabled(enabled)
                }

                FlowBarQuitCard(action: viewModel.quit)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .frame(width: FlowBarPopoverLayout.width, height: FlowBarPopoverLayout.height, alignment: .topLeading)
        }
        .frame(width: FlowBarPopoverLayout.width, height: FlowBarPopoverLayout.height)
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
        .modifier(FlowBarCardStyle())
    }
}

private struct FlowBarMetricLine: View {
    let row: FlowBarMetricRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.metric.symbol)
                .font(.system(size: 20, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(row.metric.tint.opacity(0.88))
                .frame(width: 28)

            Text(row.metric.title)
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
    var onChange: @MainActor @Sendable (Bool) -> Void

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
                .accessibilityLabel("登录时启动")
                .toggleStyle(.switch)
                .controlSize(.small)
                .modifier(PointingHandCursor())
        }
        .frame(height: 42)
        .padding(.horizontal, 14)
        .modifier(FlowBarCardStyle())
    }
}

private struct FlowBarQuitCard: View {
    var action: () -> Void
    @State private var isHovering = false

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
        .modifier(FlowBarCardStyle(highlight: Color.red.opacity(isHovering ? 0.08 : 0)))
        .onHover { hovering in
            isHovering = hovering
        }
        .modifier(PointingHandCursor())
    }
}

private struct PointingHandCursor: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                    // Reassert during movement: the hosting view can reset the cursor.
                    NSCursor.pointingHand.set()
                case .ended:
                    restoreCursor()
                }
            }
            .onDisappear { restoreCursor() }
    }

    private func restoreCursor() {
        guard isHovering else { return }
        isHovering = false
        NSCursor.arrow.set()
    }
}

private struct FlowBarCardStyle: ViewModifier {
    var highlight: Color? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        content
            .background {
                shape.fill(cardFill)
                    .overlay {
                        if let highlight {
                            shape.fill(highlight)
                        }
                    }
            }
            .overlay {
                shape.stroke(Color.white.opacity(0.32), lineWidth: 0.5)
            }
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

extension MenuBarMetric {
    var tint: Color {
        switch self {
        case .download: return Color(red: 0.43, green: 0.39, blue: 0.96)
        case .upload: return Color(red: 0.16, green: 0.58, blue: 0.84)
        case .temperature: return .red
        case .power, .level: return .green
        case .powerState: return .blue
        }
    }
}

private struct FlowBarMetricSelector: View {
    let metric: MenuBarMetric
    let onMove: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("菜单栏显示")
                Spacer()
                Text("\(metric.index + 1) / \(MenuBarMetric.allCases.count)").monospacedDigit()
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.secondary.opacity(0.75))
            .padding(.horizontal, 4)
            HStack {
                arrow("chevron.left", label: "上一项", offset: -1)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: metric.symbol)
                        .font(.system(size: 16)).foregroundStyle(metric.tint.opacity(0.88))
                        .frame(width: 24)
                    Text(metric.title).font(.system(size: 13))
                }
                .foregroundStyle(Color.primary.opacity(0.78))
                Spacer(minLength: 0)
                arrow("chevron.right", label: "下一项", offset: 1)
            }
            .frame(height: 32)
        }
        .padding(.horizontal, 10)
        .frame(height: 66)
        .modifier(FlowBarCardStyle())
    }

    private func arrow(_ symbol: String, label: String, offset: Int) -> some View {
        Button { onMove(offset) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.78))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(PointingHandCursor())
        .accessibilityLabel(label)
        .help(label)
    }
}
