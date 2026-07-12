import Foundation
import PackagePlugin

/// SwiftPM's own build system (unlike Xcode's) does not compile `.xcstrings`
/// String Catalogs into per-locale `.lproj/Localizable.strings` — it copies the
/// raw JSON verbatim, which `Bundle`/`String(localized:)` cannot read at runtime.
/// This plugin shells out to Apple's `xcstringstool` to do that compilation so
/// `swift build` / `swift test` produce a working localized resource bundle.
@main
struct CompileStringCatalogPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }

        let catalogs = sourceTarget.sourceFiles(withSuffix: "xcstrings").map(\.url)
        guard !catalogs.isEmpty else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: "StringCatalogs")

        return catalogs.map { catalog in
            .prebuildCommand(
                displayName: "Compiling String Catalog \(catalog.lastPathComponent)",
                executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: [
                    "xcstringstool", "compile",
                    catalog.path,
                    "--output-directory", outputDirectory.path,
                ],
                outputFilesDirectory: outputDirectory
            )
        }
    }
}
