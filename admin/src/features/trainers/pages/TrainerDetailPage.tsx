import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { usePagedTable, useResetPageOnChange } from '@/lib/pagedTable'
import { useFitRowHeight } from '@/hooks/useFitRows'
import PeopleTable, { type PeopleColumn } from '@/components/PeopleTable'
import PaginationFooter from '@/components/PaginationFooter'
import { ArrowLeft, Mail, Phone, Users, UserPlus, X, Search, Trash2 } from 'lucide-react'
import { useUpdateTrainer } from '../hooks/useTrainers'

/**
 * TEN rows a page, not the app-wide fifteen.
 *
 * This is deliberately a local constant and NOT `LIST_PAGE_SIZE`: the detail page
 * shows one trainer's members and one trainer's feedback, and fifteen of either
 * is more than the eye can scan before losing the thread - the fifteen-row lists
 * are whole-gym rosters where the reader is looking for one person in many, which
 * is the opposite job. So the detail page gets its own, smaller contract, and the
 * shared fifteen is left alone for the pages that were built around it.
 *
 * Ten also divides the measured row height more evenly across the same card:
 * each row gets ~1.5x the vertical space it had at fifteen, so the name/email
 * stack reads comfortably instead of being crammed.
 */
const DETAIL_PAGE_SIZE = 10

export default function TrainerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const updateTrainer = useUpdateTrainer()
  const [showAssignModal, setShowAssignModal] = useState(false)
  const [memberSearch, setMemberSearch] = useState('')

  /**
   * Editable contact + specialty. `editing` toggles inputs; `form` is seeded
   * from the trainer on entry so a cancelled edit never touches the server.
   */
  const [editing, setEditing] = useState(false)
  const [form, setForm] = useState({ email: '', phone: '', specialty: '' })
  const startEdit = () => {
    if (!trainer) return
    setForm({ email: trainer.email ?? '', phone: trainer.phone ?? '', specialty: trainer.specialty ?? '' })
    setEditing(true)
  }
  const saveEdit = () => {
    if (!id) return
    updateTrainer.mutate({ id, ...form }, { onSuccess: () => setEditing(false) })
  }
  /**
   * "Assigned Members" and "Recent Feedback" used to be two cards stacked on one
   * page. Twelve assigned members is a dozen rows of table, and every one of
   * them pushed the feedback card further down until it started below the fold -
   * what an admin saw was the members list and a cut-off heading, not the
   * feedback. They are two different questions about a trainer ("who does this
   * person coach?" and "how is this person doing?"), so they are two tabs: the
   * tab strip picks the question and the whole content area answers it.
   */
  const [section, setSection] = useState<'members' | 'feedback'>('members')

  /**
   * Pagination - one page number per tab.
   *
   * The tabs are two independent result sets with two different totals, so each
   * carries its own page: page 2 of the members list must not be carried into a
   * feedback list that only has one page. Both show DETAIL_PAGE_SIZE (10) rows a
   * page under the shared PaginationFooter, so a reader who has learned one list
   * has learned this one - only the density differs from the fifteen-row lists.
   */
  const [membersPage, setMembersPage] = useState(1)
  const [feedbackPage, setFeedbackPage] = useState(1)
  // Switching trainers starts both lists at page 1: a page number from the
  // previous trainer means nothing for the next one.
  useResetPageOnChange(setMembersPage, id)
  useResetPageOnChange(setFeedbackPage, id)
  // Ten rows is the contract; the height of one of them is what gives. Measuring
  // against TEN (not fifteen) is what keeps the card exactly full - the same
  // available height divided by a larger count would leave the bottom third
  // empty on every page instead of just the last one.
  const [scrollRef, rowHeight] = useFitRowHeight<HTMLDivElement>({ count: DETAIL_PAGE_SIZE })

  const { data: trainer } = useQuery({
    queryKey: ['trainer', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .eq('role', 'trainer')
        .single()
      return data
    },
  })

  /**
   * Assigned Members, paged server-side like every other list in the app.
   *
   * The old query fetched every active assignment at once and rendered them
   * all: a trainer with dozens of members produced a table that ran past the
   * fold with no pager to reach the rest. PostgREST also cannot order by an
   * embedded column, so the sort is on `assigned_at` (this table has no
   * `created_at`) with `id` as the unique tiebreak that keeps a row from
   * straddling a page boundary.
   *
   * `enabled: !!id` is load-bearing: usePagedTable skips an eq whose value is
   * undefined, so a missing route param would drop the trainer_id predicate
   * and page through EVERY assignment in the table.
   */
  const {
    rows: assignedMembers,
    isLoading: membersLoading,
    total: assignedTotal,
    pageCount: memberPageCount,
  } = usePagedTable<any>({
    table: 'trainer_assignments',
    select: 'id, member_id, assigned_at, profiles!trainer_assignments_member_id_fkey(full_name, email, phone)',
    orderBy: [{ column: 'assigned_at', ascending: true }, { column: 'id', ascending: true }],
    page: membersPage,
    pageSize: DETAIL_PAGE_SIZE,
    eq: { trainer_id: id, status: 'active' },
    enabled: !!id,
  })

  /**
   * Recent Feedback, likewise paged. The old query took `.limit(10)` rows and
   * the tab badge printed that cap as if it were the total - a trainer with 40
   * rows wore a "10". Here the badge, the footer and the table all read the
   * same real count.
   */
  const {
    rows: recentFeedback,
    isLoading: feedbackLoading,
    total: feedbackTotal,
    pageCount: feedbackPageCount,
  } = usePagedTable<any>({
    table: 'trainer_feedback',
    select: 'id, content, rating, created_at, profiles!trainer_feedback_member_id_fkey(full_name)',
    orderBy: [{ column: 'created_at', ascending: false }, { column: 'id', ascending: false }],
    page: feedbackPage,
    pageSize: DETAIL_PAGE_SIZE,
    eq: { trainer_id: id },
    enabled: !!id,
  })

  /**
   * Snap the page back when the result set shrinks under it.
   *
   * Unassigning the last member on the last page drops the total by one and
   * makes the current page out of range - the footer would claim "page 2 of 1"
   * over an empty table. Clamping only for display is not enough: the stale
   * state would come back to life the moment a new assignment pushed the total
   * up again and jump the reader to a page they never asked for. So the state
   * itself is snapped, and both the query and the footer read the clamped
   * value while the refetch settles.
   */
  const safeMembersPage = Math.min(membersPage, memberPageCount)
  const safeFeedbackPage = Math.min(feedbackPage, feedbackPageCount)
  // Gated on !isLoading: while a freshly keyed page is still settling, the
  // pageCount can read 1, and an ungated clamp reads that as past the end and
  // snaps the new page straight back to 1 - the Next arrow would silently do
  // nothing. A real shrink (last row of the last page unassigned) settles
  // before it clamps, so it still lands.
  useEffect(() => {
    if (!membersLoading && membersPage !== safeMembersPage) setMembersPage(safeMembersPage)
  }, [membersLoading, membersPage, safeMembersPage])
  useEffect(() => {
    if (!feedbackLoading && feedbackPage !== safeFeedbackPage) setFeedbackPage(safeFeedbackPage)
  }, [feedbackLoading, feedbackPage, safeFeedbackPage])

  /**
   * The header rating summary over ALL of this trainer feedback.
   *
   * It used to average whatever rows happened to be fetched - first the whole
   * list, then the `.limit(10)` slice - so the number described a sample, not
   * the trainer. This selects only the `rating` column for the whole result
   * set (the table is ~1,000 rows in total) and averages client-side.
   */
  const { data: ratings } = useQuery({
    queryKey: ['trainer-feedback-ratings', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_feedback')
        .select('rating')
        .eq('trainer_id', id)
      return (data ?? []).map(r => r.rating as number | null)
    },
    enabled: !!id,
  })
  const ratedRatings = (ratings ?? []).filter((r): r is number => r != null)
  const avgRating = ratedRatings.length > 0
    ? ratedRatings.reduce((sum, r) => sum + r, 0) / ratedRatings.length
    : null

  const { data: unassignedMembers } = useQuery({
    queryKey: ['unassigned-members', id],
    queryFn: async () => {
      // The FULL set of assigned member ids, fetched here rather than read off
      // the paged table above: that table holds one page of 15, so filtering
      // the drawer against it would offer every already-assigned member from
      // page 2 onwards as if they were still free. Ids and profiles are read
      // in one query so the two cannot disagree while the drawer is open.
      const { data: assignments } = await supabase
        .from('trainer_assignments')
        .select('member_id')
        .eq('trainer_id', id)
        .eq('status', 'active')
      const assignedIds = new Set((assignments ?? []).map(a => a.member_id))
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, code')
        .eq('role', 'member')
        .order('full_name')
      return (data ?? []).filter(m => !assignedIds.has(m.id))
    },
    enabled: showAssignModal,
  })

  const assignMutation = useMutation({
    mutationFn: async (memberId: string) => {
      const res = await fetch('/api/assign-trainer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ trainer_id: id, member_id: memberId }),
      })
      if (!res.ok) throw new Error('Failed to assign')
      return res.json()
    },
    onSuccess: () => {
      // The old trainer-members key was UNPAGED. The table, the stat card and
      // the tab badge now take their totals from the paged query, so that is
      // the key (matched by prefix) that has to be invalidated.
      queryClient.invalidateQueries({ queryKey: ['trainer_assignments', 'paged'] })
      queryClient.invalidateQueries({ queryKey: ['unassigned-members', id] })
      setShowAssignModal(false)
    },
  })

  const unassignMutation = useMutation({
    mutationFn: async (assignmentId: string) => {
      const res = await fetch('/api/unassign-trainer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ assignment_id: assignmentId }),
      })
      if (!res.ok) throw new Error('Failed to unassign')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['trainer_assignments', 'paged'] })
      queryClient.invalidateQueries({ queryKey: ['unassigned-members', id] })
    },
  })

  // Declared after the mutations that the action cell calls. Same shape as the
  // list pages: plain cell renderers, with the shared PeopleTable supplying the
  // `#` column, the measured row height and the footer around them.
  const memberColumns: PeopleColumn<any>[] = [
    { key: 'name', header: 'Name', render: a => <span className="font-medium text-fg-strong">{a.profiles?.full_name}</span> },
    { key: 'email', header: 'Email', render: a => a.profiles?.email },
    { key: 'phone', header: 'Phone', render: a => a.profiles?.phone || '—' },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: a => (
        <button
          type="button"
          onClick={e => { e.stopPropagation(); unassignMutation.mutate(a.id) }}
          disabled={unassignMutation.isPending}
          title="Remove assignment"
          aria-label="Remove assignment"
          className="p-1 text-fg-muted hover:text-[#EF4444] disabled:opacity-50 cursor-pointer transition-colors"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      ),
    },
  ]

  const feedbackColumns: PeopleColumn<any>[] = [
    { key: 'member', header: 'Member', render: f => <span className="font-medium text-fg-strong">{f.profiles?.full_name}</span> },
    // The note truncates at the column edge: a long feedback message is one
    // row of the table, not a paragraph that reflows the whole card.
    { key: 'content', header: 'Feedback', className: 'max-w-md truncate', render: f => f.content },
    {
      key: 'rating',
      header: 'Rating',
      className: 'whitespace-nowrap',
      render: f => f.rating
        ? (
          <span className="text-[#FFC107]">
            {'★'.repeat(f.rating)}
            <span className="text-fg-faint">{'★'.repeat(5 - f.rating)}</span>
          </span>
        )
        : <span className="text-fg-faint">—</span>,
    },
    { key: 'date', header: 'Date', className: 'text-fg-muted', render: f => new Date(f.created_at).toLocaleDateString() },
  ]

  if (!trainer) {
    return <div className="text-center py-8 text-fg-muted">Trainer not found</div>
  }

  return (
    // `h-full min-h-0` + flex column, the same shell every list page uses. As a
    // plain `space-y-3` stack the cards were laid out at their natural height
    // while the scroll container above them was height-capped, so a ten-row
    // feedback table simply ran off the bottom of the window with nothing to
    // scroll to - the "cut off" this page had. Now the single visible card takes
    // the space it is given and its own body scrolls instead.
    <div className="h-full min-h-0 flex flex-col gap-3">
      <button onClick={() => navigate('/trainers')} className="flex items-center gap-1 text-sm text-fg-muted hover:text-fg shrink-0">
        <ArrowLeft className="w-4 h-4" /> Back to Trainers
      </button>

      <div className="glass-card p-4 rounded-xl shrink-0">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-gradient-to-br from-[#22C55E]/30 to-[#4ADE80]/30 flex items-center justify-center">
            <span className="text-xl font-bold text-accent-green">{trainer.full_name.charAt(0)}</span>
          </div>
          <div>
            <div className="text-lg font-bold text-fg-strong">{trainer.full_name}</div>
            <p className="text-sm text-fg">{trainer.email}</p>
            <p className="text-xs font-mono text-fg-strong mt-1">{trainer.code}</p>
            {trainer.specialty && <p className="text-xs text-[#22C55E] mt-1">{trainer.specialty}</p>}
            {trainer.available_days && <p className="text-xs text-fg mt-0.5">Available: {trainer.available_days}</p>}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between shrink-0">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 flex-1">
          <div className="glass-card p-4 rounded-xl">
            <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
              <Mail className="w-4 h-4" />
              <span>Email</span>
            </div>
            {editing ? (
              <input type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
                className="w-full px-2 py-1.5 text-sm bg-page-deep border border-line rounded-lg text-fg-strong focus:outline-none focus:border-[#7C3AED]" />
            ) : (
              <p className="text-sm text-fg-strong break-all">{trainer.email}</p>
            )}
          </div>
          <div className="glass-card p-4 rounded-xl">
            <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
              <Phone className="w-4 h-4" />
              <span>Phone</span>
            </div>
            {editing ? (
              <input type="text" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
                className="w-full px-2 py-1.5 text-sm bg-page-deep border border-line rounded-lg text-fg-strong focus:outline-none focus:border-[#7C3AED]" />
            ) : (
              <p className="text-sm text-fg-strong">{trainer.phone || '—'}</p>
            )}
          </div>
          <div className="glass-card p-4 rounded-xl">
            <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
              <span className="text-xs font-bold">S</span>
              <span>Specialty</span>
            </div>
            {editing ? (
              <input type="text" value={form.specialty} onChange={e => setForm(f => ({ ...f, specialty: e.target.value }))}
                placeholder="e.g. Strength training"
                className="w-full px-2 py-1.5 text-sm bg-page-deep border border-line rounded-lg text-fg-strong placeholder-fg-muted focus:outline-none focus:border-[#7C3AED]" />
            ) : (
              <p className="text-sm text-fg-strong">{trainer.specialty || '—'}</p>
            )}
          </div>
          <div className="glass-card p-4 rounded-xl">
            <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
              <Users className="w-4 h-4" />
              <span>Assigned Members</span>
            </div>
            {/* The paged TOTAL, not the visible rows: the stat has to match the
                badge and the footer whether page 1 or page 3 is on screen. */}
            <p className="text-xl font-bold text-fg-strong">{assignedTotal}</p>
          </div>
        </div>
        {editing ? (
          <div className="flex gap-2 ml-3 shrink-0">
            <button onClick={() => setEditing(false)} className="px-3 py-1.5 text-xs rounded-lg border border-line text-fg-muted hover:text-fg-strong cursor-pointer transition-colors">Cancel</button>
            <button onClick={saveEdit} disabled={updateTrainer.isPending} className="px-3 py-1.5 text-xs rounded-lg bg-[#7C3AED] text-white hover:bg-[#6D28D9] disabled:opacity-50 cursor-pointer transition-colors">
              {updateTrainer.isPending ? 'Saving…' : 'Save'}
            </button>
          </div>
        ) : (
          <button onClick={startEdit} className="px-3 py-1.5 text-xs rounded-lg border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/50 cursor-pointer transition-colors ml-3 shrink-0">Edit</button>
        )}
      </div>

      {/* The tab strip is the same shape Memberships uses (glass pill, active tab
          solid purple), so it reads as the same control in two places. The counts
          are the paged totals - the feedback badge used to print the old
          `.limit(10)` cap as if it were the whole story. */}
      <div className="glass-card rounded-xl p-1 w-fit shrink-0" role="tablist" aria-label="Trainer sections">
        {([
          { id: 'members' as const, label: 'Assigned Members', count: assignedTotal },
          { id: 'feedback' as const, label: 'Recent Feedback', count: feedbackTotal },
        ]).map(tab => (
          <button
            key={tab.id}
            type="button"
            role="tab"
            aria-selected={section === tab.id}
            onClick={() => setSection(tab.id)}
            className={`px-5 py-2 text-sm rounded-lg font-medium transition-all cursor-pointer ${
              section === tab.id
                ? 'bg-[#7C3AED] text-white shadow-sm'
                : 'text-fg hover:text-fg-strong'
            }`}
          >
            {tab.label}
            <span className={`ml-2 text-xs ${section === tab.id ? 'text-white/80' : 'text-fg-muted'}`}>
              {tab.count}
            </span>
          </button>
        ))}
      </div>

      {section === 'members' && (
      // The shared list card, not a hand-rolled one: 10 rows a page with the
      // `#` column and the records footer inside the card, exactly as the
      // members/trainers/memberships lists render them. The card itself is
      // `flex-1 min-h-0`, so it takes whatever height the header, stat cards
      // and tab strip left over and its body scrolls inside it.
      <PeopleTable
        title="Assigned Members"
        rows={assignedMembers}
        columns={memberColumns}
        rowKey={a => a.id}
        // A non-empty total with an empty page is a clamp transient (or a
        // refetch), not a genuinely empty list - reading it as loading keeps
        // "No members assigned" from flashing while page 2 collapses to 1.
        isLoading={membersLoading || (assignedTotal > 0 && assignedMembers.length === 0)}
        emptyMessage="No members assigned"
        headerExtra={
          <button
            onClick={() => setShowAssignModal(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-[#7C3AED] hover:bg-[#6D28D9] rounded-lg transition-colors cursor-pointer"
          >
            <UserPlus className="w-3.5 h-3.5" /> Assign Member
          </button>
        }
        scrollRef={scrollRef}
        rowHeight={rowHeight}
        startIndex={(safeMembersPage - 1) * DETAIL_PAGE_SIZE + 1}
        footer={
          <PaginationFooter
            page={safeMembersPage}
            pageCount={memberPageCount}
            total={assignedTotal}
            pageSize={DETAIL_PAGE_SIZE}
            onPageChange={setMembersPage}
          />
        }
      />
      )}

      {section === 'feedback' && (
      // Same contract as the members tab; the header carries the rating
      // summary, which averages ALL of the trainer feedback rather than the
      // one page on screen.
      <PeopleTable
        title="Recent Feedback"
        rows={recentFeedback}
        columns={feedbackColumns}
        rowKey={f => f.id}
        isLoading={feedbackLoading || (feedbackTotal > 0 && recentFeedback.length === 0)}
        emptyMessage="No feedback yet"
        headerExtra={avgRating !== null ? (
          <span className="inline-flex items-center gap-2 text-xs text-fg-muted">
            <span className="text-[#FFC107] text-sm">
              {'★'.repeat(Math.round(avgRating))}
              <span className="text-fg-faint">{'★'.repeat(5 - Math.round(avgRating))}</span>
            </span>
            <span className="font-semibold text-fg-strong">{avgRating.toFixed(1)}</span>
            <span>/ 5 · {ratedRatings.length} rated</span>
          </span>
        ) : null}
        scrollRef={scrollRef}
        rowHeight={rowHeight}
        startIndex={(safeFeedbackPage - 1) * DETAIL_PAGE_SIZE + 1}
        footer={
          <PaginationFooter
            page={safeFeedbackPage}
            pageCount={feedbackPageCount}
            total={feedbackTotal}
            pageSize={DETAIL_PAGE_SIZE}
            onPageChange={setFeedbackPage}
          />
        }
      />
      )}

      {showAssignModal && (
        <div className="fixed inset-0 bg-black/60 z-50" onClick={() => setShowAssignModal(false)}>
          <div className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-4 border-b border-line">
              <h3 className="text-lg font-semibold text-fg-strong">Assign Member</h3>
              <button onClick={() => setShowAssignModal(false)} className="text-fg-muted hover:text-fg-strong transition-colors cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="px-6 py-4 border-b border-line">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-muted" />
                <input
                  type="text"
                  placeholder="Search members..."
                  value={memberSearch}
                  onChange={e => setMemberSearch(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-page-deep border border-line rounded-lg text-fg-strong placeholder-fg-muted focus:outline-none focus:border-[#7C3AED]"
                />
              </div>
            </div>
            <div className="flex-1 overflow-y-auto px-4 py-2">
              {unassignedMembers
                ?.filter(m =>
                  memberSearch === '' ||
                  m.full_name?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                  m.email?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                  m.code?.toLowerCase().includes(memberSearch.toLowerCase())
                )
                .map(m => (
                  <button
                    key={m.id}
                    onClick={() => assignMutation.mutate(m.id)}
                    disabled={assignMutation.isPending}
                    className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-[#7C3AED]/10 transition-colors disabled:opacity-50 text-left"
                  >
                    <div>
                      <div className="text-sm font-medium text-fg-strong">{m.full_name}</div>
                      <div className="text-xs text-fg-muted">{m.email} {m.code ? `· ${m.code}` : ''}</div>
                    </div>
                    <UserPlus className="w-4 h-4 text-[#7C3AED]" />
                  </button>
                ))}
              {unassignedMembers?.filter(m =>
                memberSearch === '' ||
                m.full_name?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                m.email?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                m.code?.toLowerCase().includes(memberSearch.toLowerCase())
              ).length === 0 && (
                <div className="text-center py-6 text-fg-muted text-sm">No members found</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
