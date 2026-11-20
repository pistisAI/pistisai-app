import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/utils/platform_file_utils.dart';

void main() {
  test('writeCallbackFile does not leave auth URLs in a plaintext temp file',
      () async {
    final callbackFile =
        File('${Directory.systemTemp.path}/pistisai_callback.txt');
    if (await callbackFile.exists()) {
      await callbackFile.delete();
    }

    await PlatformFileUtils.writeCallbackFile(
      'pistisai://auth/callback?code=oauth-secret-code',
    );

    expect(
      await callbackFile.exists(),
      isFalse,
      reason: 'OAuth callback URLs must not be written to temp plaintext',
    );
  });
}
