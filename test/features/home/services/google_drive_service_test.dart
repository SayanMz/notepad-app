import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:notepad/features/home/services/google_drive_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  final String displayName = 'Test User';
  @override
  final String email = 'test@example.com';
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  bool authenticated = false;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    return;
  }

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    authenticated = true;
    return FakeGoogleSignInAccount();
  }

  @override
  Future<GoogleSignInAccount?>? attemptLightweightAuthentication({
    bool reportAllExceptions = false,
  }) {
    return Future.value(authenticated ? FakeGoogleSignInAccount() : null);
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
  }
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: 'GOOGLE_CLIENT_ID=test_id\nGOOGLE_SERVER_CLIENT_ID=test_server_id');
  });

  group('GoogleDriveService', () {
    late FakeGoogleSignIn fakeSignIn;
    late GoogleDriveService service;

    setUp(() {
      fakeSignIn = FakeGoogleSignIn();
      service = GoogleDriveService.internalForTesting(googleSignIn: fakeSignIn);
    });

    test('signIn updates currentUser', () async {
      final result = await service.signIn();
      expect(result, isTrue);
      expect(service.currentUser, isNotNull);
      expect(service.currentUser?.email, 'test@example.com');
    });

    test('signOut clears currentUser', () async {
      await service.signIn();
      expect(service.currentUser, isNotNull);

      await service.signOut();
      expect(service.currentUser, isNull);
    });

    test('ensureAuthenticated returns true if already signed in', () async {
      await service.signIn();
      final result = await service.ensureAuthenticated();
      expect(result, isTrue);
    });
  });
}
