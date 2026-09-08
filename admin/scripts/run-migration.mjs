import { config } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

config({ path: resolve(__dirname, '..', '.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL || 'https://itxetmemsztydtngaqjx.supabase.co';
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const projectRef = 'itxetmemsztydtngaqjx';

if (!serviceRoleKey) {
  console.error('Missing SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

import { readFileSync } from 'fs';
const migrationPath = resolve(__dirname, '..', '..', 'supabase', 'migrations', '0020_met_exercises_catalog.sql');
const migrationSQL = readFileSync(migrationPath, 'utf-8');

// Split by semicolon and execute each statement
const statements = migrationSQL
  .split(';')
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.startsWith('--'));

async function runQuery(sql) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({ query: sql }),
  });
  
  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`HTTP ${response.status}: ${errText}`);
  }
  
  return response.json();
}

async function runMigration() {
  console.log('Running migration 0020_met_exercises_catalog.sql...');
  
  for (const stmt of statements) {
    if (stmt.trim().length === 0) continue;
    console.log(`Executing: ${stmt.substring(0, 80)}...`);
    
    try {
      await runQuery(stmt);
      console.log('OK');
    } catch (e) {
      console.error(`Failed: ${e.message}`);
      console.error(`Statement: ${stmt.substring(0, 200)}`);
    }
  }
  console.log('Migration complete');
}

runMigration();