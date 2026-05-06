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
    @State private var showDonchian: Bool = false
    @State private var showKeltner: Bool = false
    @State private var showZigZag: Bool = false
    @State private var showVWAPBands: Bool = false
    @State private var savedDrawings: [Chart.DrawingExport] = []
    @State private var alertToast: String? = nil
    @State private var alertToastTask: Task<Void, Never>? = nil
    @State private var crosshairInfo: Chart.CrosshairInfo? = nil

    enum PivotMode: String, CaseIterable, Identifiable {
        case off = "Off", standard = "Std", fibonacci = "Fib", camarilla = "Cam"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                TradeChartView(chart: chart, drawingMode: $drawingMode,
                               onCrosshairChange: { info in
                                   crosshairInfo = info.visible ? info : nil
                               })
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                if let msg = alertToast {
                    Text(msg)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.pink.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                if let info = crosshairInfo, let lines = indicatorReadout(at: info.candleIndex) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.caption2.monospacedDigit())
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .padding(.top, 8).padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            controls
        }
        .ignoresSafeArea(edges: .bottom)
        .task { await applyDefaults() }
    }

    /// 등록된 지표 중 hover 위치에서 값이 있는 것만 라인으로 모음.
    private func indicatorReadout(at index: Int) -> [String]? {
        guard index >= 0 else { return nil }
        var lines: [String] = []
        if showSMA, let v = chart.queryIndicator(.sma, period: 20, at: index) {
            lines.append(String(format: "SMA(20)  %.2f", v))
        }
        if showEMA, let v = chart.queryIndicator(.ema, period: 60, at: index) {
            lines.append(String(format: "EMA(60)  %.2f", v))
        }
        if showRSI, let v = chart.queryIndicator(.rsi, period: 14, at: index) {
            lines.append(String(format: "RSI(14)  %.2f", v))
        }
        if showATR, let v = chart.queryIndicator(.atr, period: 14, at: index) {
            lines.append(String(format: "ATR(14)  %.3f", v))
        }
        if showBB, let bb = chart.queryBollinger(period: 20, at: index) {
            lines.append(String(format: "BB U/M/L  %.1f / %.1f / %.1f", bb.upper, bb.middle, bb.lower))
        }
        if showDonchian, let dc = chart.queryDonchian(period: 20, at: index) {
            lines.append(String(format: "Donch U/L  %.1f / %.1f", dc.upper, dc.lower))
        }
        if showKeltner, let kl = chart.queryKeltner(emaPeriod: 20, at: index) {
            lines.append(String(format: "Keltn U/M/L  %.1f / %.1f / %.1f", kl.upper, kl.middle, kl.lower))
        }
        if showMACD, let m = chart.queryMACD(at: index) {
            lines.append(String(format: "MACD  %.3f  sig %.3f", m.line, m.signal))
        }
        if showStoch, let s = chart.queryStochastic(at: index) {
            lines.append(String(format: "Stoch K/D  %.1f / %.1f", s.k, s.d))
        }
        return lines.isEmpty ? nil : lines
    }

    private func applyDefaults() async {
        if showSMA {
            chart.addIndicator(.sma, period: 20, color: ChartColor(r: 1.00, g: 0.85, b: 0.20))
        }
        if showEMA {
            chart.addIndicator(.ema, period: 60, color: ChartColor(r: 0.45, g: 0.80, b: 1.00))
        }
        // 알림선 cross 시 토스트 표시
        chart.setAlertCallback { _, price in
            alertToast = String(format: "알림 ⚡ %.2f 도달", price)
            alertToastTask?.cancel()
            alertToastTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled { alertToast = nil }
            }
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

            // Renko brick size — Renko 모드일 때만. 가격의 0.1%~3% 사이를 슬라이더로.
            if seriesType == .renko {
                let lastPrice = chart.candle(at: max(0, chart.candleCount - 1))?.close ?? 100
                let lo = lastPrice * 0.001
                let hi = lastPrice * 0.03
                HStack {
                    Text("brick").font(.caption)
                    Slider(value: $renkoBrick, in: lo...hi, step: max(0.1, lo))
                        .onChange(of: renkoBrick) { v in chart.setRenkoBrickSize(v) }
                    Text(String(format: "%.2f", renkoBrick)).font(.caption.monospaced())
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
                    indicatorChip("Donch", isOn: $showDonchian) { on in
                        on ? chart.addDonchian(period: 20,
                                               color:     ChartColor(r: 1.00, g: 0.55, b: 0.85),
                                               edgeColor: ChartColor(r: 1.00, g: 0.55, b: 0.85, a: 0.5))
                           : chart.removeIndicator(.donchian, period: 20)
                    }
                    indicatorChip("Keltn", isOn: $showKeltner) { on in
                        on ? chart.addKeltner(emaPeriod: 20, atrPeriod: 10, multiplier: 2.0,
                                              color:     ChartColor(r: 0.55, g: 1.00, b: 0.65),
                                              edgeColor: ChartColor(r: 0.55, g: 1.00, b: 0.65, a: 0.5))
                           : chart.removeIndicator(.keltner, period: 20)
                    }
                    indicatorChip("ZigZag", isOn: $showZigZag) { on in
                        on ? chart.addZigZag(deviationPct: 5.0,
                                             color: ChartColor(r: 1.00, g: 0.85, b: 0.20))
                           : chart.removeIndicator(.zigzag, period: 0)
                    }
                    indicatorChip("VWAP±2σ", isOn: $showVWAPBands) { on in
                        if on {
                            chart.addVWAPWithBands(numStdev: 2.0,
                                color:     ChartColor(r: 0.95, g: 0.55, b: 0.95),
                                bandColor: ChartColor(r: 0.95, g: 0.55, b: 0.95, a: 0.5))
                        } else if showVWAP {
                            // ±σ만 끄고 plain은 유지 — spec을 plain 형태로 갱신
                            chart.addVWAP(color: ChartColor(r: 0.95, g: 0.55, b: 0.95))
                        } else {
                            chart.removeIndicator(.vwap, period: 0)
                        }
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
                        // VWAP과 VWAP±σ는 같은 spec(kind=VWAP, period=0)을 공유한다.
                        // 사용자가 plain만 원하는 경우 ±σ가 켜져 있으면 그걸 우선 — band-only 등록 유지.
                        if on {
                            if showVWAPBands {
                                chart.addVWAPWithBands(numStdev: 2.0,
                                    color:     ChartColor(r: 0.95, g: 0.55, b: 0.95),
                                    bandColor: ChartColor(r: 0.95, g: 0.55, b: 0.95, a: 0.5))
                            } else {
                                chart.addVWAP(color: ChartColor(r: 0.95, g: 0.55, b: 0.95))
                            }
                        } else if !showVWAPBands {
                            chart.removeIndicator(.vwap, period: 0)
                        }
                        // showVWAPBands가 켜져있는데 plain 끄기는 spec 유지 (bands 형태로 잔존)
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
                Button("Save") { savedDrawings = chart.exportDrawings() }
                    .font(.caption.monospaced())
                    .foregroundStyle(.cyan)
                Button("Load") {
                    chart.clearDrawings()
                    chart.importDrawings(savedDrawings)
                }
                .font(.caption.monospaced())
                .foregroundStyle(.cyan)
                .disabled(savedDrawings.isEmpty)
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
            var ticksOnCurrent = 0
            // 0.4초마다 tick — 12회당(약 5초) 새 분봉 생성 시뮬.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { break }
                let n = chart.candleCount
                guard n > 0, let last = chart.candle(at: n - 1) else { continue }
                let driftPct = Double.random(in: -0.002...0.002) // ±0.2%
                let nextClose = max(1.0, last.close * (1.0 + driftPct))
                if ticksOnCurrent < 12 {
                    chart.updateLast(close: nextClose,
                                     volume: last.volume + Double.random(in: 50...300))
                    ticksOnCurrent += 1
                } else {
                    // 새 분봉 생성 — 한국 분봉 단위(60초) 가정.
                    let nextTs = last.timestamp + 60.0
                    let newCandle = Candle(timestamp: nextTs,
                                           open: last.close,
                                           high: max(last.close, nextClose),
                                           low:  min(last.close, nextClose),
                                           close: nextClose,
                                           volume: Double.random(in: 800...1500))
                    chart.appendCandle(newCandle)
                    ticksOnCurrent = 0
                }
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
            // Renko 진입 시 brick 자동값(가격 0.5%) 한 번 셋팅
            if value == .renko, renkoBrick == 0 {
                let last = chart.candle(at: max(0, chart.candleCount - 1))?.close ?? 100
                renkoBrick = last * 0.005
                chart.setRenkoBrickSize(renkoBrick)
            }
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
