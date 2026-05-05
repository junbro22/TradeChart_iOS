import SwiftUI
import TradeChartEngine

struct ContentView: View {

    @State private var chart: Chart = {
        guard let c = Chart() else { fatalError("Chart engine init failed") }
        let candles = DemoData.generate(count: 200)
        c.setHistory(candles)
        c.visibleCount = 80
        c.setColorScheme(.korea)
        c.setSeriesType(.candle)
        c.setVolumePanelVisible(true)

        // 데모 — 매수/매도 마커
        if candles.count > 130 {
            c.addTradeMarker(timestamp: candles[50].timestamp,
                             price: candles[50].low, isBuy: true, quantity: 1500)
            c.addTradeMarker(timestamp: candles[130].timestamp,
                             price: candles[130].high, isBuy: false, quantity: 800)
        }
        return c
    }()

    @State private var showVolume     = true
    @State private var showSMA        = true
    @State private var showEMA        = true
    @State private var showRSI        = false
    @State private var showMACD       = false
    @State private var showBB         = false
    @State private var showStoch      = false
    @State private var showATR        = false
    @State private var showIchimoku   = false
    @State private var showPSAR       = false
    @State private var showSuperTrend = false
    @State private var showVWAP       = false
    @State private var showDMI        = false
    @State private var showCCI        = false
    @State private var showWilliamsR  = false
    @State private var showOBV        = false
    @State private var showMFI        = false
    @State private var pivotKind: PivotMode = .off
    @State private var seriesType: SeriesType = .candle
    @State private var priceMode: PriceAxisMode = .linear
    @State private var colorScheme: TradeChartEngine.ColorScheme = .korea
    @State private var showGrid: Bool = true
    @State private var drawingMode: DrawingKind? = nil
    @State private var liveOn: Bool = false
    @State private var renkoBrick: Double = 0.0
    @State private var alertLineId: Int = 0

    enum PivotMode: String, CaseIterable, Identifiable {
        case off = "Off", standard = "Std", fibonacci = "Fib", camarilla = "Cam"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TradeChartView(chart: chart, drawingMode: $drawingMode)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))
            controls
        }
        .ignoresSafeArea(edges: .bottom)
        .task { await applyDefaults() }
    }

    private func applyDefaults() async {
        if showSMA {
            chart.addIndicator(.sma, period: 20, color: ChartColor(r: 1.00, g: 0.85, b: 0.20))
        }
        if showEMA {
            chart.addIndicator(.ema, period: 60, color: ChartColor(r: 0.45, g: 0.80, b: 1.00))
        }
    }

    private var header: some View {
        HStack {
            Text("TradeChart Demo")
                .font(.headline)
            Spacer()
            Text("v\(Chart.version)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.10, blue: 0.13))
        .foregroundStyle(.white)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    seriesChip("캔들",   .candle)
                    seriesChip("라인",   .line)
                    seriesChip("Area",   .area)
                    seriesChip("OHLC",   .ohlcBar)
                    seriesChip("Heikin", .heikinAshi)
                    seriesChip("Renko",  .renko)
                }
            }

            HStack {
                Picker("축", selection: $priceMode) {
                    Text("Linear").tag(PriceAxisMode.linear)
                    Text("Log").tag(PriceAxisMode.log)
                    Text("%").tag(PriceAxisMode.percent)
                }
                .pickerStyle(.segmented)
                .onChange(of: priceMode) { v in chart.setPriceAxisMode(v) }

                Picker("색", selection: $colorScheme) {
                    Text("KR").tag(ColorScheme.korea)
                    Text("US").tag(ColorScheme.us)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .onChange(of: colorScheme) { v in chart.setColorScheme(v) }
            }

            HStack(spacing: 12) {
                Toggle("거래량", isOn: $showVolume)
                    .onChange(of: showVolume) { v in chart.setVolumePanelVisible(v) }
                Toggle("그리드", isOn: $showGrid)
                    .onChange(of: showGrid) { v in chart.setShowGrid(v) }
                Toggle("Live", isOn: $liveOn)
                    .onChange(of: liveOn) { v in v ? startLive() : stopLive() }
            }
            .toggleStyle(.switch)
            .font(.caption)

            // Renko brick size — Renko 모드일 때만
            if seriesType == .renko {
                HStack {
                    Text("brick").font(.caption)
                    Slider(value: $renkoBrick, in: 0...50, step: 0.5)
                        .onChange(of: renkoBrick) { v in chart.setRenkoBrickSize(v) }
                    Text(String(format: "%.1f", renkoBrick)).font(.caption.monospaced())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    indicatorChip("SMA20",  isOn: $showSMA) { on in
                        on ? chart.addIndicator(.sma, period: 20,
                                                color: ChartColor(r: 1.00, g: 0.85, b: 0.20))
                           : chart.removeIndicator(.sma, period: 20)
                    }
                    indicatorChip("EMA60",  isOn: $showEMA) { on in
                        on ? chart.addIndicator(.ema, period: 60,
                                                color: ChartColor(r: 0.45, g: 0.80, b: 1.00))
                           : chart.removeIndicator(.ema, period: 60)
                    }
                    indicatorChip("BB",    isOn: $showBB)    { on in
                        on ? chart.addBollinger(period: 20, stddev: 2.0,
                                                color: ChartColor(r: 0.55, g: 0.85, b: 1.0))
                           : chart.removeIndicator(.bollinger, period: 20)
                    }
                    indicatorChip("RSI",   isOn: $showRSI)   { on in
                        on ? chart.addRSI(period: 14, color: ChartColor(r: 0.95, g: 0.55, b: 0.95))
                           : chart.removeIndicator(.rsi, period: 14)
                    }
                    indicatorChip("MACD",  isOn: $showMACD)  { on in
                        on ? chart.addMACD(
                                fast: 12, slow: 26, signal: 9,
                                lineColor:   ChartColor(r: 0.30, g: 0.85, b: 1.00),
                                signalColor: ChartColor(r: 1.00, g: 0.65, b: 0.20),
                                histColor:   ChartColor(r: 0.50, g: 0.50, b: 0.50, a: 0.5)
                              )
                           : chart.removeIndicator(.macd, period: 12)
                    }
                    indicatorChip("Stoch", isOn: $showStoch) { on in
                        on ? chart.addStochastic(
                                kPeriod: 14, dPeriod: 3, smooth: 3,
                                kColor: ChartColor(r: 1.0, g: 0.85, b: 0.30),
                                dColor: ChartColor(r: 0.50, g: 0.80, b: 1.0)
                              )
                           : chart.removeIndicator(.stochastic, period: 14)
                    }
                    indicatorChip("ATR",   isOn: $showATR)   { on in
                        on ? chart.addATR(period: 14, color: ChartColor(r: 0.85, g: 0.85, b: 0.55))
                           : chart.removeIndicator(.atr, period: 14)
                    }
                    indicatorChip("Ichimoku", isOn: $showIchimoku) { on in
                        on ? chart.addIchimoku(
                                tenkanColor: ChartColor(r: 0.30, g: 0.85, b: 1.00),
                                kijunColor:  ChartColor(r: 1.00, g: 0.55, b: 0.30))
                           : chart.removeIndicator(.ichimoku, period: 9)
                    }
                    indicatorChip("PSAR",  isOn: $showPSAR) { on in
                        on ? chart.addPSAR(color: ChartColor(r: 1.00, g: 0.95, b: 0.30))
                           : chart.removeIndicator(.psar, period: 0)
                    }
                    indicatorChip("ST",    isOn: $showSuperTrend) { on in
                        on ? chart.addSuperTrend(color: ChartColor(r: 0.50, g: 1.00, b: 0.50))
                           : chart.removeIndicator(.supertrend, period: 10)
                    }
                    indicatorChip("VWAP",  isOn: $showVWAP) { on in
                        on ? chart.addVWAP(color: ChartColor(r: 0.95, g: 0.55, b: 0.95))
                           : chart.removeIndicator(.vwap, period: 0)
                    }
                    indicatorChip("DMI",   isOn: $showDMI) { on in
                        on ? chart.addDMI(period: 14,
                                          plusDIColor:  ChartColor(r: 0.30, g: 0.85, b: 0.45),
                                          minusDIColor: ChartColor(r: 0.95, g: 0.30, b: 0.30),
                                          adxColor:     ChartColor(r: 1.00, g: 0.85, b: 0.30))
                           : chart.removeIndicator(.dmiAdx, period: 14)
                    }
                    indicatorChip("CCI",   isOn: $showCCI) { on in
                        on ? chart.addCCI(period: 20, color: ChartColor(r: 0.50, g: 0.85, b: 1.00))
                           : chart.removeIndicator(.cci, period: 20)
                    }
                    indicatorChip("W%R",   isOn: $showWilliamsR) { on in
                        on ? chart.addWilliamsR(period: 14, color: ChartColor(r: 1.00, g: 0.55, b: 0.95))
                           : chart.removeIndicator(.williamsR, period: 14)
                    }
                    indicatorChip("OBV",   isOn: $showOBV) { on in
                        on ? chart.addOBV(color: ChartColor(r: 0.85, g: 0.85, b: 0.55))
                           : chart.removeIndicator(.obv, period: 0)
                    }
                    indicatorChip("MFI",   isOn: $showMFI) { on in
                        on ? chart.addMFI(period: 14, color: ChartColor(r: 0.45, g: 0.95, b: 0.85))
                           : chart.removeIndicator(.mfi, period: 14)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Pivot").font(.caption)
                Picker("Pivot", selection: $pivotKind) {
                    ForEach(PivotMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: pivotKind) { v in applyPivot(v) }

                Spacer()
                Button(action: toggleAlertLine) {
                    Text(alertLineId == 0 ? "+알림선" : "-알림선")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.10), in: Capsule())
                }

                Button("Reset") { chart.resetViewport() }
                    .font(.caption.monospaced())
            }

            HStack(spacing: 6) {
                drawingChip("✕",  active: drawingMode == nil)        { drawingMode = nil }
                drawingChip("―",  active: drawingMode == .horizontal){ drawingMode = .horizontal }
                drawingChip("│",  active: drawingMode == .vertical)  { drawingMode = .vertical }
                drawingChip("╱",  active: drawingMode == .trendline) { drawingMode = .trendline }
                drawingChip("▭",  active: drawingMode == .rectangle) { drawingMode = .rectangle }
                drawingChip("Fib", active: drawingMode == .fibRetracement) { drawingMode = .fibRetracement }
                drawingChip("Mes", active: drawingMode == .measure)   { drawingMode = .measure }
                Spacer()
                Button("Clear") { chart.clearDrawings() }
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.10, blue: 0.13))
        .foregroundStyle(.white)
    }

    // MARK: - Pivot toggle

    private func applyPivot(_ mode: PivotMode) {
        chart.removeIndicator(.pivotStandard, period: 0)
        chart.removeIndicator(.pivotFibonacci, period: 0)
        chart.removeIndicator(.pivotCamarilla, period: 0)
        let p  = ChartColor(r: 1.00, g: 0.85, b: 0.30)
        let rs = ChartColor(r: 0.85, g: 0.85, b: 0.85, a: 0.6)
        switch mode {
        case .off: break
        case .standard:  chart.addPivotStandard(pColor: p, rsColor: rs)
        case .fibonacci: chart.addPivotFibonacci(pColor: p, rsColor: rs)
        case .camarilla: chart.addPivotCamarilla(pColor: p, rsColor: rs)
        }
    }

    // MARK: - Alert line

    private func toggleAlertLine() {
        if alertLineId != 0 {
            chart.removeAlertLine(id: alertLineId)
            alertLineId = 0
            return
        }
        // 가시 범위 마지막 캔들 close 기준으로 알림선 한 개 추가
        let n = chart.candleCount
        guard n > 0, let last = chart.candle(at: n - 1) else { return }
        alertLineId = chart.addAlertLine(price: last.close,
                                          color: ChartColor(r: 1.0, g: 0.30, b: 0.45))
    }

    // MARK: - Live tick simulation

    @State private var liveTask: Task<Void, Never>? = nil

    private func startLive() {
        liveTask?.cancel()
        liveTask = Task { @MainActor in
            var prev = chart.candleCount > 0
                ? (chart.candle(at: chart.candleCount - 1)?.close ?? 100)
                : 100
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { break }
                let drift = Double.random(in: -1.5...1.5)
                prev = max(1.0, prev + drift)
                chart.updateLast(close: prev, volume: Double.random(in: 800...1800))
            }
        }
    }
    private func stopLive() {
        liveTask?.cancel(); liveTask = nil
    }

    // MARK: - Chips

    private func seriesChip(_ label: String, _ value: SeriesType) -> some View {
        let active = seriesType == value
        return Button {
            seriesType = value
            chart.setSeriesType(value)
        } label: {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color.yellow.opacity(0.85) : Color.white.opacity(0.10), in: Capsule())
        }
    }

    private func drawingChip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(active ? Color.cyan.opacity(0.85) : Color.white.opacity(0.10), in: Capsule())
        }
    }

    private func indicatorChip(_ label: String,
                               isOn: Binding<Bool>,
                               apply: @escaping (Bool) -> Void) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            apply(isOn.wrappedValue)
        } label: {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(isOn.wrappedValue ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isOn.wrappedValue ? Color.yellow.opacity(0.85) : Color.white.opacity(0.10),
                    in: Capsule()
                )
        }
    }
}
