import { client } from './seed/lib/common.mjs'

const apply = process.argv.includes('--apply')

async function readProfiles(role) {
  const { data, error } = await client
    .from('profiles')
    .select('id, role, code, created_at')
    .eq('role', role)
    .order('created_at', { ascending: true })
  if (error) throw error
  return data ?? []
}

const monthOf = createdAt => {
  const date = new Date(createdAt)
  if (Number.isNaN(date.getTime())) throw new Error(`Invalid created_at: ${createdAt}`)
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit',
  }).formatToParts(date)
  const part = type => parts.find(item => item.type === type)?.value
  return `${part('year')}-${part('month')}`
}

const makeCode = profile => {
  const rawSequence = profile.code?.match(/(\d+)$/)?.[1]
  if (!rawSequence) throw new Error(`Cannot preserve sequence for ${profile.id} (${profile.code})`)
  const sequence = String(Number(rawSequence))
  const roleMarker = profile.role === 'member' ? 'M' : 'T'
  const width = profile.role === 'member' ? 3 : 4
  return `${monthOf(profile.created_at)}-${roleMarker}${sequence.padStart(width, '0')}`
}

const profiles = [
  ...await readProfiles('member'),
  ...await readProfiles('trainer'),
]
const changes = profiles
  .map(profile => ({ id: profile.id, role: profile.role, oldCode: profile.code, newCode: makeCode(profile) }))
  .filter(profile => profile.oldCode !== profile.newCode)

console.log(`${apply ? 'Applying' : 'Preview'}: ${changes.length} of ${profiles.length} member/trainer codes need updating.`)
console.log(changes.slice(0, 8))
if (!apply) {
  console.log('Run with --apply to update the database.')
  process.exit(0)
}

let updated = 0
for (let offset = 0; offset < changes.length; offset += 20) {
  const chunk = changes.slice(offset, offset + 20)
  const results = await Promise.all(chunk.map(({ id, newCode }) =>
    client.from('profiles').update({ code: newCode }).eq('id', id).select('id').single(),
  ))
  const failed = results.find(result => result.error)
  if (failed) throw failed.error
  updated += results.length
  console.log(`Updated ${updated}/${changes.length}`)
}

const finalProfiles = [
  ...await readProfiles('member'),
  ...await readProfiles('trainer'),
]
const invalid = (finalProfiles ?? []).filter(profile =>
  profile.role === 'member'
    ? !/^\d{4}-\d{2}-M\d{3,}$/.test(profile.code ?? '')
    : !/^\d{4}-\d{2}-T\d{4,}$/.test(profile.code ?? ''),
)
if (invalid.length) throw new Error(`${invalid.length} member/trainer codes do not match the new format.`)
console.log(`Complete: updated ${updated}; all ${finalProfiles.length} member/trainer codes match the new format.`)
