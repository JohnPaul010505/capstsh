const { createClient } = require('@supabase/supabase-js');
const url = process.env.VITE_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}
const client = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

(async () => {
  const { data: profiles } = await client
    .from('profiles')
    .select('id, code')
    .eq('code', 'M002')
    .limit(1);
  const profile = profiles && profiles[0];
  if (!profile) {
    console.error('M002 not found');
    process.exit(1);
  }
  const memberId = profile.id;
  const start = '2026-08-06T00:00:00+08:00';
  const end = '2026-08-07T00:00:00+08:00';
  const { data: logs, error } = await client
    .from('workout_logs')
    .select('id, proof_url, logged_at')
    .eq('member_id', memberId)
    .gte('logged_at', start)
    .lt('logged_at', end);

  if (error) {
    console.error('fetch error', error);
    process.exit(1);
  }

  console.log('Aug6 workout_logs:', logs.length);
  const urls = (logs || []).map((l) => l.proof_url).filter(Boolean);
  console.log('proof_urls:', JSON.stringify(urls, null, 2));

  const paths = urls
    .map((u) => {
      try {
        const uu = new URL(u);
        return uu.pathname.replace(/^\/+/, '');
      } catch {
        return u;
      }
    })
    .filter(Boolean);

  console.log('storage paths:', JSON.stringify(paths, null, 2));
  if (paths.length) {
    const { data: storage, error: sErr } = await client.storage
      .from('proofs')
      .remove(paths);
    console.log('storage remove', storage, sErr);
  } else {
    console.log('no proof urls to remove');
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
