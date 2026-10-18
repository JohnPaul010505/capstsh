# Public enrollment deployment

The standalone enrollment site lives in `enrollment/`. Deploy it as its own Vercel project so a prospective member can open the form from any network without needing the admin computer or the admin API to be online.

## Deploy the enrollment site

1. In Vercel, import the `capstsh` GitHub repository as a new project.
2. Set **Root Directory** to `enrollment`.
3. Select **Vite**. Use `npm run build` for Build Command and `dist` for Output Directory. Leave Install Command as `npm install`.
4. Add these Production environment variables:
   - `SUPABASE_URL` = `https://itxetmemsztydtngaqjx.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = the project’s service role/secret key from Supabase Project Settings → API Keys. Store this only as a server environment variable; never prefix it with `VITE_`.
5. Deploy and open the Vercel URL ending in `/enroll`. Submit a test application and confirm it appears in the admin QR page’s Pending tab.

The page sends form submissions to its own `/api/enroll` Vercel Function. That function validates the fields and inserts a `pending` row into the existing Supabase `enrollments` table. It does not expose the service role key to the browser.

## Point the admin QR at the public page

1. Copy the deployed enrollment URL, for example `https://capstsh-enrollment.vercel.app/enroll`.
2. In the existing admin Vercel project, add `VITE_ENROLLMENT_URL` with that full URL for Production (and Preview if wanted).
3. Redeploy the admin project so its QR code is rebuilt with the public URL.
4. Scan the QR from a phone on mobile data or another Wi-Fi network. It should open the public form; submissions should show in the admin Pending tab.

No database migration is needed. Keep `SUPABASE_SERVICE_ROLE_KEY` off the admin frontend and out of source control.
