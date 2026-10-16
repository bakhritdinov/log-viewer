# LogViewer on the phone (PWA)

The browser version of LogViewer 3 is published with every release at

**https://bakhritdinov.github.io/log-viewer/**

Open it in Chrome (Android) or Safari (iOS) and install it on the home screen:
the app offers it after the second successful search (on iOS: Share → Add to
Home Screen). It then opens full screen, without the browser, and starts
offline from its cache; a new version is announced with "A new version is
available · Update".

## What the phone needs

- **The network to Grafana.** The page comes from GitHub, but the queries go
  from the phone straight to your Grafana. If Grafana is reachable only
  through the VPN, the VPN has to be on — as on the desktop.
- **Grafana must allow the PWA's origin (CORS).** A browser sends a request
  to another site only when that site allows it. Without it the app shows
  "The browser blocked the request" with a button that copies the
  instructions below for DevOps.

Logins, passwords and tokens are kept in the browser's storage of this site on
the phone and are sent only to your Grafana.

## For DevOps: CORS in front of Grafana

Grafana itself has no CORS settings for its API; allow the origin in the
reverse proxy in front of it. For nginx (the same block the app copies):

```nginx
# nginx in front of Grafana: allow the LogViewer PWA to call the query API
location /api/ {
    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin "https://bakhritdinov.github.io" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
        add_header Access-Control-Max-Age 86400 always;
        return 204;
    }
    add_header Access-Control-Allow-Origin "https://bakhritdinov.github.io" always;
    add_header Access-Control-Allow-Credentials "true" always;
    proxy_pass http://grafana;
}
```

- The preflight (`OPTIONS`) is answered by nginx without authentication — the
  browser never sends credentials with it.
- Allow exactly this origin, not `*`: the requests carry an `Authorization`
  header.
- Repeat for every Grafana the phones use (DEV, PROD, …).

Check from a desktop browser's console on the PWA page:

```js
fetch("https://<grafana>/api/health").then(r => console.log(r.status))
```

`200` means the origin is allowed; a CORS error in the console means it is not.

## Publishing

The release workflow (`.github/workflows/build.yml`, job `publish-pwa`)
builds the WebAssembly app on a `v*` tag and deploys it to GitHub Pages. Once,
in the repository: **Settings → Pages → Build and deployment → Source:
GitHub Actions**. The same files are attached to every release as
`LogViewer-PWA.zip` for anyone who wants to host the PWA on their own server
(then, on the same domain as Grafana, CORS is not needed).
