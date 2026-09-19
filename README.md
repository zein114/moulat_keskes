# Moulat Keskes · مولات كسكس

Arabic-first Flutter + Supabase marketplace for homemade Mauritanian food. Inspired by the supplied concept image: warm ivory, forest green, Tajawal Arabic typography, food photography, and separate customer/seller experiences.

## Run the app

Flutter 3.41.6 / Dart 3.11.4 or compatible newer SDK.

```powershell
flutter pub get
flutter run -d chrome
```

Without Supabase configuration, the app runs in an explicitly labeled in-memory demo. Orders, inventory edits, favorites, and messages reset when the app restarts. No real orders or payments are sent. Use **حسابي → فتح لوحة البائعة** to switch to the demo seller. Create an order from أم خديجة first, then advance it in seller mode.

The app does not read `.env` automatically. On macOS/Linux, if `.env` contains `SUPABASE_URL` and `SUPABASE_ANON_KEY`, start the connected app with:

```bash
bash tool/run_live.sh -d chrome --web-port 8080
```

For an attached Android or iOS phone, find its ID with `flutter devices`, then run directly on the phone:

```bash
bash tool/run_live.sh --mobile -d YOUR_DEVICE_ID
```

The `--mobile` option lets the app use its registered `moulatkeskes://auth-callback/` redirect for sign-in links. Running Chrome first is not required.

The map shows only Supabase merchants. In demo mode it shows no merchant pins and explains that a live connection is needed. Restart the app after switching modes.

For a connected backend, follow [database and authentication setup](docs/SUPABASE_SETUP.md). The guide includes SQL migration, RLS, account roles, confirmation emails, password recovery, redirect URLs, configuration, and verification steps.

```powershell
flutter run -d chrome --web-port=3000 --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY --dart-define=AUTH_REDIRECT_URL=http://localhost:3000/
```

The historical variable name `SUPABASE_ANON_KEY` accepts a Supabase publishable key (or legacy anon key). Never use a service-role or secret key in the client. No credentials are committed.

## MVC structure

```text
lib/
  main.dart                         Bootstrap, Supabase configuration, RTL theme
  models/models.dart                Seller, Meal, FoodOrder; labeled demo fixtures
  controllers/
    app_controller.dart             Catalog, location, cart, stock, checkout, seller operations
    auth_controller.dart            Sign-in, sign-up, recovery and redirect handling
    order_controller.dart           Order messages and verified reviews
  views/
    app.dart                        Welcome, navigation, discovery and family-order dialog
    customer.dart                   Seller detail, maps, cart, checkout, tracking, chat, review
    seller.dart                     Dashboard, meal editor, seller profile, account
    auth.dart                       Authentication forms
    shared.dart                     Colors, typography and reusable UI components
supabase/
  migrations/202609170001_initial_schema.sql
  tests/database_smoke.sql
```

Views render the models and call controllers. Controllers own validation, state changes and Supabase operations. Models describe the data. `ChangeNotifier` rebuilds affected views. Supabase enforces authorization and purchase invariants; client validation is for feedback, not security.

## Included flows

- Arabic RTL responsive screens for phone and wide browser layouts.
- Search meals, sellers and neighborhoods; category/open filters, favorites for the current session, stock and approximate distance.
- GPS permission flow or manual neighborhood selection; OpenStreetMap map and external directions.
- Multi-seller family orders: allocate available portions by distance and review the proposed cart before ordering.
- Cash on receipt, pickup or a delivery request coordinated with the seller. Delivery fees are not calculated or charged.
- Customer signup/signin, seller signup, confirmation email, password reset, persistent Supabase sessions and logout.
- Seller setup with public business coordinates/contact, availability switch, meal add/edit, stock and price management.
- Today's order statistics and sequential pending → preparing → ready → delivered tracking.
- Participant-only order chat and one customer review per delivered order.
- In-app refresh: orders/catalog every 30 seconds; open chat every 15 seconds, plus manual pull-to-refresh. No background push notifications.

## Scope and remaining integrations

The PDF is a concept/roadmap brief. This repository implements the food marketplace MVP. AI forecasting, voice bookkeeping, financing, subscriptions/commissions, courier dispatch, cancellation/refunds, seller moderation, and other home services are future work. Bankily, Sedad and Masrivi are displayed as **coming soon**, not simulated payment success. Connect an authorized provider server-side with verified webhooks before enabling online payments.

The seller editor accepts a public HTTPS image URL; device camera/gallery upload is not implemented. The bundled couscous image is generated demo artwork, not a representation of a real seller's food. Bassi and aish use category icons until sellers supply images. Tajawal is bundled under its SIL Open Font License (`assets/fonts/OFL.txt`).

Map tiles use OpenStreetMap for development. For production, configure `MAP_TILE_URL` for a suitable provider, retain required attribution, and follow that provider's usage policy. GPS needs a physical device or browser location permission and HTTPS (localhost works for development). Distances are straight-line estimates, not travel times.

Android and iOS location permissions/auth callback schemes are configured. macOS entitlements are included. Android/iOS release signing and physical-device auth/location checks remain deployment work. Windows/Linux callback protocol registration is not included; use web for authentication recovery on desktop until configured.

## Validation

```powershell
flutter analyze
flutter test
flutter build web --release
```

Database security smoke checks live in `supabase/tests/database_smoke.sql`; run them in a disposable Supabase project after applying the migration. They roll back test fixtures. See the setup guide for concurrency and provider-specific checks.

## Git milestones

The repository is local. Each completed step is committed; inspect `git log --oneline`. No remote repository or deployment has been created.
