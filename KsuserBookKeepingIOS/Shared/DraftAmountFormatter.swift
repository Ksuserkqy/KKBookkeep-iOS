import Foundation

enum DraftAmountFormatter {
    static func sanitizedNumericAmountText(_ text: String) -> String {
        var result = ""
        var hasDecimalSeparator = false
        var fractionalDigitCount = 0

        for character in text {
            if character.isNumber {
                if hasDecimalSeparator {
                    guard fractionalDigitCount < 2 else { continue }
                    fractionalDigitCount += 1
                }

                result.append(character)
            } else if character == "." || character == "。" {
                guard !hasDecimalSeparator else { continue }
                hasDecimalSeparator = true
                result.append(".")
            }
        }

        return result
    }

    static func normalizedAmountText(_ text: String, allowNegative: Bool) -> String? {
        let trimmedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")

        guard !trimmedText.isEmpty else { return "0" }

        let pattern = allowNegative
            ? #"^-?(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$"#
            : #"^(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$"#

        guard trimmedText.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }

        let decimalText: String
        if trimmedText.hasPrefix("-.") {
            decimalText = "-0" + trimmedText.dropFirst()
        } else if trimmedText.hasPrefix(".") {
            decimalText = "0" + trimmedText
        } else {
            decimalText = trimmedText
        }

        guard let decimal = Decimal(string: decimalText, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        let number = NSDecimalNumber(decimal: decimal)
        guard !number.doubleValue.isNaN else { return nil }

        return plainFormatter.string(from: number)
    }

    static func currencyText(from amountText: String) -> String {
        let normalizedText = normalizedAmountText(amountText, allowNegative: true) ?? "0"
        let decimal = Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        let number = NSDecimalNumber(decimal: decimal)

        return currencyFormatter.string(from: number) ?? "¥\(normalizedText)"
    }

    private static let plainFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
