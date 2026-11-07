import 'access_login_flow_stub.dart'
    if (dart.library.io) 'access_login_flow_io.dart' as impl;

/// Opens the Access login and returns the CF_Authorization token when the
/// platform can capture the redirect.
Future<String?> openAccessLogin(Uri loginUrl) => impl.openAccessLogin(loginUrl);
