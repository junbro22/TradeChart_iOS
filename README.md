# TradeChart_iOS

[TradeChartEngine](https://github.com/junbro22/TradeChartEngine) (C++ 코어)을
iOS에서 SwiftUI로 사용하기 위한 wrapper + 샘플 앱.

## 구성

```
TradeChart_iOS/
├── Package.swift                   # SPM — TradeChartEngine 의존
├── Sources/TradeChart/             # Swift wrapper (Chart / TradeChartView / Renderer)
└── Examples/ios-demo/              # Tuist 샘플 앱
```

엔진(xcframework)은 TradeChartEngine repo에서 SPM binary target(`TradeChartEngineC`)으로 가져옴 →
이 패키지가 그 위에 Swift/SwiftUI/Metal/제스처를 붙여 `TradeChart` product로 노출.

## 사용 (호스트 앱)

```swift
.package(url: "https://github.com/junbro22/TradeChart_iOS.git", branch: "main")
// dependency: .product(name: "TradeChart", package: "TradeChart_iOS")
```

```swift
import TradeChart

guard let chart = Chart() else {
    // tce_create 실패 — 거의 발생하지 않지만(메모리 부족) 호스트 앱은 옵셔널 처리.
    return
}
chart.setHistory(candles)
chart.addIndicator(.sma, period: 20, color: ChartColor(r: 1, g: 0.85, b: 0.2))

TradeChartView(chart: chart)
```

### 주의사항

- **스레드**: `Chart`의 모든 메서드는 main thread에서만 호출. 백그라운드에서 데이터를
  내려받았다면 `Task { @MainActor in chart.appendCandle(...) }` 등으로 main에 dispatch.
- **실시간 갱신**: 마지막 캔들 close 갱신은 `chart.updateLast(close:volume:)`,
  새 분/일봉이 마감되면 `chart.appendCandle(...)`. 들어오는 캔들의 `timestamp`는
  마지막 캔들보다 작거나 같으면 (작으면 무시, 같으면 갱신) 처리.
- **레이아웃 활용**: SwiftUI overlay를 그리려면 `chart.layout()` 결과의 `plot` rect를
  사용. `buildFrame` 직후에만 유효하므로 `.onChange` 등에서 재조회.
- **Renko brick size**: `chart.setRenkoBrickSize(0)`이면 엔진이 마지막 close × 0.5%를
  자동 값으로 사용. 호스트가 ATR 기반으로 계산해 명시적으로 넣어도 됨.
- **Heikin-Ashi vs Renko 지표**: HA에선 SMA/RSI 같은 지표가 원본 OHLC 기준으로 계산
  되어 일반 캔들 모드와 동일한 값을 보임. Renko에선 brick 시리즈 기준으로 계산.
- **알림선 드래그**: `Examples/ios-demo`의 `+알림선` 버튼으로 추가 후 선을 드래그하면
  가격이 갱신됨. 호스트는 `chart.hitTestAlertLine(screenY:)` + `chart.updateAlertLine(id:screenY:)`
  로 같은 흐름 구현.
- **deprecated**: `chart.pan(deltaPixels:)` / `chart.zoom(factor:anchorX:)`은 곧 제거.
  대신 `chart.applyPan(dxPx:)` / `chart.applyPinch(scale:anchorPx:)` 사용.
- **좌표 변환**: 호스트 커스텀 overlay/annotation을 `TradeChartView` 위에 그릴 때
  `chart.indexAt(screenX:)` / `chart.screenX(forIndex:)` / `chart.price(atScreenY:)` /
  `chart.screenY(forPrice:)`로 화면-도메인 변환. PRICE_LOG/PERCENT 모드에서도
  raw price가 보장된다. **buildFrame 후에만 의미** — 첫 프레임 전엔 0/실패 반환.
- **알림 cross**: `chart.setAlertCallback { id, price in ... }`로 등록하면
  `appendCandle`/`updateLast`로 들어온 가격이 알림선을 가로지를 때 main thread에서
  콜백 호출. 호스트는 푸시/햅틱/사운드 트리거.
- **Donchian Channels**: `chart.addDonchian(period: 20, color:, edgeColor:)` —
  period 캔들의 최고/최저/중앙선. 터틀 트레이딩 셋업.
- **Keltner Channels**: `chart.addKeltner(emaPeriod: 20, atrPeriod: 10, multiplier: 2.0, color:, edgeColor:)` —
  EMA ± multiplier × ATR. BB와 비교/대체로 자주 쓰임.
- **지표 값 query**: crosshair hover 라벨용으로
  `chart.queryIndicator(.sma, period: 20, at: idx)` (단일 출력),
  `queryBollinger`/`queryMACD`/`queryStochastic`/`queryDonchian`/`queryKeltner`/`queryDMI`/`queryPivot`/`queryIchimoku`/`querySuperTrend` (다출력 전용).
  등록된 (kind, period) spec과 정확히 일치해야 값 반환. 미등록/index 범위 밖이면 nil.
  **Renko 주의**: query는 항상 원본 OHLC 기준으로 계산되며, 메인 패널의 brick
  시리즈 라인과 의미가 다를 수 있다 (시각=brick, 라벨=원본).
- **세션 시작 보정**: `chart.setSessionStartUTC(hour: 14, minute: 30)` (NYSE 09:30 EST).
  VWAP/Pivot의 일별 boundary가 거래소 세션 시작 시각으로 정렬. KR/JP=default(0,0), CET=(8,0).
  **DST**: 호스트가 시즌별로 UTC 시각을 다시 호출 (NYSE EDT 시 13:30, EST 시 14:30).
- **VWAP ± σ 밴드**: `chart.addVWAPWithBands(numStdev: 2.0, color:, bandColor:)`.
  같은 day session 내 가중분산으로 sigma 계산. `queryVWAPBands(at:)`로 hover 값 조회.
- **ZigZag**: `chart.addZigZag(deviationPct: 5.0, color:)`. swing high/low 직선 연결.
  **repaint 주의**: 마지막 swing은 잠정값이며 새 캔들이 들어와 더 큰 극값이 나오면
  위치가 갱신된다. ZigZag 기반 알림은 신뢰성 검증 후 사용할 것.
- **드로잉 저장/복원**: `let saved = chart.exportDrawings()` → JSON으로 영속화 →
  복원 시 `chart.importDrawings(saved)`. 도메인 좌표(timestamp/price) 기반이라
  series가 달라도 안전. host가 `Codable` `[Chart.DrawingExport]`를 원하는 형식으로 직렬화.
- **알림 콜백 lifecycle**: host가 `setAlertCallback`의 user 컨텍스트를 해제하기 전에는
  반드시 `chart.setAlertCallback(nil)`을 명시 호출해 dangling 방지.
  `tce_destroy`도 자동 nullify하지만 destroy 이전에 user 객체가 해제되는 경로를 위해.
- **Volume Profile**: `chart.addVolumeProfile(bins: 24, widthRatio: 0.20, barColor:, pocColor:)`.
  plot 우측 widthRatio 영역에 가격 bin별 거래량 막대 + POC/VAH/VAL 가로선.
  alpha는 엔진이 0.30으로 강제. **Renko 모드는 미지원** (no-op).
- **Fib Extension**: `drawingMode = .fibExtension`. 두 점 너머 100/127.2/138.2/161.8/200/261.8% 가로선.
  `fibRetracement`(두 점 사이)와 별개의 도구.
- **ZigZag 시작점**: 표준 ZigZag와 일치하도록 첫 swing이 결정 시점 [0..i] 윈도우의
  반대 극값(low for 상승, high for 하락)으로 보정됨. v0.10 동작과 시각 차이 가능.
- **성능 baseline (v0.11)**: Release 빌드 기준 5000 candles + 8 indicators에서
  build_frame 1.32ms / query 0.023ms. 16ms 프레임 budget 내 안전.

## 샘플 앱 실행

```bash
cd Examples/ios-demo
tuist install
tuist generate
open TradeChartDemo.xcworkspace
# Xcode에서 ⌘R
```

## 기여 가이드

호스트 앱이 매번 작성해야 할 코드는 wrapper에 흡수한다 — Metal 렌더, 텍스트 overlay, 제스처 dispatch.
호스트 앱은 데이터 push와 `TradeChartView(chart:)` 한 줄만으로 차트 사용.
