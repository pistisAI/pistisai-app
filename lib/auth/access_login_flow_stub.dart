import 'package:url_launcher/url_launcher.dart';

/// Web opens the Access login in the browser. The token comes back as the
/// CF_Authorization cookie on the protected host, not into this isolate.
Future<String?> openAccessLogin(Uri loginUrl) async {
  await launchUrl(loginUrl, webOnlyWindowName: '_self');
  return null;
}
