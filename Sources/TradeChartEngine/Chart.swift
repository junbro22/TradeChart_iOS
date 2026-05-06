import Foundation
import TradeChartEngineC

// MARK: - 공개 타입

public struct Candle: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public init(timestamp: TimeInterval, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    fileprivate var c: TceCandle {
        TceCandle(timestamp: timestamp, open: open, high: high, low: low, close: close, volume: volume)
    }
}

public enum SeriesType: Int32, Sendable {
    case candle      = 0
    case line        = 1
    case area        = 2
    case ohlcBar     = 3
    case heikinAshi  = 4
    case renko       = 5
}

public enum PriceAxisMode: Int32, Sendable {
    case linear  = 0
    case log     = 1
    case percent = 2
}

public enum ColorScheme: Int32, Sendable {
    case korea = 0   // 양봉 빨강 / 음봉 파랑
    case us    = 1   // 양봉 초록 / 음봉 빨강
}

public enum IndicatorKind: Int32, Sendable {
    // Overlay
    case sma        = 0
    case ema        = 1
    case bollinger  = 2
    case ichimoku   = 3
    case psar       = 4
    case supertrend = 5
    case vwap       = 6
    case pivotStandard  = 7
    case pivotFibonacci = 8
    case pivotCamarilla = 9
    case donchian       = 10
    case keltner        = 11
    case zigzag         = 12
    case volumeProfile  = 13
    // Subpanel
    case rsi        = 100
    case macd       = 101
    case stochastic = 102
    case atr        = 103
    case dmiAdx     = 104
    case cci        = 105
    case williamsR  = 106
    case obv        = 107
    case mfi        = 108
}

public struct ChartColor: Sendable {
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float
    public init(r: Float, g: Float, b: Float, a: Float = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    fileprivate var c: TceColor { TceColor(r: r, g: g, b: b, a: a) }
}

public struct ChartVertex: Sendable {
    public let x: Float
    public let y: Float
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float
}

public enum Primitive: Int32, Sendable {
    case triangles = 0
    case lines     = 1
}

public enum DrawingKind: Int32, Sendable {
    case trendline       = 0
    case horizontal      = 1
    case vertical        = 2
    case fibRetracement  = 3
    case measure         = 4
    case rectangle       = 5
    case fibExtension    = 6
}

public struct Mesh {
    public let vertices: [ChartVertex]
    public let indices: [UInt32]
    public let primitive: Primitive
}

// MARK: - Labels

public enum LabelKind: Int32, Sendable {
    case priceAxis        = 0
    case timeAxis         = 1
    case lastPrice        = 2
    case crosshairPrice   = 3
    case crosshairTime    = 4
}

public enum TextAnchor: Int32, Sendable {
    case leftCenter   = 0
    case rightCenter  = 1
    case centerTop    = 2
    case centerBottom = 3
    case centerCenter = 4
}

public struct ChartLabel: Sendable {
    public let text: String
    public let x: CGFloat
    public let y: CGFloat
    public let anchor: TextAnchor
    public let kind: LabelKind
    public let color: ChartColor
    public let background: ChartColor   // alpha 0이면 배경 없음
}

// MARK: - Layout (TceLayout 미러)

public struct ChartRect: Sendable, Equatable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
}

public struct ChartLayout: Sendable {
    public let plot: ChartRect
    public let priceAxis: ChartRect
    public let timeAxis: ChartRect
    public let volumePanel: ChartRect
    public let subpanels: [ChartRect]
}

// MARK: - Chart

/// TradeChartEngine의 Swift 래퍼.
///
/// **스레드 안전성**: 한 인스턴스의 모든 메서드는 main thread에서만 호출해야 한다.
/// 엔진은 단일-스레드 진입을 가정한다. 호스트가 백그라운드에서 데이터를 받아
/// 차트에 push할 때는 `DispatchQueue.main.async` 또는 `await MainActor.run { ... }`로 감싸야 한다.
public final class Chart {
    private let ctx: OpaquePointer

    /// 엔진 컨텍스트 생성. 메모리 부족 시 nil.
    public init?() {
        guard let p = tce_create() else { return nil }
        self.ctx = p
    }

    deinit {
        // 콜백 raw 포인터가 self였으므로 destroy 전에 해제 (방어적).
        tce_set_alert_callback(ctx, nil, nil)
        tce_destroy(ctx)
    }

    public static var version: String {
        String(cString: tce_version())
    }

    /// 마지막 buildFrame 기준의 패널 레이아웃 (px 좌표).
    /// buildFrame 호출 전에는 모든 사각형이 0인 layout 반환.
    public func layout() -> ChartLayout {
        let l = tce_layout(ctx)
        let toRect: (TceRect) -> ChartRect = {
            ChartRect(x: CGFloat($0.x), y: CGFloat($0.y),
                      width: CGFloat($0.width), height: CGFloat($0.height))
        }
        var subs: [ChartRect] = []
        let n = Int(l.subpanelCount)
        if n > 0 {
            withUnsafeBytes(of: l.subpanels) { raw in
                let buf = raw.bindMemory(to: TceRect.self)
                for i in 0..<min(n, buf.count) {
                    subs.append(toRect(buf[i]))
                }
            }
        }
        return ChartLayout(
            plot: toRect(l.plot),
            priceAxis: toRect(l.priceAxis),
            timeAxis: toRect(l.timeAxis),
            volumePanel: toRect(l.volumePanel),
            subpanels: subs
        )
    }

    /// index 위치의 캔들. 범위 밖이면 nil.
    public func candle(at index: Int) -> Candle? {
        var c = TceCandle()
        guard index >= 0,
              tce_get_candle(ctx, index, &c) == 1 else { return nil }
        return Candle(timestamp: c.timestamp, open: c.open, high: c.high,
                      low: c.low, close: c.close, volume: c.volume)
    }

    public func resetViewport() { tce_reset_viewport(ctx) }
    public func fitAll()        { tce_fit_all(ctx) }

    // MARK: 좌표 변환 (커스텀 overlay/annotation용 — buildFrame 후에만 의미)

    /// 화면 X(px) → 캔들 인덱스. plot 영역 밖이면 nil.
    public func indexAt(screenX: CGFloat) -> Int? {
        let i = tce_screen_x_to_index(ctx, Float(screenX))
        return i >= 0 ? Int(i) : nil
    }

    /// 캔들 인덱스 → 화면 X(px) 중심. 가시 viewport 밖이면 nil.
    public func screenX(forIndex index: Int) -> CGFloat? {
        var x: Float = 0
        guard tce_index_to_screen_x(ctx, Int32(index), &x) == 1 else { return nil }
        return CGFloat(x)
    }

    /// 화면 Y(px) → raw price. PRICE_LOG/PERCENT 자동 역변환.
    public func price(atScreenY y: CGFloat) -> Double {
        tce_screen_y_to_price(ctx, Float(y))
    }

    /// raw price → 화면 Y(px). PRICE_LOG/PERCENT 자동 변환.
    public func screenY(forPrice price: Double) -> CGFloat {
        CGFloat(tce_price_to_screen_y(ctx, price))
    }

    // MARK: 지표 값 query (crosshair hover 라벨용)
    //
    // 정책: 등록된 (kind, period) spec이 정확히 매치되어야 값을 반환. 미등록/index 범위 밖/
    //       첫 (period-1)개 → nil. period가 없는 지표(VWAP/OBV/Pivot)는 0 입력.

    public func queryIndicator(_ kind: IndicatorKind, period: Int, at index: Int) -> Double? {
        var v: Double = 0
        guard tce_query_indicator_value(ctx, TceIndicatorKind(rawValue: UInt32(kind.rawValue)),
                                        Int32(period), index, &v) == 1 else { return nil }
        return v
    }

    public struct BandValue: Sendable {
        public let upper: Double
        public let middle: Double
        public let lower: Double
    }

    public func queryBollinger(period: Int, at index: Int) -> BandValue? {
        var u: Double = 0, m: Double = 0, l: Double = 0
        guard tce_query_bollinger(ctx, Int32(period), index, &u, &m, &l) == 1 else { return nil }
        return BandValue(upper: u, middle: m, lower: l)
    }

    public func queryDonchian(period: Int, at index: Int) -> BandValue? {
        var u: Double = 0, m: Double = 0, l: Double = 0
        guard tce_query_donchian(ctx, Int32(period), index, &u, &m, &l) == 1 else { return nil }
        return BandValue(upper: u, middle: m, lower: l)
    }

    public func queryKeltner(emaPeriod: Int, at index: Int) -> BandValue? {
        var u: Double = 0, m: Double = 0, l: Double = 0
        guard tce_query_keltner(ctx, Int32(emaPeriod), index, &u, &m, &l) == 1 else { return nil }
        return BandValue(upper: u, middle: m, lower: l)
    }

    public struct MACDValue: Sendable {
        public let line: Double
        public let signal: Double
        public let histogram: Double
    }

    public func queryMACD(at index: Int) -> MACDValue? {
        var l: Double = 0, s: Double = 0, h: Double = 0
        guard tce_query_macd(ctx, index, &l, &s, &h) == 1 else { return nil }
        return MACDValue(line: l, signal: s, histogram: h)
    }

    public struct StochasticValue: Sendable {
        public let k: Double
        public let d: Double
    }

    public func queryStochastic(at index: Int) -> StochasticValue? {
        var k: Double = 0, d: Double = 0
        guard tce_query_stochastic(ctx, index, &k, &d) == 1 else { return nil }
        return StochasticValue(k: k, d: d)
    }

    public struct DMIValue: Sendable {
        public let plusDI: Double
        public let minusDI: Double
        public let adx: Double
    }

    public func queryDMI(period: Int, at index: Int) -> DMIValue? {
        var p: Double = 0, m: Double = 0, a: Double = 0
        guard tce_query_dmi(ctx, Int32(period), index, &p, &m, &a) == 1 else { return nil }
        return DMIValue(plusDI: p, minusDI: m, adx: a)
    }

    public struct PivotValue: Sendable {
        public let p: Double
        public let r1: Double; public let r2: Double; public let r3: Double
        public let s1: Double; public let s2: Double; public let s3: Double
    }

    public func queryPivot(_ kind: IndicatorKind, at index: Int) -> PivotValue? {
        var p: Double = 0
        var r1: Double = 0, r2: Double = 0, r3: Double = 0
        var s1: Double = 0, s2: Double = 0, s3: Double = 0
        guard tce_query_pivot(ctx, TceIndicatorKind(rawValue: UInt32(kind.rawValue)), index,
                              &p, &r1, &r2, &r3, &s1, &s2, &s3) == 1 else { return nil }
        return PivotValue(p: p, r1: r1, r2: r2, r3: r3, s1: s1, s2: s2, s3: s3)
    }

    public struct IchimokuValue: Sendable {
        public let tenkan: Double
        public let kijun: Double
        public let senkouA: Double
        public let senkouB: Double
        public let chikou: Double
    }

    public func queryIchimoku(at index: Int) -> IchimokuValue? {
        var t: Double = 0, k: Double = 0, sA: Double = 0, sB: Double = 0, ch: Double = 0
        guard tce_query_ichimoku(ctx, index, &t, &k, &sA, &sB, &ch) == 1 else { return nil }
        return IchimokuValue(tenkan: t, kijun: k, senkouA: sA, senkouB: sB, chikou: ch)
    }

    public struct SuperTrendValue: Sendable {
        public let line: Double
        public let direction: Int
    }

    public func querySuperTrend(at index: Int) -> SuperTrendValue? {
        var l: Double = 0
        var d: Int32 = 0
        guard tce_query_supertrend(ctx, index, &l, &d) == 1 else { return nil }
        return SuperTrendValue(line: l, direction: Int(d))
    }

    public func queryVWAPBands(at index: Int) -> BandValue? {
        var m: Double = 0, u: Double = 0, l: Double = 0
        guard tce_query_vwap_bands(ctx, index, &m, &u, &l) == 1 else { return nil }
        return BandValue(upper: u, middle: m, lower: l)
    }

    // MARK: 드로잉 직렬화

    /// 영속 저장용. 도메인 좌표(timestamp/price) 기반이라 차트 series가 달라도 안전.
    public struct DrawingExport: Codable, Sendable {
        public var kind: Int32          // DrawingKind raw
        public var r: Float; public var g: Float; public var b: Float; public var a: Float
        public var pointCount: Int      // 1 or 2
        public var ts: [Double]         // size pointCount
        public var price: [Double]
    }

    public func exportDrawings() -> [DrawingExport] {
        let n = tce_drawing_count(ctx)
        var out: [DrawingExport] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            var raw = TceDrawingExport()
            guard tce_drawing_export(ctx, i, &raw) == 1 else { continue }
            let pc = Int(raw.point_count)
            let tsArr: [Double] = withUnsafeBytes(of: raw.ts) { buf in
                let p = buf.bindMemory(to: Double.self)
                return Array(p[0..<min(pc, p.count)])
            }
            let pxArr: [Double] = withUnsafeBytes(of: raw.price) { buf in
                let p = buf.bindMemory(to: Double.self)
                return Array(p[0..<min(pc, p.count)])
            }
            out.append(DrawingExport(
                kind: Int32(raw.kind.rawValue),
                r: raw.color.r, g: raw.color.g, b: raw.color.b, a: raw.color.a,
                pointCount: pc, ts: tsArr, price: pxArr
            ))
        }
        return out
    }

    /// import — 새 id 부여 후 반환 배열. invalid 항목(kind 범위 밖/point_count 불일치
    /// /배열 길이 부족)은 silent skip. 외부 JSON 등 신뢰할 수 없는 데이터에도 안전.
    @discardableResult
    public func importDrawings(_ drawings: [DrawingExport]) -> [Int] {
        var ids: [Int] = []
        for d in drawings {
            // 외부 입력 가드 — fatal error 방지
            guard (0...5).contains(d.kind),
                  (1...2).contains(d.pointCount),
                  d.ts.count >= d.pointCount,
                  d.price.count >= d.pointCount else { continue }

            var raw = TceDrawingExport()
            raw.kind = TceDrawingKind(rawValue: UInt32(d.kind))
            raw.color = TceColor(r: d.r, g: d.g, b: d.b, a: d.a)
            raw.point_count = Int32(d.pointCount)
            for i in 0..<d.pointCount {
                withUnsafeMutableBytes(of: &raw.ts) {
                    $0.bindMemory(to: Double.self)[i] = d.ts[i]
                }
                withUnsafeMutableBytes(of: &raw.price) {
                    $0.bindMemory(to: Double.self)[i] = d.price[i]
                }
            }
            let id = tce_drawing_import(ctx, &raw)
            if id > 0 { ids.append(Int(id)) }
        }
        return ids
    }

    // MARK: 알림 cross 콜백

    /// Chart 인스턴스 단위 — deinit 시 자동 해제.
    private var alertCallback: ((Int, Double) -> Void)?

    /// 알림선 cross 시 호출 — append/updateLast 시 prev_close ↔ new_close 사이의
    /// alert.price를 가로지르면 한 번 호출. `cb=nil`로 해제.
    /// @note 콜백은 main thread(append/updateLast 호출 스레드)에서 동기 호출.
    public func setAlertCallback(_ cb: ((_ alertId: Int, _ price: Double) -> Void)?) {
        alertCallback = cb
        if cb != nil {
            let userPtr = Unmanaged.passUnretained(self).toOpaque()
            tce_set_alert_callback(ctx, { id, price, user in
                guard let user else { return }
                let chart = Unmanaged<Chart>.fromOpaque(user).takeUnretainedValue()
                chart.alertCallback?(Int(id), price)
            }, userPtr)
        } else {
            tce_set_alert_callback(ctx, nil, nil)
        }
    }

    // MARK: 데이터

    public func setHistory(_ candles: [Candle]) {
        let raw = candles.map(\.c)
        raw.withUnsafeBufferPointer {
            tce_set_history(ctx, $0.baseAddress, $0.count)
        }
    }

    public func appendCandle(_ candle: Candle) {
        var c = candle.c
        tce_append_candle(ctx, &c)
    }

    public func updateLast(close: Double, volume: Double) {
        tce_update_last(ctx, close, volume)
    }

    public var candleCount: Int {
        tce_candle_count(ctx)
    }

    // MARK: 설정

    public func setSize(width: CGFloat, height: CGFloat) {
        tce_set_size(ctx, Float(width), Float(height))
    }

    public func setSeriesType(_ type: SeriesType) {
        tce_set_series_type(ctx, TceSeriesType(rawValue: UInt32(type.rawValue)))
    }

    public func setColorScheme(_ scheme: ColorScheme) {
        tce_set_color_scheme(ctx, TceColorScheme(rawValue: UInt32(scheme.rawValue)))
    }

    public func setVolumePanelVisible(_ visible: Bool) {
        tce_set_volume_panel_visible(ctx, visible ? 1 : 0)
    }

    public func setPriceAxisMode(_ mode: PriceAxisMode) {
        tce_set_price_axis_mode(ctx, TcePriceAxisMode(rawValue: UInt32(mode.rawValue)))
    }

    public func setRenkoBrickSize(_ size: Double) {
        tce_set_renko_brick_size(ctx, size)
    }

    public func setShowGrid(_ show: Bool) {
        tce_set_show_grid(ctx, show ? 1 : 0)
    }

    /// 거래소 세션 시작(UTC 기준) — VWAP/Pivot 일별 boundary 보정.
    /// 예: NYSE = (14, 30), EU CET = (8, 0), KR/JP = (0, 0)(default).
    public func setSessionStartUTC(hour: Int, minute: Int = 0) {
        tce_set_session_start_utc(ctx, Int32(hour), Int32(minute))
    }

    /// 직접 offset(초) 지정 — `setSessionStartUTC`와 둘 중 하나만 쓰면 됨.
    public func setSessionOffsetSeconds(_ seconds: Double) {
        tce_set_session_offset_seconds(ctx, seconds)
    }

    // MARK: 지표

    public func addIndicator(_ kind: IndicatorKind, period: Int, color: ChartColor) {
        tce_add_indicator(
            ctx,
            TceIndicatorKind(rawValue: UInt32(kind.rawValue)),
            Int32(period),
            color.c
        )
    }

    public func removeIndicator(_ kind: IndicatorKind, period: Int) {
        tce_remove_indicator(
            ctx,
            TceIndicatorKind(rawValue: UInt32(kind.rawValue)),
            Int32(period)
        )
    }

    public func clearIndicators() {
        tce_clear_indicators(ctx)
    }

    public func addBollinger(period: Int = 20, stddev: Double = 2.0, color: ChartColor) {
        tce_add_bollinger(ctx, Int32(period), stddev, color.c)
    }

    public func addDonchian(period: Int = 20, color: ChartColor, edgeColor: ChartColor) {
        tce_add_donchian(ctx, Int32(period), color.c, edgeColor.c)
    }

    public func addKeltner(emaPeriod: Int = 20, atrPeriod: Int = 10, multiplier: Double = 2.0,
                           color: ChartColor, edgeColor: ChartColor) {
        tce_add_keltner(ctx, Int32(emaPeriod), Int32(atrPeriod), multiplier,
                        color.c, edgeColor.c)
    }

    public func addRSI(period: Int = 14, color: ChartColor) {
        tce_add_rsi(ctx, Int32(period), color.c)
    }

    public func addMACD(fast: Int = 12, slow: Int = 26, signal: Int = 9,
                        lineColor: ChartColor, signalColor: ChartColor, histColor: ChartColor) {
        tce_add_macd(ctx, Int32(fast), Int32(slow), Int32(signal),
                     lineColor.c, signalColor.c, histColor.c)
    }

    public func addStochastic(kPeriod: Int = 14, dPeriod: Int = 3, smooth: Int = 3,
                              kColor: ChartColor, dColor: ChartColor) {
        tce_add_stochastic(ctx, Int32(kPeriod), Int32(dPeriod), Int32(smooth),
                           kColor.c, dColor.c)
    }

    public func addATR(period: Int = 14, color: ChartColor) {
        tce_add_atr(ctx, Int32(period), color.c)
    }

    public func addIchimoku(tenkan: Int = 9, kijun: Int = 26,
                            senkouB: Int = 52, displacement: Int = 26,
                            tenkanColor: ChartColor, kijunColor: ChartColor) {
        tce_add_ichimoku(ctx, Int32(tenkan), Int32(kijun), Int32(senkouB), Int32(displacement),
                         tenkanColor.c, kijunColor.c)
    }

    public func addPSAR(step: Double = 0.02, max: Double = 0.2, color: ChartColor) {
        tce_add_psar(ctx, step, max, color.c)
    }

    public func addSuperTrend(period: Int = 10, multiplier: Double = 3.0, color: ChartColor) {
        tce_add_supertrend(ctx, Int32(period), multiplier, color.c)
    }

    public func addVWAP(color: ChartColor) {
        tce_add_vwap(ctx, color.c)
    }

    /// VWAP + ±numStdev × sigma 밴드. numStdev<=0이면 plain VWAP과 동일.
    public func addVWAPWithBands(numStdev: Double = 2.0,
                                 color: ChartColor, bandColor: ChartColor) {
        tce_add_vwap_with_bands(ctx, numStdev, color.c, bandColor.c)
    }

    /// ZigZag — deviationPct(%) 이상 swing high/low 직선. **repaint 주의**: 마지막 swing은 잠정값.
    public func addZigZag(deviationPct: Double = 5.0, color: ChartColor) {
        tce_add_zigzag(ctx, deviationPct, color.c)
    }

    /// Volume Profile — plot 우측 widthRatio 영역에 가격 bin별 거래량 막대 + POC/VAH/VAL 가로선.
    /// alpha는 엔진이 0.30 강제. Renko 모드에서는 no-op.
    public func addVolumeProfile(bins: Int = 24, widthRatio: Double = 0.20,
                                 barColor: ChartColor, pocColor: ChartColor) {
        tce_add_volume_profile(ctx, Int32(bins), widthRatio, barColor.c, pocColor.c)
    }

    public func addDMI(period: Int = 14,
                       plusDIColor: ChartColor, minusDIColor: ChartColor, adxColor: ChartColor) {
        tce_add_dmi(ctx, Int32(period), plusDIColor.c, minusDIColor.c, adxColor.c)
    }

    public func addCCI(period: Int = 20, color: ChartColor) {
        tce_add_cci(ctx, Int32(period), color.c)
    }

    public func addWilliamsR(period: Int = 14, color: ChartColor) {
        tce_add_williams_r(ctx, Int32(period), color.c)
    }

    public func addOBV(color: ChartColor) {
        tce_add_obv(ctx, color.c)
    }

    public func addMFI(period: Int = 14, color: ChartColor) {
        tce_add_mfi(ctx, Int32(period), color.c)
    }

    public func addPivotStandard(pColor: ChartColor, rsColor: ChartColor) {
        tce_add_pivot_standard(ctx, pColor.c, rsColor.c)
    }
    public func addPivotFibonacci(pColor: ChartColor, rsColor: ChartColor) {
        tce_add_pivot_fibonacci(ctx, pColor.c, rsColor.c)
    }
    public func addPivotCamarilla(pColor: ChartColor, rsColor: ChartColor) {
        tce_add_pivot_camarilla(ctx, pColor.c, rsColor.c)
    }

    // MARK: 드로잉

    @discardableResult
    public func beginDrawing(_ kind: DrawingKind,
                             atScreenX x: CGFloat, atScreenY y: CGFloat,
                             color: ChartColor) -> Int {
        let id = tce_drawing_begin(
            ctx,
            TceDrawingKind(rawValue: UInt32(kind.rawValue)),
            Float(x), Float(y), color.c
        )
        return Int(id)
    }

    public func updateDrawing(id: Int, pointIndex: Int,
                              screenX x: CGFloat, screenY y: CGFloat) {
        tce_drawing_update(ctx, Int32(id), Int32(pointIndex), Float(x), Float(y))
    }

    public func removeDrawing(id: Int) {
        tce_drawing_remove(ctx, Int32(id))
    }

    public func clearDrawings() {
        tce_drawing_clear(ctx)
    }

    public func hitTestDrawing(at point: CGPoint) -> Int {
        Int(tce_drawing_hit_test(ctx, Float(point.x), Float(point.y)))
    }

    public func translateDrawing(id: Int, dxPx: CGFloat, dyPx: CGFloat) {
        tce_drawing_translate(ctx, Int32(id), Float(dxPx), Float(dyPx))
    }

    // MARK: 매수/매도 마커

    @discardableResult
    public func addTradeMarker(timestamp: TimeInterval, price: Double,
                               isBuy: Bool, quantity: Double = 0) -> Int {
        Int(tce_add_trade_marker(ctx, timestamp, price, isBuy ? 1 : 0, quantity))
    }
    public func removeTradeMarker(id: Int) { tce_remove_trade_marker(ctx, Int32(id)) }
    public func clearTradeMarkers()         { tce_clear_trade_markers(ctx) }

    // MARK: 가격 알림선

    @discardableResult
    public func addAlertLine(price: Double, color: ChartColor) -> Int {
        Int(tce_add_alert_line(ctx, price, color.c))
    }
    public func updateAlertLine(id: Int, screenY: CGFloat) {
        tce_update_alert_line_by_screen(ctx, Int32(id), Float(screenY))
    }
    public func removeAlertLine(id: Int) { tce_remove_alert_line(ctx, Int32(id)) }
    public func clearAlertLines()         { tce_clear_alert_lines(ctx) }
    public func hitTestAlertLine(screenY: CGFloat) -> Int {
        Int(tce_hit_test_alert_line(ctx, Float(screenY)))
    }

    // MARK: 뷰포트

    public var visibleCount: Int {
        get { Int(tce_visible_count(ctx)) }
        set { tce_set_visible_count(ctx, Int32(newValue)) }
    }

    public var rightOffset: Int {
        get { Int(tce_right_offset(ctx)) }
        set { tce_set_right_offset(ctx, Int32(newValue)) }
    }

    @available(*, deprecated, message: "use applyPan(dxPx:) instead")
    public func pan(deltaPixels: CGFloat) {
        tce_pan(ctx, Float(deltaPixels))
    }

    @available(*, deprecated, message: "use applyPinch(scale:anchorPx:) instead")
    public func zoom(factor: CGFloat, anchorX: CGFloat) {
        tce_zoom(ctx, Float(factor), Float(anchorX))
    }

    /// Wrapper는 raw 픽셀만 dispatch — 의미 해석은 엔진이.
    public func applyPinch(scale: CGFloat, anchorPx: CGFloat) {
        tce_apply_pinch(ctx, Float(scale), Float(anchorPx))
    }

    public func applyPan(dxPx: CGFloat) {
        tce_apply_pan(ctx, Float(dxPx))
    }

    // MARK: 크로스헤어

    public func setCrosshair(x: CGFloat, y: CGFloat) {
        tce_set_crosshair(ctx, Float(x), Float(y))
    }

    public func clearCrosshair() {
        tce_clear_crosshair(ctx)
    }

    public struct CrosshairInfo: Sendable {
        public let visible: Bool
        public let candleIndex: Int
        public let price: Double
        public let timestamp: TimeInterval
        public let screenX: Float
        public let screenY: Float
    }

    public var crosshair: CrosshairInfo {
        let info = tce_crosshair_info(ctx)
        return CrosshairInfo(
            visible: info.visible != 0,
            candleIndex: Int(info.candle_index),
            price: info.price,
            timestamp: info.timestamp,
            screenX: info.screen_x,
            screenY: info.screen_y
        )
    }

    // MARK: 렌더

    public var autoScroll: Bool {
        get { tce_auto_scroll(ctx) != 0 }
        set { tce_set_auto_scroll(ctx, newValue ? 1 : 0) }
    }

    /// buildFrame 직후 호출 — 같은 layout으로 라벨 좌표 계산.
    public func buildLabels() -> [ChartLabel] {
        let raw = tce_build_labels(ctx)
        var out: [ChartLabel] = []
        out.reserveCapacity(raw.count)
        for i in 0..<raw.count {
            let l = raw.items[i]
            let text = l.text.flatMap { String(cString: $0) } ?? ""
            out.append(ChartLabel(
                text: text,
                x: CGFloat(l.x),
                y: CGFloat(l.y),
                anchor: TextAnchor(rawValue: Int32(l.anchor.rawValue)) ?? .leftCenter,
                kind: LabelKind(rawValue: Int32(l.kind.rawValue)) ?? .priceAxis,
                color: ChartColor(r: l.color.r, g: l.color.g, b: l.color.b, a: l.color.a),
                background: ChartColor(r: l.background.r, g: l.background.g, b: l.background.b, a: l.background.a)
            ))
        }
        return out
    }

    /// 현재 상태로 한 프레임의 메시 묶음을 빌드.
    /// 반환된 Mesh는 Swift가 소유 (Vertex/Index는 복사됨).
    public func buildFrame() -> [Mesh] {
        let frame = tce_build_frame(ctx)
        var result: [Mesh] = []
        result.reserveCapacity(frame.mesh_count)
        for i in 0..<frame.mesh_count {
            let m = frame.meshes[i]
            var verts: [ChartVertex] = []
            verts.reserveCapacity(m.vertex_count)
            for vi in 0..<m.vertex_count {
                let v = m.vertices[vi]
                verts.append(ChartVertex(x: v.x, y: v.y, r: v.r, g: v.g, b: v.b, a: v.a))
            }
            var indices: [UInt32] = []
            indices.reserveCapacity(m.index_count)
            for ii in 0..<m.index_count {
                indices.append(m.indices[ii])
            }
            result.append(Mesh(
                vertices: verts,
                indices: indices,
                primitive: Primitive(rawValue: m.primitive) ?? .triangles
            ))
        }
        tce_release_frame(frame)
        return result
    }
}
