import Foundation

@main
struct WeightFormatterTests {
    static func main() {
        let cases: [(weight: Double, expected: String)] = [
            (7.5, "7.5"),
            (8, "8"),
            (0.5, "0.5")
        ]

        for testCase in cases {
            let actual = WeightFormatter.string(from: testCase.weight)
            precondition(
                actual == testCase.expected,
                "Expected \(testCase.weight) to display as \(testCase.expected), got \(actual)"
            )
        }

        print("WeightFormatterTests passed")
    }
}
