# Supabase database and authentication setup

The Flutter app runs with an in-memory demonstration when neither Supabase setting is supplied. Follow these steps to connect real accounts, kitchens, inventory, orders, messages, and reviews. Demonstration data does not migrate automatically into Supabase.

## 1. Create the database

1. Create a Supabase project in your own account. Save its database password securely.
2. Open **SQL Editor** and run the complete contents of [`supabase/migrations/202609170001_initial_schema.sql`](../supabase/migrations/202609170001_initial_schema.sql) once. It is a transactional initial migration for a fresh app schema; it deliberately does not drop existing tables. Do not rerun it over an existing installation.
3. Confirm that the `public` schema contains `profiles`, `sellers`, `meals`, `orders`, `messages`, and `reviews`, with RLS enabled on every table.
4. Keep `private` out of the API's exposed schemas. It contains trigger helpers, with client execution revoked.
5. Keep the API's `public` schema exposed. The application uses table reads and the explicitly authorized `place_order` / `advance_order` functions.

Alternatively, with the Supabase CLI installed, run these commands from the repository root against your intended **development** project:

```powershell
supabase init
supabase login
supabase link --project-ref YOUR_PROJECT_REFERENCE
supabase db push
```

Choose SQL Editor **or** the CLI migration workflow for the initial application. Do not apply the same SQL manually and then push it again without reconciling migration history. Subsequent schema changes belong in new numbered migration files.

## 2. Configure email authentication

In Supabase **Authentication**, enable the **Email** provider and email/password signups. Enable **Confirm email** for the real app. Configure the minimum password length to match or exceed the application's eight-character minimum.

Configure custom SMTP before inviting real users. Supabase's default mail service restricts delivery to authorized project-team addresses and has restrictive limits; it is intended for development. See [Supabase SMTP setup](https://supabase.com/docs/guides/auth/auth-smtp).

Use the app's registration form to create a **customer** account and a separate **seller** account. Registration sends these metadata fields:

```dart
data: {'name': name, 'role': isSeller ? 'seller' : 'customer'}
```

The database trigger creates a matching `profiles` row. `profiles.id` equals the Supabase Auth user's UUID. The role is chosen once at registration and cannot be changed through the app API. Later edits to Auth user metadata do not promote a customer to a seller. Unknown metadata roles become `customer`.

Seller registration is self-service in this version. If your business requires seller verification, add a separate approval workflow and require approval in both the seller policies and checkout function before opening registration publicly. Do not treat the existing `seller` role as administrative access.

After email confirmation, sign in. The seller must save their public kitchen details before adding meals. No demonstration seller or hard-coded test password is inserted into the live database. When manually creating a user through the Auth dashboard, include the same `name` and `role` metadata, or that user receives the default customer profile.

For a temporary private development project, email confirmation can be disabled to test quickly. Re-enable it and test actual email delivery before release. See [Supabase password authentication](https://supabase.com/docs/guides/auth/passwords).

## 3. Set callback URLs for confirmation and password recovery

Open **Authentication → URL Configuration**:

| Setting | Development value | Release value |
|---|---|---|
| Site URL | `http://localhost:8080/` | Your deployed HTTPS app URL |
| Additional redirect URL, web | `http://localhost:8080/` | Exact deployed HTTPS callback URL |
| Additional redirect URL, Android/iOS | `moulatkeskes://auth-callback/` | Same scheme, unless you change native configuration |

The Flutter define is named `AUTH_REDIRECT_URL`. Set it to the exact allowed URL. Without this define, web uses its current URL without query/fragment and mobile uses `moulatkeskes://auth-callback/`. Run web development on a fixed port so email links return to the right app. Use exact production URLs; broad wildcard redirects are unnecessary for this project. See [Supabase redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).

Android already declares the `moulatkeskes` scheme and `auth-callback` host in `android/app/src/main/AndroidManifest.xml`. iOS registers the scheme in `ios/Runner/Info.plist`. Flutter's built-in deep link handler is disabled there so `supabase_flutter` can process Auth links. Changing the scheme requires changing both native files, the define, and Supabase's allowlist. See [Supabase Flutter deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter).

Test both flows on each target platform:

1. Register, open the confirmation email on the device running the app, and confirm the account. With PKCE, use the same browser/device that initiated the flow.
2. Sign out, choose the forgotten-password action, and request a reset email.
3. Open the reset link, enter a new password on the recovery screen, sign out, and sign back in with it.
4. Verify expired links fail safely; request a fresh email rather than reusing a consumed link.

The recovery screen is driven by `AuthChangeEvent.passwordRecovery` and saves the password through Supabase Auth. Keep the standard confirmation/recovery link templates unless you intentionally implement a custom callback flow. A callback URL being allowed in Supabase does not by itself register it with Android or iOS.

## 4. Connect Flutter

Copy the **Project URL** and **publishable key** from the project's Connect/API settings. A legacy `anon` key also works. The Flutter define retains the name `SUPABASE_ANON_KEY` for either public client key. Never use the secret key or `service_role` key in Flutter; client binaries and web builds are inspectable. Supabase's [Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter) describes the client connection.

From the repository root, run this PowerShell command with your public project values:

```powershell
flutter run -d chrome --web-port 8080 --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REFERENCE.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_CLIENT_KEY --dart-define=AUTH_REDIRECT_URL=http://localhost:8080/
```

For an attached Android device or emulator, use its device ID from `flutter devices`:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REFERENCE.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_CLIENT_KEY --dart-define=AUTH_REDIRECT_URL=moulatkeskes://auth-callback/
```

Use the same defines with `flutter build apk`, `flutter build appbundle`, or `flutter build web`. These are compile-time values: restart/rebuild after changing them. A build without either Supabase define starts the demonstration. A partially specified configuration shows an error rather than silently using the demonstration.

An optional local JSON configuration can be passed with `--dart-define-from-file=path/to/your-local-config.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REFERENCE.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_PUBLIC_CLIENT_KEY",
  "AUTH_REDIRECT_URL": "http://localhost:8080/"
}
```

Keep real environment configuration out of source control. The database password and server secret keys are never needed by the app.

## 5. Database contract

| Table | Purpose | Client access |
|---|---|---|
| `profiles` | Account name and immutable customer/seller role | Read own row; update own `name` only |
| `sellers` | Public kitchen profile, business phone, location, opening state, derived rating | Anyone reads; seller creates/edits own business fields |
| `meals` | Category, whole-MRU price, stock, description, HTTPS image URL | Anyone reads; seller manages own meals |
| `orders` | Immutable purchase snapshot, participants, fulfillment, status | Participants read; only RPCs create/advance |
| `messages` | Order conversation | Participants read/send as themselves; no client edit/delete |
| `reviews` | One rating per delivered order | Customer creates for own delivered order; participants read |

The three category enum values are exactly `الكسكس`, `الباسي`, and `العيش`. Prices and totals are integer **MRU**, not floating-point values or minor currency units. `sellers.id` equals the owner's Auth UUID; meal and order IDs are generated UUIDs. Seller contact and coordinates are intentionally public business data. Review text and its customer/order references are private to order participants; the aggregate seller rating is public.

Checkout calls:

```dart
await client.rpc('place_order', params: {
  'p_items': [
    {'meal_id': mealId, 'quantity': 2, 'price': displayedPrice},
  ],
  'p_fulfillment': 'pickup', // or 'delivery'
  'p_address': '', // Required for delivery.
  'p_customer_name': customerName,
});
```

`place_order` returns an array of created orders, one per kitchen. The database normalizes repeated meal IDs, checks authentication and open kitchens, locks all relevant seller rows then meal rows in UUID order, and reserves stock atomically. Prices and meal names come from the database; client totals and names are ignored. Each line's optional `price` is an expected price: Flutter supplies the displayed value, and a mismatch rejects the entire checkout with `Meal price changed; refresh cart`. API callers may omit this expectation and still receive server-authoritative pricing. A missing meal, closed kitchen, own-kitchen purchase, invalid quantity, or insufficient stock also aborts the entire cart. Limits are 100 submitted lines and 1,000 portions per distinct meal.

Only the order's seller can call `advance_order(p_order_id)`. It locks the order and advances one state: `pending → preparing → ready → delivered`. Direct order inserts, edits, and deletes are denied. Reviews require a delivered order and update `sellers.rating` via a trigger; clients cannot assign their own rating.

RLS and column grants both enforce these rules. Functions that need elevated table access explicitly check the authenticated participant and use a fixed empty search path; trigger-only functions are not exposed. Background administrative work must use a trusted server environment. See Supabase's [RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security) and [function security guide](https://supabase.com/docs/guides/database/functions).

## 6. Verify before connecting real customers

Run [`supabase/tests/database_smoke.sql`](../supabase/tests/database_smoke.sql) in SQL Editor on a disposable development project after applying the migration. Run the **entire file**, not individual statements. It creates synthetic accounts, switches database roles, checks successful operations and access denials, and rolls everything back. Expected result: `PASS: database smoke test completed; fixtures rolled back`. If the session stops on a failure, run `ROLLBACK;` before trying again. This is plain SQL/PLpgSQL, not a pgTAP test suite.

With `psql` already installed, the equivalent is:

```powershell
psql "YOUR_DEVELOPMENT_DATABASE_CONNECTION_STRING" -v ON_ERROR_STOP=1 -f supabase/tests/database_smoke.sql
```

The smoke test covers signup profiles, owner-only profile reads, role protection, normalized multi-kitchen orders, authoritative pricing, stale-price rejection without partial changes, stock reservation/rollback, quantity/address validation, private chat, seller ownership, status progression, verified reviews, rating protection, and anonymous access. Its Auth records exist only inside the transaction and cannot be used to sign in.

Also run these app checks with two seller accounts and two customer accounts:

1. Seller A saves a kitchen and a meal with stock 1; Seller B saves a different kitchen and meal. Refresh the customer catalog.
2. Two customers attempt to purchase Seller A's last portion at almost the same time. Exactly one succeeds. Verify stock is 0 and only one new order exists. Use separate browser profiles/devices so the sessions are independent.
3. Submit a cart containing an available meal and an unavailable meal. Verify no order is created for either seller and no stock changes.
4. Change a meal's price after it enters a cart, before the customer's next refresh. Confirm checkout rejects the stale displayed price without any inventory/order changes, then refresh the cart and confirm again. Catalog updates happen through periodic/manual refresh; the server validates price and availability when checkout is confirmed.
5. Close a kitchen after a customer has added its meal. Checkout must fail without changing inventory.
6. Confirm each seller sees only their incoming orders; an unrelated customer cannot read another customer's orders or messages.
7. Advance an order through all four states. Confirm the customer can review only after delivery and cannot submit a second review.
8. Verify confirmation, recovery, session persistence, and sign-out on web and real Android/iOS devices.

No Supabase project credentials were provided during development. The migration and integration smoke test are supplied for execution in your project; live database, SMTP, SMS, and device callback checks have not been claimed as passed.

## 7. Optional phone login

The delivered login UI uses email/password. The phone number on a kitchen profile is a public business contact; it is not a verified Auth identity. Phone authentication requires additional UI and an SMS provider.

To add it, enable the Phone provider in Supabase Authentication, configure a supported SMS service with coverage for your intended users, and implement phone input plus OTP verification/resend states. Normalize phone numbers to E.164, including Mauritania's `+222` country code. The existing profile trigger supports phone-created users because it does not depend on email.

The Dart API flow is:

```dart
await client.auth.signInWithOtp(
  phone: phoneInE164,
  data: {'name': name, 'role': 'customer'},
);
await client.auth.verifyOTP(
  phone: phoneInE164,
  token: enteredCode,
  type: OtpType.sms,
);
```

For a sign-in-only form, set `shouldCreateUser: false`; use a separate registration path to collect the initial name/role. Changing OTP metadata later does not change `profiles.role`. Configure provider quotas, rate limits, and abuse protection before enabling SMS. See [Supabase phone login](https://supabase.com/docs/guides/auth/phone-login) and the [Flutter OTP reference](https://supabase.com/docs/reference/dart/auth-signinwithotp).

## 8. Integration boundaries

- **Payments:** checkout records an order for payment on receipt. No Bankily, Sedad, Masrivi, card processing, payment verification, or refunds are integrated. Those need provider credentials, trusted server endpoints, and signed webhook handling before presenting a paid status.
- **Delivery:** a delivery choice and address record the request; there is no courier dispatch, delivery pricing, or live courier tracking.
- **Media:** meals accept public HTTPS image URLs. No Storage bucket or upload policy is installed. If uploads are added, use owner-scoped object paths, size/type limits, and matching Storage RLS; never make the bucket writable by everyone.
- **Updates:** the app refreshes data while open. Push notifications and Supabase Realtime subscriptions are separate integrations; there is no requirement to enable a Realtime publication for this build.
- **Order lifecycle:** there is no cancellation/restocking/refund operation. Add a transactional server operation with state checks before exposing cancellation. Avoid deleting historical orders to simulate cancellation.
- **Retry behavior:** checkout is atomic but does not yet accept an idempotency key. If a network interruption hides a successful response, refresh orders before retrying. Add server idempotency before automatic checkout retries or payment processing.
- **Account deletion:** orders preserve purchase history through restrictive foreign keys. Deleting an Auth account with orders requires an explicit server-side retention/anonymization workflow, not a client table delete.
