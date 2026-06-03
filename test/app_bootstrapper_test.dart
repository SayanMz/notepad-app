import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/bootstrap/app_bootstrapper.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';

void main() {
  test('bootstrapper runs startup steps once for repeated calls', () async {
    var persistenceCalls = 0;
    var repositoryCalls = 0;

    final bootstrapper = AppBootstrapper(
      noteRepository: NoteRepository.internalForTesting(),
      appSettingsRepository: AppSettingsRepository(),
      initializePersistence: () async {
        persistenceCalls++;
      },
      initializeRepositories: () async {
        repositoryCalls++;
      },
    );

    await Future.wait([bootstrapper.initialize(), bootstrapper.initialize()]);

    expect(persistenceCalls, 1);
    expect(repositoryCalls, 1);
  });

  test('bootstrapper retries after a startup failure', () async {
    var persistenceCalls = 0;

    final bootstrapper = AppBootstrapper(
      noteRepository: NoteRepository.internalForTesting(),
      appSettingsRepository: AppSettingsRepository(),
      initializePersistence: () async {
        persistenceCalls++;
        throw StateError('boom');
      },
      initializeRepositories: () async {},
    );

    expect(bootstrapper.initialize(), throwsStateError);
    expect(bootstrapper.initialize(), throwsStateError);
    expect(persistenceCalls, 2);
  });
}
