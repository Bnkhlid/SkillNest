import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/services/firebase_remote_config_service.dart';

void main() {
  test('semantic version comparison ignores build suffix', () {
    expect(compareSemanticVersions('1.2.0+5', '1.2.0'), 0);
    expect(compareSemanticVersions('1.0.0', '1.1.0'), lessThan(0));
    expect(compareSemanticVersions('2.0.0', '1.9.9'), greaterThan(0));
  });

  test('update information handles minimum version and invalid URL', () {
    const required = UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      minimumVersion: '1.1.0',
      url: '',
      message: '',
      forceUpdate: false,
    );
    const optional = UpdateInfo(
      currentVersion: '1.1.0',
      latestVersion: '1.1.0',
      minimumVersion: '1.0.0',
      url: 'not a url',
      message: '',
      forceUpdate: false,
    );
    expect(required.hasNewVersion, isTrue);
    expect(required.required, isTrue);
    expect(required.hasValidUrl, isFalse);
    expect(optional.hasNewVersion, isFalse);
    expect(optional.required, isFalse);
    expect(optional.hasValidUrl, isFalse);
  });
}
