// swift-tools-version: 5.9
import PackageDescription

// TradeChart_iOS — Swift wrapper.
// host는 `import TradeChart`로 wrapper 사용 (C 엔진 TradeChartEngineC는 내부 dispatch).
let package = Package(
    name: "TradeChart_iOS",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TradeChart", targets: ["TradeChart"]),
    ],
    dependencies: [
        .package(url: "https://github.com/junbro22/TradeChartEngine.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "TradeChart",
            dependencies: [
                .product(name: "TradeChartEngineC", package: "TradeChartEngine"),
            ],
            path: "Sources/TradeChart"
        ),
    ]
)
