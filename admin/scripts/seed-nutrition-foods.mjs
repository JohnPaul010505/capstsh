import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import * as XLSX from 'xlsx'

const __dirname = dirname(fileURLToPath(import.meta.url))
const envPath = resolve(__dirname, '..', '.env')
const envContent = readFileSync(envPath, 'utf-8')
const urlMatch = envContent.match(/VITE_SUPABASE_URL=(.+)/)
const keyMatch = envContent.match(/SUPABASE_SERVICE_ROLE_KEY=(.+)/)
if (!urlMatch || !keyMatch) {
  console.error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in admin/.env')
  process.exit(1)
}
const supabaseUrl = urlMatch[1].trim()
const serviceRoleKey = keyMatch[1].trim()
const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const usage = () => {
  console.log('Usage: node seed-nutrition-foods.mjs <path-to-filled-template.xlsx>')
  console.log('The XLSX should have columns: food_name, aliases, category, serving_label, serving_size_g, calories_kcal, protein_g, carbs_g, fat_g, source')
  process.exit(1)
}

const xlsxPath = process.argv[2]
if (!xlsxPath) usage()

const workbook = XLSX.readFile(xlsxPath)
const sheet = workbook.Sheets[workbook.SheetNames[0]]
const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' })

const insert = []
for (const row of rows) {
  const foodName = String(row.food_name || row.Food_name || '').trim()
  if (!foodName || foodName === 'Food name' || foodName.toLowerCase().includes('example')) continue
  const aliasesRaw = String(row.aliases || '').trim()
  const aliases = aliasesRaw ? aliasesRaw.split(',').map(a => a.trim()).filter(Boolean) : []
  const category = String(row.category || '').trim()
  const servingLabel = String(row.serving_label || row.serving_label || '').trim()
  const servingSizeG = parseFloat(row.serving_size_g)
  const caloriesKcal = parseFloat(row.calories_kcal)
  const proteinG = parseFloat(row.protein_g)
  const carbsG = parseFloat(row.carbs_g)
  const fatG = parseFloat(row.fat_g)
  const source = String(row.source || 'DOST-FNRI PhilFCT').trim()
  if (isNaN(servingSizeG) || isNaN(caloriesKcal) || isNaN(proteinG) || isNaN(carbsG) || isNaN(fatG)) {
    console.warn(`Skipping ${foodName}: missing numeric nutrition values`)
    continue
  }
  insert.push({
    food_name: foodName,
    aliases,
    category,
    serving_label: servingLabel,
    serving_size_g: servingSizeG,
    calories_kcal: caloriesKcal,
    protein_g: proteinG,
    carbs_g: carbsG,
    fat_g: fatG,
    source,
  })
}

if (insert.length === 0) {
  console.error('No valid rows found in XLSX')
  process.exit(1)
}

async function run() {
  const { data, error } = await client
    .from('nutrition_foods')
    .upsert(insert, { onConflict: 'food_name' })
  if (error) {
    console.error('Seed error:', error)
    process.exit(1)
  }
  console.log(`Seeded ${insert.length} foods into nutrition_foods`)
}
run()
