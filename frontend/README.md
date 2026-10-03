# Frontend setup

The React/Vite frontend requires Node.js 20.19 or newer and npm. From this directory:

```sh
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite proxies `/api` requests to the Rails API at `http://localhost:3000` by default. Set `API_PROXY_TARGET` before starting Vite to use a different backend URL.

Run the frontend checks with:

```sh
npm test
npm run lint
npm run build
```

For the complete local setup, including the Rails backend and PostgreSQL, see the [repository setup guide](../README.md).
