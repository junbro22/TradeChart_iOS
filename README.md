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

let chart = Chart()
chart.setHistory(candles)
chart.addIndicator(.sma, period: 20, color: ChartColor(r: 1, g: 0.85, b: 0.2))

TradeChartView(chart: chart)
```

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
