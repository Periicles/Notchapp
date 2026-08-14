import Foundation

/// Resolves localized strings from the `.lproj` bundles that SwiftPM compiles
/// natively from `Sources/Resources/{en,fr}.lproj/Localizable.strings`. When
/// `locale` is the system's current locale, resolution is left entirely to the
/// resource bundle's standard search order (which honors a per-app language
/// override). For an explicit non-current locale — as used by tests and by
/// snapshot building when a caller-supplied locale is needed — the matching
/// `.lproj` sub-bundle is looked up directly so resolution doesn't depend on
/// the host machine's language.
enum Localized {
    /// Where every localized string in the app comes from.
    ///
    /// Not `Bundle.module`: SwiftPM generates that accessor for a bare
    /// executable, so it looks for the resource bundle next to `Bundle.main`'s
    /// *bundle* URL — which for a packaged `.app` is the `.app` itself, not
    /// `Contents/Resources` where resources belong. Its only other candidate is
    /// the absolute `.build` path of the machine that compiled the binary, so a
    /// packaged build resolved resources purely by accident on the developer's
    /// machine and trapped at launch anywhere else.
    static let resources: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()

    private static let resourceBundleName = "NotchBar_NotchBar.bundle"

    static func string(_ keyAndValue: String.LocalizationValue, locale: Locale = .current) -> String {
        String(localized: keyAndValue, bundle: bundle(for: locale))
    }

    private static func bundle(for locale: Locale) -> Bundle {
        guard locale != .current else { return resources }
        let language = locale.language.languageCode?.identifier ?? "en"
        guard let path = resources.path(forResource: language, ofType: "lproj"),
              let lprojBundle = Bundle(path: path) else {
            return resources
        }
        return lprojBundle
    }
}
