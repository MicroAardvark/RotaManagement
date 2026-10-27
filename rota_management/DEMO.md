# Portfolio demo

A demo build of Rota Manager runs entirely in the browser. It never contacts a server, and it holds no real data: every staff member, client, address and phone number is made up.

## How it works

`ApiService` sends every request through a single `http.Client`. In a demo build (`--dart-define=DEMO=true`) that client is `DemoBackend`, an in-memory fake of the Node/Express API, instead of the browser's HTTP client.

Because the swap happens below `ApiService`, every screen, model and error message runs exactly as it does in production. Only the transport changes.

| File | Purpose |
| --- | --- |
| `lib/demo/demo_mode.dart` | The `isDemo` flag, read from `--dart-define=DEMO=true` |
| `lib/demo/demo_backend.dart` | Fake API: the same routes, status codes, JSON shapes and draft/publish rules as `routes/*.js` on the server |
| `lib/demo/demo_seed.dart` | Made-up company, staff, clients, job types and six weeks of shifts, generated around today's date |
| `lib/demo/demo_widgets.dart` | The "Demo" banner and the one-click Manager / Employee login panel |
| `test/demo_backend_test.dart` | Checks the fake API against the app's own models and the server's rules |
| `build_demo.ps1` | Tests and builds the demo, then zips it for upload |

The only changes outside `lib/demo/` are:

- `ApiService` picks `DemoBackend` as its client in demo builds.
- `main.dart` adds the banner and shows the login panel on the welcome page.
- `login.dart` shows the login panel above the login form.

A normal build (without `DEMO=true`) behaves exactly as before.

### The demo data

The seed is generated around today's date, so the rota never looks out of date:

- three past weeks, this week and next week are published
- next week has two shifts changed since publishing, plus two new drafts, so **Publish** has something to send
- the week after next is entirely in draft

Shifts use a fixed random seed, so every visitor sees the same rota. Changes last until the page is refreshed.

### Demo accounts

| View | Email | Password |
| --- | --- | --- |
| Manager | alex.morgan@example.com | demo1234 |
| Employee | jamie.patel@example.com | demo1234 |

Visitors don't need these, because the welcome and login pages have one-click buttons.

### What's turned off

- **Photo uploads** show a "turned off in the demo" message.
- **Password changes** show a "turned off in the demo" message.
- **Invites, publish emails, password resets and issue reports** all report success but send nothing.
- **Staff added in the demo** can't log in, because they would normally set a password from their invite email.

## Building

From PowerShell in `rota_management`:

```powershell
.\build_demo.ps1
```

This runs the demo tests, builds to `build\web-demo` with a base href of `/rota-demo/`, and creates `build\rota-demo.zip`.

To build for the root of its own subdomain (for example `rota-demo.microaardvark.co.uk`), run this instead:

```powershell
.\build_demo.ps1 -BaseHref "/"
```

To run the demo locally while working on it:

```powershell
flutter run -d chrome --dart-define=DEMO=true
```

## Deploying to cPanel

1. In File Manager, open the document root of `portfolio.microaardvark.co.uk` and create a folder called `rota-demo`.
2. Upload `build\rota-demo.zip` into that folder, then right-click it and choose **Extract**. Delete the zip afterwards.
3. Open `https://portfolio.microaardvark.co.uk/rota-demo/` to check it loads.
4. Link to it from the portfolio page.

The app uses hash URLs (`/rota-demo/#/rota`), so no `.htaccess` rewrite rules are needed.

When you redeploy, delete the old files first. Flutter's service worker can cache an old build, so check in a private window or do a hard refresh.

## Keeping the demo up to date

This branch only adds files and makes small additions to `api_service.dart`, `main.dart` and `login.dart`, so merging new work in from `additions` should be painless:

```powershell
git checkout demo
git merge additions
flutter test test/demo_backend_test.dart
```

When you add or change an API route, add the matching route to `DemoBackend`. Otherwise that screen will show the backend's "Not found" error in the demo. The tests catch JSON shape mismatches for the routes they cover.
