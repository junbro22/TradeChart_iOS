# TradeChart_iOS

[TradeChartEngine](https://github.com/junbro22/TradeChartEngine) (C++ 코어)을
iOS에서 SwiftUI로 사용하기 위한 wrapper + 샘플 앱.

## 구성

```
TradeChart_iOS/
├── Package.swift                   # SPM — TradeChartEngine 의존
├── Sources/TradeChartEngine/       # Swift wrapper (Chart / TradeChartView / Renderer)
└── Examples/ios-demo/              # Tuist 샘플 앱
```

엔진(xcframework)은 TradeChartEngine repo에서 SPM binary target으로 가져옴 → wrapper는 그 위에 SwiftUI/Metal/제스처를 붙임.

## 사용 (호스트 앱)

```swift
.package(url: "https://github.com/junbro22/TradeChart_iOS.git", branch: "main")
// dependency: .product(name: "TradeChartEngine", package: "TradeChart_iOS")
```

```swift
import TradeChartEngine

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
