import Foundation

/// Resolves localized strings from the `.lproj` bundles that SwiftPM compiles
/// natively from `Sources/Resources/{en,fr}.lproj/Localizable.strings`. When
/// `locale` is the system's current locale, resolution is left entirely to
/// `Bundle.module`'s standard search order (which honors a per-app language
/// override). For an explicit non-current locale — as used by tests and by
/// snapshot building when a caller-supplied locale is needed — the matching
/// `.lproj` sub-bundle is looked up directly so resolution doesn't depend on
/// the host machine's language.
enum Localized {
    static func string(_ keyAndValue: String.LocalizationValue, locale: Locale = .current) -> String {
        String(localized: keyAndValue, bundle: bundle(for: locale))
    }

    private static func bundle(for locale: Locale) -> Bundle {
        guard locale != .current else { return .module }
        let language = locale.language.languageCode?.identifier ?? "en"
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let lprojBundle = Bundle(path: path) else {
            return .module
        }
        return lprojBundle
    }
}
