import SwiftUI
import Combine

struct ContentView: View {
    // 圖文、按鈕、手勢與計時都透過 @State 更新畫面。
    @State private var coffee = 0
    @State private var water = 0.0
    @State private var elapsed = 0.0
    @State private var running = false
    @State private var started = false
    @State private var finished = false
    @State private var pouring = false
    @State private var automatic = true
    @State private var dragging = false
    @State private var point = CGPoint(x: 0, y: 0)
    @State private var angle = 0.0
    @State private var turns = 0.0
    @State private var lastAngle: Double?
    @State private var lastTick = Date()
    @State private var pour = 0
    @State private var message = "先加入 20 g 粗研磨咖啡粉。"
    private let starts = [0, 45, 90, 135, 180]
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var target: Double { Double((pour + 1) * 60) }
    private var active: Bool { running && pouring && (automatic || dragging) && water < target }
    private var title: String {
        if finished { return "沖煮完成" }
        if !started { return "準備咖啡粉" }
        return "第 \(pour + 1) 段 · " + (pour < 2 ? "前 40% 酸甜平衡" : "後 60% 濃度")
    }
    private func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("4:6 手沖模擬器").font(.largeTitle.bold())
                Text("粕谷哲 · 基礎五段版").foregroundStyle(.secondary)
                HStack {
                    Label("\(coffee) / 20 g 粉", systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Label("300 g 水", systemImage: "drop.fill")
                    Spacer()
                    Text("1:15")
                }.font(.subheadline)
                HStack(alignment: .firstTextBaseline) {
                    Text(clock(elapsed)).font(.system(size: 40, weight: .medium, design: .monospaced))
                    Spacer()
                    Text("目標 03:30").foregroundStyle(.secondary)
                }
                Text(title).font(.headline)
                brewScene
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20], id: \.self) { grams in
                        Text("\(grams) g")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(coffee >= grams ? Color.brown : Color.brown.opacity(0.08), in: Capsule())
                            .foregroundStyle(coffee >= grams ? Color.white : Color.brown)
                    }
                }
                HStack {
                    Text("累計 \(Int(water)) / 300 g")
                    Spacer()
                    Text("本段目標 \(Int(target)) g")
                }.monospacedDigit()
                ProgressView(value: water, total: 300).tint(.brown)
                Text(message).frame(maxWidth: .infinity, minHeight: 42)
                    .multilineTextAlignment(.center).accessibilityIdentifier("brewStatus")
                controls
                schedule
                Text("前兩段共 120 g（40%），後三段共 180 g（60%）。每段 60 g；以時間提示分段，水量達標後停止注水。實際沖煮仍需依落水情況調整。")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("食譜原理：HARIO × 粕谷哲", destination: URL(string: "https://www.hario.co.uk/products/tetsu-kasuya-02-v60-dripper")!)
                    .font(.footnote)
                Text("繞圈、水流與落水為互動示意；模擬流速 6 g／秒，並非風味或萃取率計算。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .onReceive(timer) { date in tick(date) }
    }

    private var brewScene: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy: CGFloat = 125
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color.brown.opacity(0.08))
                Circle().fill(Color.white).frame(width: 220, height: 220).position(x: cx, y: cy)
                Circle().stroke(Color.brown.opacity(0.4), lineWidth: 6)
                    .frame(width: 212, height: 212).position(x: cx, y: cy)
                // 粉堆面積依 5、10、15、20 g 逐級增加。
                let diameter = 184 * sqrt(CGFloat(coffee) / 20)
                Circle().fill(Color.gray.opacity(0.08))
                    .frame(width: 184, height: 184).position(x: cx, y: cy)
                Circle().fill(RadialGradient(colors: [Color(red: 0.48, green: 0.30, blue: 0.16), Color(red: 0.25, green: 0.13, blue: 0.06)], center: .center, startRadius: 0, endRadius: max(1, diameter / 2)))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .brown.opacity(0.25), radius: 3, y: 2)
                    .position(x: cx, y: cy)
                ForEach(0..<96) { i in
                    let a = Double(i) * 2.39996
                    let r = CGFloat(sqrt(Double(i + 1) / 96)) * max(0, diameter / 2 - 4)
                    Ellipse().fill(i.isMultiple(of: 3) ? Color(red: 0.67, green: 0.45, blue: 0.27) : Color(red: 0.20, green: 0.10, blue: 0.04))
                        .frame(width: 2 + CGFloat(i % 3), height: 2 + CGFloat(i % 2))
                        .rotationEffect(.radians(a))
                        .position(x: cx + CGFloat(cos(a)) * r, y: cy + CGFloat(sin(a)) * r)
                        .opacity(i < coffee * 4 ? 0.85 : 0)
                }
                Text(coffee == 0 ? "尚未加粉" : "咖啡粉 \(coffee) g")
                    .font(.headline.monospacedDigit()).foregroundStyle(.brown)
                    .position(x: cx, y: 237)
                Circle().stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .frame(width: 120, height: 120).position(x: cx, y: cy)
                if active {
                    Circle().fill(Color.cyan.opacity(0.25)).frame(width: 182, height: 182).position(x: cx, y: cy)
                    Path { p in
                        p.move(to: CGPoint(x: cx + point.x + 30, y: 8))
                        p.addQuadCurve(to: CGPoint(x: cx + point.x, y: cy + point.y), control: CGPoint(x: cx + point.x - 15, y: 45))
                    }.stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    Circle().stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 20 + CGFloat(sin(elapsed * 12) + 1) * 12, height: 20 + CGFloat(sin(elapsed * 12) + 1) * 12)
                        .position(x: cx + point.x, y: cy + point.y)
                }
                if started {
                    Image(systemName: "drop.fill").foregroundStyle(.cyan)
                        .position(x: cx + point.x, y: cy + point.y)
                }
                HStack(spacing: 8) {
                    Image(systemName: finished ? "cup.and.saucer.fill" : "cup.and.saucer")
                    Text(finished ? "咖啡完成" : "繞圈 \(Int(turns)) 圈 · \(automatic ? "自動示範" : "手動拖曳")")
                }.font(.subheadline).foregroundStyle(.brown).position(x: cx, y: 263)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !automatic, running, pouring else { return }
                    let x = value.location.x - cx
                    let y = value.location.y - cy
                    let radius = hypot(x, y)
                    guard radius <= 88 else { dragging = false; lastAngle = nil; return }
                    dragging = true
                    point = CGPoint(x: x, y: y)
                    let a = atan2(Double(y), Double(x))
                    if let previous = lastAngle, radius > 15 {
                        let delta = atan2(sin(a - previous), cos(a - previous))
                        turns += abs(delta) / (2 * .pi)
                    }
                    lastAngle = a
                }
                .onEnded { _ in dragging = false; lastAngle = nil })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("咖啡粉 \(coffee) g，濾杯注水模擬，\(active ? "注水中" : "停止注水")，繞圈 \(Int(turns)) 圈")
        }.frame(height: 290)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Toggle("自動繞圈示範（關閉可在粉床拖曳注水）", isOn: $automatic)
                .font(.subheadline).onChange(of: automatic) { _, _ in dragging = false; lastAngle = nil }
            if !started {
                Button("加咖啡粉 · 5 g（目前 \(coffee) g）") {
                    withAnimation(.easeInOut(duration: 0.45)) { coffee = min(coffee + 5, 20) }
                    message = coffee == 20 ? "咖啡粉就緒，開始計時並注入第一段 60 g。" : "已加入 \(coffee) g，目標 20 g。"
                }.disabled(coffee == 20)
                Button("開始沖煮與計時", systemImage: "play.fill") {
                    started = true; running = true; pouring = true; lastTick = Date()
                    message = automatic ? "第一段注水中：先潤濕粉床，到 60 g 停止。" : "在粉床內按住並繞圈拖曳，放開即停止注水。"
                }.disabled(coffee < 20)
            } else if !finished {
                HStack {
                    Button(running ? "暫停" : "繼續", systemImage: running ? "pause.fill" : "play.fill") {
                        running.toggle(); dragging = false; lastAngle = nil; lastTick = Date()
                    }
                    Button(pouring ? "停止注水" : "繼續本段注水", systemImage: "drop.fill") {
                        pouring.toggle()
                    }.disabled(!running || water >= target)
                }
                if water >= target && pour < 4 {
                    Button("下一段 · \(clock(Double(starts[pour + 1])) ) 起") {
                        pour += 1; pouring = true; dragging = false
                        message = "第 \(pour + 1) 段注水：累計目標 \(Int(target)) g。"
                    }.disabled(!running || elapsed < Double(starts[pour + 1]))
                }
                if water >= target {
                    Text(pour < 4 ? "等待落水，下一段倒數 \(max(0, starts[min(pour + 1, 4)] - Int(elapsed))) 秒" : "最後落水中，等待 03:30 完成")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("重新沖煮", systemImage: "arrow.counterclockwise") { reset() }
        }.buttonStyle(.borderedProminent).tint(.brown).controlSize(.large)
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("五段注水時間表").font(.headline)
            ForEach(0..<5) { i in
                HStack {
                    Image(systemName: water >= Double((i + 1) * 60) ? "checkmark.circle.fill" : "circle")
                    Text("\(clock(Double(starts[i]))) · 第 \(i + 1) 段")
                    Spacer()
                    Text("+60 → \((i + 1) * 60) g")
                }.font(.subheadline).foregroundStyle(started && pour == i ? Color.brown : Color.secondary)
            }
            Text("03:30 · 目標完成；若操作較慢，會繼續計時直到補足水量。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding().background(Color.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func tick(_ date: Date) {
        let dt = max(0, date.timeIntervalSince(lastTick))
        lastTick = date
        guard running, !finished else { return }
        elapsed += dt
        if active {
            // 自動圈速每四秒一圈；水量依真實經過時間增加，不依手勢事件次數。
            if automatic {
                angle += dt * .pi / 2
                point = CGPoint(x: cos(angle) * 58, y: sin(angle) * 58)
                turns += dt / 4
            }
            water = min(target, water + dt * 6)
            if water >= target {
                pouring = false; dragging = false; lastAngle = nil
                message = pour == 4 ? "300 g 注水完成，等待最後落水。" : "本段達標，停止注水並等待下一段時間。"
            }
        }
        if elapsed >= 210 && water >= 300 {
            finished = true; running = false; pouring = false
            message = "沖煮完成！20 g 咖啡粉、300 g 水，用時 \(clock(elapsed))。"
        }
    }

    private func reset() {
        coffee = 0; water = 0; elapsed = 0; pour = 0
        running = false; started = false; finished = false; pouring = false
        dragging = false; point = .zero; angle = 0; turns = 0; lastAngle = nil
        lastTick = Date(); message = "先加入 20 g 粗研磨咖啡粉。"
    }
}

#Preview { ContentView() }
