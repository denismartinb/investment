import Foundation

private let currencyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "es_ES")
    formatter.currencyCode = "EUR"
    formatter.maximumFractionDigits = 0
    return formatter
}()

private let currencyWithDecimalsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "es_ES")
    formatter.currencyCode = "EUR"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter
}()

private let percentFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.locale = Locale(identifier: "es_ES")
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 1
    return formatter
}()

extension Double {
    var currencyString: String {
        currencyFormatter.string(from: NSNumber(value: self)) ?? "-"
    }

    var preciseCurrencyString: String {
        currencyWithDecimalsFormatter.string(from: NSNumber(value: self)) ?? "-"
    }

    var compactCurrencyString: String {
        let absolute = abs(self)
        if absolute >= 1_000_000 {
            let value = self / 1_000_000
            return String(format: "%.1f M€", locale: Locale(identifier: "es_ES"), value)
        }
        if absolute >= 1_000 {
            let value = self / 1_000
            return String(format: "%.0f mil €", locale: Locale(identifier: "es_ES"), value)
        }
        return currencyString
    }

    var signedCurrencyString: String {
        if self > 0 {
            return "+\(currencyString)"
        }
        return currencyString
    }

    var percentString: String {
        percentFormatter.string(from: NSNumber(value: self)) ?? "-"
    }

    func percentOf(_ total: Double) -> Double {
        guard total != 0 else { return 0 }
        return self / total
    }
}
