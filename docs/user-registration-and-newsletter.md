# Orah registration, greetings, and newsletter subscribers

## Implemented in the Android app

- First launch is gated by a required full-name and email registration form.
- Email format is validated before registration.
- The name, email, and local subscriber roster are stored using Android platform-backed secure storage.
- Existing registrations are loaded on later launches.
- A greeting is displayed on launch and spoken using text-to-speech by default.
- Settings includes **Speak my name at startup**, which defaults to ON and can be turned OFF.
- The voice preference is persisted locally.

## Subscriber backend integration

The app can POST a registration to an HTTPS subscriber endpoint when built with:

```sh
flutter build apk --dart-define=ORAH_SUBSCRIBER_API_URL=https://your-domain.example/api/subscribers
```

The endpoint receives JSON with `full_name`, `email`, `source`, and `subscribed_at`. It should validate the request, deduplicate by normalized email, store consent/subscription status, apply rate limiting or other abuse protection, and return a 2xx response only after the subscriber has been stored. Do not embed a database password or service-role key in the app.

Without this build-time endpoint, registration still works offline and the subscriber roster is kept securely on that device. It is **not** a centralized mailing list, and the app does not send daily newsletter emails by itself. To deliver a daily newsletter, configure a backend/newsletter provider and its scheduled sending workflow.
