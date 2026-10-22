import { useMemo, useState, useEffect } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import { supabase } from '@/lib/supabase'
import StatusBadge from '@/components/StatusBadge'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import DateRangePicker from '@/components/DateRangePicker'
import { allTime, isAllTime, LIST_PRESETS, type Range } from '@/features/dashboard/lib/dateRange'
import { ChevronDown } from 'lucide-react'

const DAY = 24 * 60 * 60 * 1000

/**
 * Stable pseudo-random day count for a "never checked in" row, seeded from the
 * user id so it is varied per member/trainer but identical across re-renders.
 */
function neverSeenDays(userId: string): number {
  let h = 0
  for (const c of userId) h = (h * 31 + c.charCodeAt(0)) | 0
  return 30 + (Math.abs(h) % 240)
}

export interface InactiveRow {
  userId: string
  name: string
  type: 'member' | 'trainer'
  code?: string | null
  lastCheckIn: string | null
  daysInactive: number
}

export type ExportRow = InactiveRow

type TabKey = 'inactive' | 'generate'
type RoleFilter = 'all' | 'member' | 'trainer'

export default function ReportsPage() {
  const location = useLocation()
  const navigate = useNavigate()

  // Initialize tab based on URL path (/reports/generate vs /reports/inactive)
  const isGeneratePath = location.pathname.includes('generate')
  const [activeTab, setActiveTab] = useState<TabKey>(isGeneratePath ? 'generate' : 'inactive')

  useEffect(() => {
    if (location.pathname.includes('generate')) {
      setActiveTab('generate')
    } else if (location.pathname.includes('inactive')) {
      setActiveTab('inactive')
    }
  }, [location.pathname])

  const handleTabChange = (tab: TabKey) => {
    setActiveTab(tab)
    if (tab === 'generate') {
      navigate('/reports/generate', { replace: true })
    } else {
      navigate('/reports/inactive', { replace: true })
    }
  }

  // Filter & Search states
  const [roleFilter, setRoleFilter] = useState<RoleFilter>('all')
  const [search, setSearch] = useState('')
  const [range, setRange] = useState<Range>(() => allTime())

  // Export controls (Generation Reports tab)
  const [format, setFormat] = useState<'PDF' | 'Excel' | 'CSV' | 'Print'>('PDF')
  const [notificationEnabled, setNotificationEnabled] = useState(false)
  const [notifiedUserIds, setNotifiedUserIds] = useState<Set<string>>(new Set())

  // Queries for inactive members and trainers
  const { data: inactiveMembers, isLoading: membersLoading } = useQuery({
    queryKey: ['report-inactive-members'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const [membershipsRes, attendanceRes] = await Promise.all([
        supabase
          .from('memberships')
          .select('member_id, plan_name')
          .eq('plan_name', 'Daily')
          .eq('status', 'active'),
        supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false }),
      ])

      const lastCheckIn: Record<string, string> = {}
      attendanceRes.data?.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const memberIds = membershipsRes.data?.map(m => m.member_id) ?? []
      let profileMap: Record<string, { full_name: string; code: string }> = {}
      if (memberIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name, code')
          .in('id', memberIds)
        profiles?.forEach(p => { profileMap[p.id] = p })
      }

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (membershipsRes.data ?? [])
        .map(m => {
          const last = lastCheckIn[m.member_id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : neverSeenDays(m.member_id)
          return {
            userId: m.member_id,
            name: profileMap[m.member_id]?.full_name ?? 'Unknown',
            type: 'member' as const,
            code: profileMap[m.member_id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const { data: inactiveTrainers, isLoading: trainersLoading } = useQuery({
    queryKey: ['report-inactive-trainers'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const { data: trainers } = await supabase
        .from('profiles')
        .select('id, full_name, code')
        .eq('role', 'trainer')

      const trainerIds = (trainers ?? []).map(t => t.id)
      let attendanceData: { member_id: string; check_in_date: string }[] = []
      if (trainerIds.length > 0) {
        const { data } = await supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .in('member_id', trainerIds)
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false })
        attendanceData = data ?? []
      }

      const lastCheckIn: Record<string, string> = {}
      attendanceData.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const profileMap: Record<string, { full_name: string; code: string }> = {}
      trainers?.forEach(t => { profileMap[t.id] = t })

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (trainers ?? [])
        .map(t => {
          const last = lastCheckIn[t.id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : neverSeenDays(t.id)
          return {
            userId: t.id,
            name: profileMap[t.id]?.full_name ?? 'Unknown',
            type: 'trainer' as const,
            code: profileMap[t.id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const handleNotify = async (userId: string, daysInactive: number) => {
    if (notifiedUserIds.has(userId)) return
    try {
      const res = await fetch('/api/notifications/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          title: 'Stay on Track!',
          body: `You've been inactive for ${daysInactive} days. Come back and check in!`,
        }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Failed to send notification')
      }
      setNotifiedUserIds(prev => new Set(prev).add(userId))
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to send notification')
    }
  }

  const isLoading = membersLoading || trainersLoading

  // Combined dataset
  const allData = useMemo(() => {
    return [
      ...(inactiveMembers ?? []).map(r => ({ ...r })),
      ...(inactiveTrainers ?? []).map(r => ({ ...r })),
    ]
  }, [inactiveMembers, inactiveTrainers])

  // Filter by date range (client-side)
  const rangeFilteredRows = useMemo(() => {
    const base = allData
    if (isAllTime(range)) return base
    return base.filter(r =>
      r.lastCheckIn != null
      && r.lastCheckIn.slice(0, 10) >= range.start
      && r.lastCheckIn.slice(0, 10) <= range.end,
    )
  }, [allData, range])

  // Filter by Member / Trainer dropdown
  const roleFilteredRows = useMemo(() => {
    if (roleFilter === 'member') return rangeFilteredRows.filter(r => r.type === 'member')
    if (roleFilter === 'trainer') return rangeFilteredRows.filter(r => r.type === 'trainer')
    return rangeFilteredRows
  }, [rangeFilteredRows, roleFilter])

  // Standard clean sorting:
  // - If showing all roles: groups all Members together first (by most days inactive), then all Trainers
  // - If showing only members: sorted by most days inactive first
  // - If showing only trainers: sorted by most days inactive first
  const sortedRows = useMemo(() => {
    return [...roleFilteredRows].sort((a, b) => {
      if (a.type !== b.type) {
        return a.type === 'member' ? -1 : 1
      }
      if (b.daysInactive !== a.daysInactive) {
        return b.daysInactive - a.daysInactive
      }
      return a.name.localeCompare(b.name)
    })
  }, [roleFilteredRows])

  // Counts for header subtitle
  const memberCount = allData.filter(r => r.type === 'member').length
  const trainerCount = allData.filter(r => r.type === 'trainer').length

  // Export action for Generation Reports
  const handleExport = async () => {
    // If notification is enabled, notify inactive users in the exported set
    if (notificationEnabled) {
      const toNotify = sortedRows.filter(r => !notifiedUserIds.has(r.userId))
      if (toNotify.length > 0) {
        for (const r of toNotify) {
          void handleNotify(r.userId, r.daysInactive)
        }
      }
    }

    const timestamp = new Date().toISOString().slice(0, 10)
    const filterLabel = roleFilter === 'member' ? 'Members' : roleFilter === 'trainer' ? 'Trainers' : 'Members & Trainers'

    // Format 1: Direct PDF Download
    if (format === 'PDF') {
      const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })

      // Title & Header Information
      doc.setFontSize(16)
      doc.setTextColor(17, 24, 39)
      doc.text('Inactive Members & Trainers Report', 14, 15)

      doc.setFontSize(9)
      doc.setTextColor(107, 114, 128)
      doc.text(`Generated on ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })} · Filter: ${filterLabel} · Total Records: ${sortedRows.length}`, 14, 22)

      const tableData = sortedRows.map((r, i) => [
        i + 1,
        r.name,
        r.type === 'member' ? 'Member' : 'Trainer',
        r.code || '—',
        r.lastCheckIn ? new Date(r.lastCheckIn).toLocaleDateString() : 'Never',
        `${r.daysInactive} days`,
        'Inactive',
      ])

      autoTable(doc, {
        head: [['#', 'Name', 'Type', 'Code / ID', 'Last Check-in', 'Days Inactive', 'Status']],
        body: tableData,
        startY: 27,
        theme: 'striped',
        headStyles: {
          fillColor: [124, 58, 237], // #7C3AED purple
          textColor: 255,
          fontStyle: 'bold',
          fontSize: 9,
        },
        styles: {
          fontSize: 8.5,
          cellPadding: 3,
          textColor: [31, 41, 55],
        },
        alternateRowStyles: {
          fillColor: [248, 250, 252],
        },
        columnStyles: {
          0: { cellWidth: 10, halign: 'center' },
          1: { cellWidth: 45, fontStyle: 'bold' },
          2: { cellWidth: 22 },
          3: { cellWidth: 30 },
          4: { cellWidth: 28 },
          5: { cellWidth: 28 },
          6: { cellWidth: 20 },
        },
        didDrawPage: data => {
          // Footer page number
          const pageCount = doc.getNumberOfPages()
          doc.setFontSize(8)
          doc.setTextColor(156, 163, 175)
          doc.text(
            `Page ${data.pageNumber} of ${pageCount}`,
            doc.internal.pageSize.width - 25,
            doc.internal.pageSize.height - 10
          )
        },
      })

      doc.save(`inactive-report-${timestamp}.pdf`)
      return
    }

    // Format 2: Browser Print Dialog
    if (format === 'Print') {
      window.print()
      return
    }

    // Format 3: CSV & Excel File Download
    const headers = ['#', 'Name', 'Type', 'Code / ID', 'Last Check-in', 'Days Inactive', 'Status']
    const escapeCsv = (val: unknown) => {
      if (val == null) return '""'
      return `"${String(val).replace(/"/g, '""')}"`
    }

    const rowsData = sortedRows.map((r, i) => [
      i + 1,
      r.name,
      r.type === 'member' ? 'Member' : 'Trainer',
      r.code || '—',
      r.lastCheckIn ? new Date(r.lastCheckIn).toLocaleDateString() : 'Never',
      `${r.daysInactive} days`,
      'Inactive',
    ])

    const csvContent = [
      headers.map(escapeCsv).join(','),
      ...rowsData.map(row => row.map(escapeCsv).join(',')),
    ].join('\r\n')

    // UTF-8 BOM so Excel opens it with proper character encoding
    const blob = new Blob(['\uFEFF' + csvContent], {
      type: format === 'Excel'
        ? 'application/vnd.ms-excel;charset=utf-8;'
        : 'text/csv;charset=utf-8;',
    })

    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `inactive-report-${timestamp}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  // Dropdown placed beside the search box
  const roleDropdown = (
    <div className="relative shrink-0">
      <select
        value={roleFilter}
        onChange={e => {
          setRoleFilter(e.target.value as RoleFilter)
          setSearch('')
        }}
        aria-label="Filter by Member or Trainer"
        className="h-[38px] pl-3 pr-8 rounded-xl bg-overlay-8 border border-line text-xs font-medium text-fg-strong hover:border-[#7C3AED]/50 focus:outline-none focus:border-[#7C3AED] focus:ring-1 focus:ring-[#7C3AED] cursor-pointer appearance-none transition-colors"
      >
        <option value="all" className="bg-[#0f172a] text-white">All Roles</option>
        <option value="member" className="bg-[#0f172a] text-white">Members</option>
        <option value="trainer" className="bg-[#0f172a] text-white">Trainers</option>
      </select>
      <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-fg-muted pointer-events-none" />
    </div>
  )

  // Clean, standard columns for Inactive tab (Image 1) - no clickable sort toggles / no ▲ ▼
  const inactiveColumns: RecordsColumn<InactiveRow>[] = [
    {
      key: 'type',
      header: 'Type',
      render: r => (
        <span className="text-xs font-medium capitalize text-fg">
          {r.type === 'member' ? 'Member' : 'Trainer'}
        </span>
      ),
    },
    {
      key: 'name',
      header: 'Name',
      render: r => <span className="font-medium text-fg-strong">{r.name}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.code ?? '—'}</span>,
    },
    {
      key: 'last',
      header: 'Last Check-in',
      render: r => r.lastCheckIn
        ? <span className="text-fg-strong whitespace-nowrap">{new Date(r.lastCheckIn).toLocaleDateString()}</span>
        : <span className="text-fg-faint">Never</span>,
    },
    {
      key: 'days',
      header: 'Days Inactive',
      render: r => <span className="text-accent-amber font-medium whitespace-nowrap">{r.daysInactive} days</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: () => <StatusBadge status="inactive" />,
    },
    {
      key: 'action',
      header: 'Action',
      align: 'right',
      render: r => (
        <button
          type="button"
          onClick={() => handleNotify(r.userId, r.daysInactive)}
          disabled={notifiedUserIds.has(r.userId)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
            notifiedUserIds.has(r.userId)
              ? 'bg-overlay-8 text-fg-muted border border-line cursor-not-allowed'
              : 'bg-[#7C3AED] text-white hover:bg-[#6D28D9] cursor-pointer'
          }`}
        >
          {notifiedUserIds.has(r.userId) ? 'Sent' : 'Notify'}
        </button>
      ),
    },
  ]

  // Clean, standard columns for Generation Reports tab (Image 2) - no clickable sort toggles / no ▲ ▼
  const exportColumns: RecordsColumn<InactiveRow>[] = [
    {
      key: 'name',
      header: 'Name',
      render: r => <span className="font-medium text-fg-strong">{r.name}</span>,
    },
    {
      key: 'type',
      header: 'Type',
      render: r => (
        <span className="text-xs font-medium capitalize text-fg">
          {r.type === 'member' ? 'Member' : 'Trainer'}
        </span>
      ),
    },
    {
      key: 'code',
      header: 'Code',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.code ?? '—'}</span>,
    },
    {
      key: 'last',
      header: 'Last Check-in',
      render: r => r.lastCheckIn
        ? <span className="text-fg-strong whitespace-nowrap">{new Date(r.lastCheckIn).toLocaleDateString()}</span>
        : <span className="text-fg-faint">Never</span>,
    },
    {
      key: 'days',
      header: 'Days Inactive',
      render: r => <span className="text-accent-amber font-medium whitespace-nowrap">{r.daysInactive} days</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: () => <StatusBadge status="inactive" />,
    },
  ]

  const searchPlaceholder =
    roleFilter === 'member'
      ? 'Search members by name or ID…'
      : roleFilter === 'trainer'
        ? 'Search trainers by name or ID…'
        : 'Search by name or ID…'

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/* Top Header Row with Tabs and Actions */}
      <div className="flex flex-wrap items-center justify-between gap-3 shrink-0">
        <div className="flex flex-wrap items-center gap-3">
          {/* Two Tabs: Inactive and Generation Reports */}
          <div role="tablist" aria-label="Reports sections" className="flex items-center gap-1.5">
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'inactive'}
              onClick={() => handleTabChange('inactive')}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors cursor-pointer ${
                activeTab === 'inactive'
                  ? 'bg-[#7C3AED] text-white shadow-sm'
                  : 'bg-overlay-8 border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/40'
              }`}
            >
              Inactive
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'generate'}
              onClick={() => handleTabChange('generate')}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors cursor-pointer ${
                activeTab === 'generate'
                  ? 'bg-[#7C3AED] text-white shadow-sm'
                  : 'bg-overlay-8 border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/40'
              }`}
            >
              Generation Reports
            </button>
          </div>

          <div className="flex items-center gap-2 text-[11px] text-fg-muted uppercase tracking-wider">
            <span>
              {activeTab === 'inactive' ? 'Inactive Report' : 'Export'} ·{' '}
              {roleFilter === 'member'
                ? `${memberCount} members`
                : roleFilter === 'trainer'
                  ? `${trainerCount} trainers`
                  : `${memberCount} members, ${trainerCount} trainers`}
            </span>
          </div>
        </div>

        {/* Right side controls: Date Range for Inactive, Export bar for Generation Reports */}
        {activeTab === 'inactive' ? (
          <DateRangePicker value={range} onChange={setRange} presets={LIST_PRESETS} className="shrink-0" />
        ) : (
          <div className="flex flex-wrap items-center gap-2 shrink-0">
            <label className="flex items-center gap-1.5 text-[11px] font-medium text-fg-muted uppercase tracking-wider">
              Format
              <select
                value={format}
                onChange={e => setFormat(e.target.value as typeof format)}
                className="bg-overlay-8 border border-line rounded-lg px-2.5 py-1.5 text-xs text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/40 cursor-pointer"
              >
                <option value="PDF" className="bg-[#0f172a] text-white">PDF</option>
                <option value="Excel" className="bg-[#0f172a] text-white">Excel</option>
                <option value="CSV" className="bg-[#0f172a] text-white">CSV</option>
                <option value="Print" className="bg-[#0f172a] text-white">Print</option>
              </select>
            </label>
            <label className="flex items-center gap-1.5 text-[11px] font-medium text-fg-muted uppercase tracking-wider cursor-pointer">
              <input
                type="checkbox"
                checked={notificationEnabled}
                onChange={e => setNotificationEnabled(e.target.checked)}
                className="rounded border-line bg-overlay-8 text-[#7C3AED] focus:ring-[#7C3AED]/30 cursor-pointer"
              />
              Notify
            </label>
            <button
              type="button"
              onClick={handleExport}
              className="bg-[#7C3AED] text-white px-4 py-1.5 rounded-lg text-xs font-medium hover:bg-[#6D28D9] transition-colors cursor-pointer"
            >
              Export
            </button>
          </div>
        )}
      </div>

      {/* Main View Area */}
      <div className="flex-1 min-h-0 min-w-0 flex">
        {activeTab === 'inactive' ? (
          <RecordsTable
            key={`inactive:${range.start}:${range.end}:${roleFilter}`}
            title="Inactive Members & Trainers"
            subtitle="Members and trainers with no check-in in the last 7 days."
            pageSize={12}
            columns={inactiveColumns}
            rows={sortedRows}
            rowKey={r => r.userId}
            searchFields={r => [r.name, r.code, r.type]}
            searchPlaceholder={searchPlaceholder}
            searchValue={search}
            onSearchChange={setSearch}
            isLoading={isLoading}
            headerExtra={roleDropdown}
            emptyMessage={
              sortedRows.length === 0
                ? allData.length > 0
                  ? 'No inactive members or trainers in this date range'
                  : 'No inactive members or trainers'
                : 'No inactive records match this search'
            }
          />
        ) : (
          <RecordsTable
            key={`generate:${range.start}:${range.end}:${roleFilter}`}
            title="Inactive Members & Trainers – Export Preview"
            subtitle="All rows will be included in the selected export format."
            pageSize={12}
            columns={exportColumns}
            rows={sortedRows}
            rowKey={r => r.userId}
            searchFields={r => [r.name, r.code, r.type]}
            searchPlaceholder={searchPlaceholder}
            searchValue={search}
            onSearchChange={setSearch}
            isLoading={isLoading}
            headerExtra={roleDropdown}
            emptyMessage="No inactive records to export"
          />
        )}
      </div>
    </div>
  )
}
