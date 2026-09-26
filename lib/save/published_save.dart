/// The saves players already have: those of the last public build. Every
/// build reads its own format and this one, and no other: the formats in
/// between were never installed by anyone. See `docs/save_policy.md`.
library;

/// The save format of the last public build, null until the first one.
/// Set it to `SaveGame.format` when a build goes public, and never
/// otherwise.
const int? publishedSaveFormat = null;

/// Brings a save of [publishedSaveFormat] up to what the current format
/// holds; `SaveGame.decode` stamps the new format on it afterwards.
///
/// There is only ever this one migration, from the public build to the
/// current one: when the format changes again it is rewritten, not
/// chained. It throws until it is written, and the saves frozen from the
/// public build (`test/saves/published`) fail their test until then.
Map<String, Object?> migratePublishedSave(Map<String, Object?> save) =>
    throw UnsupportedError('no migration from format $publishedSaveFormat');

typedef SaveMigration =
    Map<String, Object?> Function(Map<String, Object?> save);

/// The saves of the public build, as `SaveGame.decode` reads them: the
/// game's own by default, others in tests.
final class PublishedSaves {
  const PublishedSaves({
    this.format = publishedSaveFormat,
    this.migrate = migratePublishedSave,
  });

  final int? format;
  final SaveMigration migrate;
}
