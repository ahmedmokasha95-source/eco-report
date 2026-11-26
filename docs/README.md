# Balagh web

Static site served by GitHub Pages from `/docs`. Same Supabase backend as the app (`lib/config.dart`).
- `index.html`: public page to submit a report (no login).
- `admin.html`: admin dashboard (same usernames/passwords as the app, admins only).
Only the public publishable key is in `config.js`. Never put a secret key here.
