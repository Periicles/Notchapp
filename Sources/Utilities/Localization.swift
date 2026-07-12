import Foundation

/// `String(localized:bundle:locale:)` does not reliably honor an explicit `locale`
/// override when given a plain `Bundle` value — it silently falls back to
/// `Locale.current` instead. Routing through `LocalizedStringResource` with a
/// `.atURL` bundle description resolves correctly regardless of the system locale.
/// This is what lets tests pin the `en` catalog deterministically and lets snapshot
/// building honor a caller-supplied locale rather than always following the host
/// machine's language.
enum Localized {
    static func string(_ value: String.LocalizationValue, locale: Locale) -> String {
        String(localized: LocalizedStringResource(value, locale: locale, bundle: .atURL(Bundle.module.bundleURL)))
    }
}
