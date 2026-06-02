/// Application-layer re-export of [currentMachinesServerIdProvider].
///
/// Keeps the presentation layer decoupled from the data layer — presentation
/// files should import this file instead of the data-layer provider directly.
library;

export 'package:slock_app/features/machines/data/machines_repository_provider.dart'
    show currentMachinesServerIdProvider;
