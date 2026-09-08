import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const supabaseUrl = process.env.VITE_SUPABASE_URL || 'https://itxetmemsztydtngaqjx.supabase.co';
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!serviceRoleKey) {
  console.error('Missing SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const catalogPath = resolve(__dirname, '..', '..', 'mobile', 'fitness_app', 'lib', 'features', 'member', 'workout', 'data', 'met_exercise_catalog.dart');
const content = readFileSync(catalogPath, 'utf-8');

const exercises = [];
const categoryRegex = /'([^']+)':\s*\[/g;
let categoryMatch;

const categorySections = [];
while ((categoryMatch = categoryRegex.exec(content)) !== null) {
  const category = categoryMatch[1];
  const startIdx = categoryMatch.index + categoryMatch[0].length;
  let braceCount = 1;
  let endIdx = startIdx;
  while (braceCount > 0 && endIdx < content.length) {
    if (content[endIdx] === '[') braceCount++;
    else if (content[endIdx] === ']') braceCount--;
    endIdx++;
  }
  const sectionContent = content.slice(startIdx, endIdx - 1);
  const exerciseRegex = /MetExercise\('([^']+)',\s*([\d.]+),\s*'[^']+'\)/g;
  let exMatch;
  while ((exMatch = exerciseRegex.exec(sectionContent)) !== null) {
    const name = exMatch[1];
    const met = parseFloat(exMatch[2]);
    exercises.push({ name, category, met_value: met });
  }
}

console.log(`Found ${exercises.length} exercises to seed`);

async function seed() {
  const rows = exercises.map(e => ({
    ...e,
    is_ai_estimated: false,
    is_verified: true,
  }));

  const { error } = await supabase.from('met_exercises').insert(rows);

  if (error) {
    console.error('Seed failed:', error);
    process.exit(1);
  }

  console.log(`Successfully seeded ${rows.length} exercises`);
}

seed();