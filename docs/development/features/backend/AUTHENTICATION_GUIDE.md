# Authentication

API requests use a bearer token or an API key.

```
Authorization: Bearer <token>
```

```
X-API-Key: <key>
```

The identity provider is configured for each deployment. Do not commit provider hostnames, client identifiers, or keys.

Store tokens in platform secure storage, send them only over HTTPS, and refresh them before they expire.
