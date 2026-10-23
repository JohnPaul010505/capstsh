Forecasting runs from readable JavaScript source in `admin/server/prediction-service.js`.
It shares regression and retention calculations with the admin API fallback in
`admin/server/predictionEngine.js`. It uses the existing server-only Supabase
configuration from `admin/.env` and listens only on localhost port 8001.

From `admin`, run `npm run dev` to start the API, forecast service, and web client.
To start forecasting separately, run `npm run dev:ai`.

The former Python source files are absent from this checkout. The compiled
Python artifacts are not used by the forecast service. Forecasts use statistical
regression and attendance-based scoring; they do not call a language model.
