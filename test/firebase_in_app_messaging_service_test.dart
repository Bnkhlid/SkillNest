import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/services/firebase_in_app_messaging_service.dart';

void main() {
  test('FirebaseInAppMessagingService handles uninitialized Firebase safely', () async {
    await expectLater(FirebaseInAppMessagingService.instance.initialize(), completes);
  });
}