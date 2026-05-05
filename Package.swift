// swift-tools-version: 5.9
import PackageDescription

// TradeChart_iOS — TradeChartEngine xcframework를 SPM으로 받아 Swift wrapper 노출.
// 별도 repo의 코어 엔진을 SPM 의존성으로 가져옴.
let package = Package(
    name: "TradeChart_iOS",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TradeChartEngine", targets: ["TradeChartEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/junbro22/TradeChartEngine.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "TradeChartEngine",
            dependencies: [
                .product(name: "TradeChartEngineC", package: "TradeChartEngine"),
            ],
            path: "Sources/TradeChartEngine"
        ),
    ]
)
