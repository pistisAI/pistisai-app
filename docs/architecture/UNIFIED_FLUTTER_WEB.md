# Unified Flutter Web Architecture

## Overview

Pistisai implements a unified Flutter-based web architecture that consolidates marketing content and application functionality into a single codebase. This removes the need for a separate marketing static-site container while keeping documentation on its own static site. (The earlier "v3.10.3+" version marker was stale; the current app version is `1.5.58+180` per `pubspec.yaml:6`.)

## Architecture Changes

### Before (Multi-Container)

```
example.com → static-site container (HTML/CSS)
app.example.com → flutter-app container (Flutter web)
docs.example.com → static-site container (VitePress docs)
```

### After (Unified Flutter)

```
example.com → flutter-app container (Flutter marketing pages)
app.example.com → flutter-app container (Flutter chat interface)
docs.example.com → static-site container (VitePress docs - unchanged)
```

## Domain Routing Strategy

### Main Domain (example.com)

- **Purpose**: Marketing homepage and download information
- **Routes**: `/` (homepage), `/download` (installation guide)
- **Platform**: Web-only (`kIsWeb` detection)
- **Authentication**: Not required for marketing content

### App Subdomain (app.example.com)

- **Purpose**: Main application interface
- **Routes**: `/chat`, `/settings`, `/login`, `/callback`
- **Platform**: Web and desktop
- **Authentication**: Required for application features
- **Redirect**: Root `/` redirects to `/chat`

### Docs Subdomain (docs.example.com)

- **Purpose**: Technical documentation
- **Technology**: VitePress (unchanged)
- **Container**: static-site (docs path only)

## Flutter Route Configuration

### Platform-Specific Routing with Lazy Loading

```dart
// Lazy load marketing screens
import '../screens/marketing/marketing_lazy.dart' deferred as marketing_lazy;

// Home route - platform-specific behavior
GoRoute(
  path: '/',
  name: 'home',
  builder: (context, state) {
    if (kIsWeb) {
      // Lazy load HomepageScreen
      return FutureBuilder<void>(
        future: marketing_lazy.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return marketing_lazy.HomepageScreen();
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      return const HomeScreen(); // Desktop chat interface
    }
  },
),

// Lazy-loaded marketing routes
ShellRoute(
  builder: (context, state, child) {
    return FutureBuilder<void>(
      future: marketing_lazy.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return child;
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  },
  routes: marketing_lazy.marketingRoutes,
),
```

### Authentication Logic

```dart
redirect: (context, state) {
  final isHomepage = state.matchedLocation == '/' && kIsWeb;
  final isDownload = state.matchedLocation == '/download' && kIsWeb;
  
  // Allow marketing pages without authentication
  if (kIsWeb && (isHomepage || isDownload)) {
    return null;
  }
  
  // Require authentication for app routes
  if (!isAuthenticated) {
    return '/login';
  }
  
  return null;
},
```

### Web Authentication

There is **no Auth0/JS bridge** in this repository. `web/` ships only the Flutter bootstrap and static assets: `web/index.html` loads `flutter_bootstrap.js` and contains no Auth0 or bridge script. Authentication is handled in Dart by `AuthService` (`lib/services/auth_service.dart`) through a provider-agnostic `AuthProvider`; the provider selected in `lib/di/locator.dart:392-423` is `CloudflareAccessAuthProvider` (`lib/auth/providers/cloudflare_access_auth_provider.dart:19`), not Auth0. The JS bridge snippet that appeared in older revisions of this document was aspirational and has been removed.

App routes still require authentication; the public marketing routes (`/`, `/download`) are served from `lib/screens/marketing/` and wired in `lib/config/router.dart:420`.

## Implementation Details

### Marketing Screens

- **Location**: `lib/screens/marketing/`
- **Files**: `homepage_screen.dart`, `download_screen.dart`
- **Lazy Loading**: `marketing_lazy.dart` bundles screens for deferred loading
- **Design**: Material Design 3 with static site color scheme
- **Responsive**: Mobile-first responsive design
- **Content**: Replicates existing static site functionality

### Nginx Configuration

The production container uses the repo-root `nginx.conf`: one server on port 80, no `server_name` split, and no `proxy_pass`. Domain routing in front of that container is handled on the host, which is outside this file. Cache rules, the CanvasKit build flag, and the healthcheck are in [Web Deploy](../operations/cicd/WEB_DEPLOY.md).

The sample below is an earlier routing sketch. It is not what the image ships.

```nginx
# Not the checked-in container config.
server {
    server_name example.com;
    location / {
        proxy_pass http://flutter-app;
    }
}
```

## Benefits

### Unified Codebase

- Single Flutter application handles all web functionality
- Consistent theming and component library
- Shared authentication and state management
- Simplified deployment and maintenance

### Performance

- Single container for web functionality
- Shared Flutter assets and dependencies
- Reduced infrastructure complexity
- Faster build and deployment times
- **Optimized Loading**: Route-based code splitting reduces initial bundle size

### Developer Experience

- Single codebase for all web features
- Consistent development environment
- Shared tooling and testing infrastructure
- Simplified debugging and monitoring

## Migration Status (verified against code)

The implementation phase is complete in the repository:

- `lib/screens/marketing/` contains `homepage_screen.dart`, `download_screen.dart`, `documentation_screen.dart` and `marketing_lazy.dart`.
- `lib/config/router.dart:420` mounts `marketing_lazy.marketingRoutes` with platform detection.
- Route-based deferred loading is wired through `marketing_lazy` (`deferred as marketing_lazy`).
- `nginx.conf` at the repo root is the config the production container ships (see "Nginx Configuration" above); `web/nginx.conf` and `web/nginx-main.conf` are also present.
- `web/index.html` loads `flutter_bootstrap.js` and static assets; VitePress docs remain on the docs host.

The items below are **operational checks**: they depend on deployed DNS/Traefik configuration and cannot be confirmed from this repository. They are intentionally left as unchecked TODOs rather than asserted as done (deploys run only through GitHub Actions).

- [ ] Domain access: `example.com` → Flutter homepage; `/download` → Flutter download page; `app.example.com` → `/chat`; `docs.example.com` → VitePress docs.
- [ ] Web: marketing routes public, app routes authenticated.
- [ ] Desktop: marketing routes excluded; direct chat access.
- [ ] Responsive layout, navigation and link functionality on the live sites.
- [ ] Traffic/performance monitoring after deploy.

No repository change is implied by these boxes; they are a runbook for whoever owns deployment.

## Future Considerations

### Static Site Container

The static-site container will be retained for documentation hosting but can be further optimized:

- Remove homepage-related configurations
- Focus solely on docs.example.com
- Consider migrating docs to Flutter in future versions

### Performance Optimization

- Optimize Flutter web bundle size
- Add progressive web app features
- Consider service worker caching
- **Completed**: Route-based code splitting

### SEO and Analytics

- Add meta tags for marketing pages
- Implement structured data
- Configure analytics tracking
- Optimize for search engines
