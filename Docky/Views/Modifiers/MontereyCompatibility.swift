import SwiftUI

enum DockyScrollBehavior {
    enum LimitBehavior { case always }
    case paging
    case viewAligned(limitBehavior: LimitBehavior)
}

extension View {
    @ViewBuilder
    func dockyScrollTargetLayout() -> some View {
        if #available(macOS 14.0, *) { self.scrollTargetLayout() } else { self }
    }

    @ViewBuilder
    func dockyScrollTargetBehavior(_ behavior: DockyScrollBehavior) -> some View {
        if #available(macOS 14.0, *) {
            switch behavior {
            case .paging: self.scrollTargetBehavior(.paging)
            case .viewAligned: self.scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            }
        } else {
            // Monterey uses ordinary trackpad scrolling and explicit page buttons.
            self
        }
    }

    @ViewBuilder
    func dockyScrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        if #available(macOS 14.0, *) {
            self.scrollPosition(id: id, anchor: anchor)
        } else {
            ScrollViewReader { proxy in
                self.onChange(of: id.wrappedValue) { value in
                    if let value { proxy.scrollTo(value, anchor: anchor) }
                }
                .onAppear {
                    if let value = id.wrappedValue { proxy.scrollTo(value, anchor: anchor) }
                }
            }
        }
    }

    @ViewBuilder
    func dockyScrollClipDisabled() -> some View {
        if #available(macOS 14.0, *) { self.scrollClipDisabled() } else { self }
    }

    @ViewBuilder
    func dockyContentMargin(_ edge: Edge.Set, _ length: CGFloat) -> some View {
        if #available(macOS 14.0, *) { self.contentMargins(edge, length, for: .scrollContent) }
        else { self.padding(edge, length) }
    }
}

extension View {
    @ViewBuilder
    func dockySettingsForm() -> some View {
        if #available(macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self.padding(16)
        }
    }

    @ViewBuilder
    func dockyHideScrollBackground() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

struct DockyAnyShape: Shape {
    private let makePath: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { makePath = shape.path(in:) }
    func path(in rect: CGRect) -> Path { makePath(rect) }
}

struct DockyCornerRadii: Equatable {
    var topLeading: CGFloat = 0
    var bottomLeading: CGFloat = 0
    var bottomTrailing: CGFloat = 0
    var topTrailing: CGFloat = 0
}

/// Per-corner rounding without SwiftUI's macOS 13 shape types.
struct DockyRoundedRectangle: InsettableShape {
    var cornerRadii: DockyCornerRadii
    var style: RoundedCornerStyle = .continuous
    private var insetAmount: CGFloat = 0

    init(cornerRadii: DockyCornerRadii, style: RoundedCornerStyle = .continuous) {
        self.cornerRadii = cornerRadii
        self.style = style
    }

    init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0,
         bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0,
         style: RoundedCornerStyle = .continuous) {
        self.init(cornerRadii: DockyCornerRadii(
            topLeading: topLeadingRadius, bottomLeading: bottomLeadingRadius,
            bottomTrailing: bottomTrailingRadius, topTrailing: topTrailingRadius), style: style)
    }

    func inset(by amount: CGFloat) -> Self {
        var result = self
        result.insetAmount += amount
        return result
    }

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let limit = min(bounds.width, bounds.height) / 2
        func radius(_ value: CGFloat) -> CGFloat { min(limit, max(0, value - insetAmount)) }
        let tl = radius(cornerRadii.topLeading), tr = radius(cornerRadii.topTrailing)
        let bl = radius(cornerRadii.bottomLeading), br = radius(cornerRadii.bottomTrailing)
        let x0 = bounds.minX, x1 = bounds.maxX, y0 = bounds.minY, y1 = bounds.maxY
        var path = Path()
        path.move(to: CGPoint(x: x0 + tl, y: y0))
        path.addLine(to: CGPoint(x: x1 - tr, y: y0))
        path.addQuadCurve(to: CGPoint(x: x1, y: y0 + tr), control: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y1 - br))
        path.addQuadCurve(to: CGPoint(x: x1 - br, y: y1), control: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x0 + bl, y: y1))
        path.addQuadCurve(to: CGPoint(x: x0, y: y1 - bl), control: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x0, y: y0 + tl))
        path.addQuadCurve(to: CGPoint(x: x0 + tl, y: y0), control: CGPoint(x: x0, y: y0))
        path.closeSubpath()
        return path
    }
}
