import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  test('SessionService saves and loads user correctly', () async {
    // Arrange: mock shared preferences
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.init();

    final user = UserModel(uid: 'uid123', phoneNumber: '+911234567890', name: 'Alice', email: 'alice@example.com');

    // Act: save user
    await session.saveUser(user);

    // Assert: isLoggedIn true and getUser returns equal values
    expect(session.isLoggedIn(), isTrue);

    final loaded = session.getUser();
    expect(loaded, isNotNull);
    expect(loaded!.uid, equals(user.uid));
    expect(loaded.phoneNumber, equals(user.phoneNumber));
    expect(loaded.name, equals(user.name));
    expect(loaded.email, equals(user.email));

    // Cleanup
    await session.clear();
    expect(session.isLoggedIn(), isFalse);
  });
}

