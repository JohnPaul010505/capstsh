import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { MessageSquare, Star, X } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import KpiCard from '@/components/KpiCard'
import ListToolbar from '@/components/ListToolbar'
import { allTime, isAllTime, LIST_PRESETS, localEndIso, localStartIso, type Range } from '@/features/dashboard/lib/dateRange'
import { FeedbackTable, type FeedbackRow } from '../components/FeedbackTable'

export default function CoachFeedbackPage() {
  // Opened on all-time, so the landing render is the same 50 most recent rows
  // and the same average rating this page has always shown. See `usePredictions`
  // for why an all-time window deliberately sends NO bounds rather than the
  // dataset's outer edges: it keeps the seeded totals intact.
  const [range, setRange] = useState<Range>(() => allTime())
  const narrow = !isAllTime(range)
  const from = narrow ? localStartIso(range.start) : undefined
  const to = narrow ? localEndIso(range.end) : undefined

  // The id of the row whose detail drawer is open, or null when none is.
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['coach-feedback', from, to],
    queryFn: async () => {
      // `created_at` is a timestamptz, so the bounds are local-midnight ISO
      // instants - not bare 'YYYY-MM-DD' strings, which would read as UTC and
      // clip the first and last days of the window.
      //
      // The embedded profiles join carries the member's `code` and `email` for
      // the detail drawer. `member_comment` is picked up by the `*` and read by
      // the drawer too, so the whole view stays one query - the drawer resolves
      // its row out of this same array rather than re-fetching by id.
      let q = supabase
        .from('trainer_feedback')
        .select('*, member:profiles!trainer_feedback_member_id_fkey(full_name, code, email), trainer:profiles!trainer_feedback_trainer_id_fkey(full_name)')
      if (from) q = q.gte('created_at', from)
      if (to) q = q.lte('created_at', to)
      const { data } = await q
        .order('created_at', { ascending: false })
        .limit(50)
      return data ?? []
    },
  })

  const rated = (data ?? []).filter((f: any) => f.rating != null)
  const average = rated.length
    ? rated.reduce((sum: number, f: any) => sum + f.rating, 0) / rated.length
    : null

  // The open row, resolved from the fetched page rather than re-fetched by id.
  //
  // A second query would be one more round trip to read columns this array
  // already holds, and it would also introduce a loading state the drawer has no
  // way to show - the row would briefly be unavailable on every open. Resolving
  // locally also makes the drawer self-healing: change the date range while it
  // is open and the row leaves the set, so `selected` goes null and the drawer
  // closes instead of showing a stale row the table no longer contains.
  const selected = (data ?? []).find((f: FeedbackRow) => f.id === selectedId) ?? null

  return (
    /*
      A full-height flex column, the same shell the QR page uses. `main` is
      `flex-1 overflow-hidden`, so an auto-height stack under it simply runs off
      the bottom of the viewport - which is exactly what the old `space-y-3`
      page did. The table below is the `flex-1` child, so `useFitRows` has a real
      height budget to measure a whole page of rows from.
    */
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/*
        HALF WIDTH, LEFT-ANCHORED, AND ON THE PICKER'S OWN ROW - and a real KPI
        card.

        The average used to be one full-width strip of "4.1  stars  average
        member rating - 35 of 50 feedback entries rated", a single line with three
        unrelated pieces of text on it, stretched across 1,690px with 1,600px of
        empty card to the right of it. It is now the same component the four
        dashboard KPI cards use: icon tile, title, value, sub-line.

        Centring it was the wrong correction, though, and the reason is
        positional rather than typographic. A half-width card centred on a
        1,690px panel has ~400px of empty panel on BOTH sides, and its date
        filter stranded alone on the row below - so the card had no relationship
        to anything and read as floating in the middle of the page. Centring
        only works for something that is genuinely alone on its row, and this is
        not alone: the window picker describes the same slice of feedback the
        rating is computed from. So the card is anchored left and the picker sits
        at the right end of the SAME row, which is the shape every other list
        page here already uses - subject on the left, filter on the right. The
        52rem ceiling stays so it still agrees with the Member Distribution card
        instead of stretching the full panel.

        Both the card and the table read through the same `range`, so they can
        never disagree about which slice of feedback they are describing.
      */}
      <ListToolbar
        left={
          <div className="w-full lg:w-1/2 lg:max-w-[52rem] min-w-0">
        <KpiCard
          title="Average Member Rating"
          value={average != null ? average.toFixed(1) : '—'}
          stars={average}
          sub={`${rated.length} of ${(data ?? []).length} feedback entries rated`}
          icon={Star}
          tone="amber"
          isLoading={isLoading}
        />
          </div>
        }
        range={range}
        onRangeChange={setRange}
        presets={LIST_PRESETS}
      />
      <FeedbackTable
        data={data ?? []}
        isLoading={isLoading}
        onRowClick={row => setSelectedId(row.id)}
      />
      {selected && (
        <FeedbackDetailDrawer feedback={selected} onClose={() => setSelectedId(null)} />
      )}
    </div>
  )
}

/**
 * One piece of feedback in full, in the same right-side drawer the Renewal queue
 * uses on the Memberships page.
 *
 * The list row truncates the note at 22rem because its cells are measured to a
 * 45px line, so the drawer is the only place the whole sentence is readable. It
 * is READ-ONLY on purpose: the member owns the comment and writes it from the
 * mobile app, and an admin edit box here would be a second writer racing the
 * member's own update on the same column.
 */
function FeedbackDetailDrawer({ feedback, onClose }: { feedback: FeedbackRow; onClose: () => void }) {
  const memberName = feedback.member?.full_name ?? feedback.profiles?.full_name ?? 'Unknown'
  const comment = (feedback.member_comment ?? '').trim()
  const commentedAt = feedback.member_commented_at
    ? new Date(feedback.member_commented_at).toLocaleDateString('en-US', {
        weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
      })
    : null

  const field = (label: string, body: React.ReactNode) => (
    <div>
      <label className="block text-xs font-medium text-fg-muted uppercase tracking-wide mb-1">{label}</label>
      {body}
    </div>
  )

  return (
    // Backdrop click closes; the panel stops propagation so a click inside it -
    // including on the long feedback text being selected - does not dismiss.
    <div className="fixed inset-0 bg-black/60 z-50" onClick={onClose}>
      <div
        className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line"
        onClick={e => e.stopPropagation()}
        role="dialog"
        aria-label="Feedback details"
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-line shrink-0">
          <h3 className="text-lg font-semibold text-fg-strong">Feedback Details</h3>
          <button
            onClick={onClose}
            aria-label="Close feedback details"
            className="text-fg-muted hover:text-fg-strong transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">
          {field('Member', (
            <div>
              <p className="text-sm font-medium text-fg-strong">{memberName}</p>
              {feedback.member?.code != null && (
                <p className="text-xs font-mono text-fg-strong mt-0.5">{feedback.member.code}</p>
              )}
              {feedback.member?.email != null && (
                <p className="text-xs text-fg-muted mt-0.5">{feedback.member.email}</p>
              )}
            </div>
          ))}

          {field('Trainer', (
            <p className="text-sm text-fg">{feedback.trainer?.full_name ?? '—'}</p>
          ))}

          {/*
            `whitespace-pre-wrap` so the trainer's own line breaks survive: this
            text is written by hand on a phone, and a hard-wrapped line would
            otherwise be reflowed into one and change how it reads.
          */}
          {field('Feedback', (
            <p className="text-sm text-fg bg-overlay-8 rounded-lg px-3 py-2 border border-line whitespace-pre-wrap">
              {feedback.content}
            </p>
          ))}

          {field('Rating', feedback.rating == null
            ? <p className="text-sm text-fg-faint">Not rated</p>
            : (
              <span className="inline-flex items-center gap-1 text-sm">
                <span className="text-[#FFC107]">
                  {'★'.repeat(feedback.rating)}
                  <span className="text-fg-faint">{'★'.repeat(5 - feedback.rating)}</span>
                </span>
                <span className="text-fg-muted">{feedback.rating}/5</span>
              </span>
            ))}

          {field('Date', (
            <p className="text-sm text-fg">
              {new Date(feedback.created_at).toLocaleDateString('en-US', {
                weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
              })}
            </p>
          ))}

          {/*
            The member's own comment, or the absence of one stated plainly.
            An explicit "No comment" is better than hiding the field: the admin
            is looking at this drawer to find out whether the member replied, and
            a section that silently isn't there reads as "not loaded yet".
          */}
          {field('Member Comment', comment === ''
            ? <p className="text-sm text-fg-faint">No comment from the member</p>
            : (
              <div className="bg-overlay-5 rounded-lg px-3 py-2 border border-line">
                <p className="flex items-start gap-2 text-sm text-fg whitespace-pre-wrap">
                  <MessageSquare className="w-3.5 h-3.5 text-fg-muted shrink-0 mt-0.5" />
                  {comment}
                </p>
                {commentedAt && (
                  <p className="text-xs text-fg-muted mt-1.5 pl-6">{commentedAt}</p>
                )}
              </div>
            ))}
        </div>
      </div>
    </div>
  )
}
