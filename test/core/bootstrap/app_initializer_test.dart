import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/bootstrap/app_initializer.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';

void main() {
  test('bootstrapper runs startup steps once for repeated calls', () async {
    var persistenceCalls = 0;
    var repositoryCalls = 0;

    final bootstrapper = AppInitializer.forTesting(
      noteRepository: NoteRepository.internalForTesting(),
      appSettingsRepository: AppSettingsRepository(),
      initializePersistenceStep: () async {
        persistenceCalls++;
      },
      initializeRepositoriesStep: () async {
        repositoryCalls++;
      },
    );

    await Future.wait([bootstrapper.initialize(), bootstrapper.initialize()]);

    expect(persistenceCalls, 1);
    expect(repositoryCalls, 1);
  });

  test('bootstrapper retries after a startup failure', () async {
    var persistenceCalls = 0;

    final bootstrapper = AppInitializer.forTesting(
      noteRepository: NoteRepository.internalForTesting(),
      appSettingsRepository: AppSettingsRepository(),
      initializePersistenceStep: () async {
        persistenceCalls++;
        throw StateError('boom');
      },
      initializeRepositoriesStep: () async {},
    );

    // Call 1: Should fail and reset _bootstrapFuture
    await expectLater(bootstrapper.initialize(), throwsStateError);
    expect(persistenceCalls, 1);

    // Call 2: Should trigger a fresh initialization attempt
    await expectLater(bootstrapper.initialize(), throwsStateError);
    expect(persistenceCalls, 2);
  });
}
