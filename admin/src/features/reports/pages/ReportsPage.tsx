import { useMemo, useState, useEffect } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import { supabase } from '@/lib/supabase'
import { fetchLastCheckins, fetchMemberships } from '@/features/dashboard/lib/attendance'
import { fetchAllRows } from '@/features/dashboard/lib/fetchAll'
import { toDay, daysBetween } from '@/features/dashboard/lib/dateRange'
import StatusBadge from '@/components/StatusBadge'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import PurpleSelect from '@/components/PurpleSelect'
import DateRangePicker from '@/components/DateRangePicker'
import { allTime, isAllTime, LIST_PRESETS, localEndIso, localStartIso, type Range } from '@/features/dashboard/lib/dateRange'
import { ChevronDown, MessageSquare } from 'lucide-react'
import { useCheckinsTab, type CheckinRecord } from '@/features/dashboard/hooks/useCheckinsTab'
import { useGrowthTab, type GrowthRecord } from '@/features/dashboard/hooks/useGrowthTab'
import { useRevenueTab, type RevenueRecord } from '@/features/dashboard/hooks/useRevenueTab'
import { useMemberOverviewTab, type MemberOverviewRecord } from '@/features/dashboard/hooks/useMemberOverviewTab'
import { useActivityTab } from '@/features/dashboard/hooks/useActivityTab'
import type { ActivityItem } from '@/features/dashboard/lib/activityFeed'
import type { PlanFilter } from '@/features/dashboard/lib/planFilter'
import { fmtDay, formatRangeLabel } from '@/features/dashboard/lib/dateRange'

export interface InactiveRow {
  userId: string
  name: string
  type: 'member' | 'trainer'
  code?: string | null
  lastCheckIn: string | null
  joinedAt: string | null
  daysInactive: number
}

export interface FeedbackExportRow {
  id: string
  memberName: string
  memberCode?: string | null
  memberEmail?: string | null
  trainerName?: string | null
  feedback: string
  rating: number | null
  date: string
  memberComment?: string | null
  memberCommentedAt?: string | null
}

export type ExportRow = InactiveRow

type TabKey = 'inactive' | 'generate'
type RoleFilter = 'all' | 'member' | 'trainer'
type ReportType = 'inactive' | 'feedback' | 'dailyCheckins' | 'revenue' | 'memberGrowth' | 'memberOverview' | 'recentActivity'

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
  const [roles, setRoles] = useState<Record<string, RoleFilter>>({})
  const [searches, setSearches] = useState<Record<string, string>>({})
  const [inactiveRange, setInactiveRange] = useState<Range>(() => allTime())
  const [feedbackRange, setFeedbackRange] = useState<Range>(() => allTime())
  const [generateInactiveRange, setGenerateInactiveRange] = useState<Range>(() => allTime())

  // Independent date ranges and search for each report section (Generation Reports tab)
  const [dailyCheckinRange, setDailyCheckinRange] = useState<Range>(() => allTime())
  const [dailyCheckinSearch, setDailyCheckinSearch] = useState('')
  const [revenueRange, setRevenueRange] = useState<Range>(() => allTime())
  const [revenueSearch, setRevenueSearch] = useState('')
  const [memberGrowthRange, setMemberGrowthRange] = useState<Range>(() => allTime())
  const [memberGrowthSearch, setMemberGrowthSearch] = useState('')
  const [memberOverviewRange, setMemberOverviewRange] = useState<Range>(() => allTime())
  const [memberOverviewSearch, setMemberOverviewSearch] = useState('')
  const [recentActivityRange, setRecentActivityRange] = useState<Range>(() => allTime())
  const [recentActivitySearch, setRecentActivitySearch] = useState('')

  // Export controls (Generation Reports tab)
  const [format, setFormat] = useState<'PDF' | 'Excel' | 'CSV' | 'Print'>('PDF')
  const [notificationEnabled, setNotificationEnabled] = useState(false)
  const [notifiedUserIds, setNotifiedUserIds] = useState<Set<string>>(new Set())
  const [reportType, setReportType] = useState<ReportType>('inactive')
  const viewKey = activeTab === 'inactive' ? 'inactive-tab' : reportType
  const roleFilter = roles[viewKey] ?? 'all'
  const setRoleFilter = (value: RoleFilter) => setRoles(prev => ({ ...prev, [viewKey]: value }))
  const search = searches[viewKey] ?? ''
  const setSearch = (value: string) => setSearches(prev => ({ ...prev, [viewKey]: value }))
  const reportRanges = {
    inactive: [generateInactiveRange, setGenerateInactiveRange], feedback: [feedbackRange, setFeedbackRange],
    dailyCheckins: [dailyCheckinRange, setDailyCheckinRange], revenue: [revenueRange, setRevenueRange],
    memberGrowth: [memberGrowthRange, setMemberGrowthRange], memberOverview: [memberOverviewRange, setMemberOverviewRange],
    recentActivity: [recentActivityRange, setRecentActivityRange],
  } as const
  const [currentRange, setCurrentRange] = activeTab === 'inactive' ? [inactiveRange, setInactiveRange] as const : reportRanges[reportType]
  const selectedInactiveRange = activeTab === 'inactive' ? inactiveRange : generateInactiveRange


  // Read actual last visits across history, not only the last seven days.
  const { data: inactiveData, isLoading: membersLoading, error: inactiveError } = useQuery({
    queryKey: ['report-inactive-roster'],
    queryFn: async () => {
      type Profile = { id: string; full_name: string; code: string | null; role: 'member' | 'trainer'; created_at: string | null }
      const [profiles, memberships, lastVisits] = await Promise.all([
        fetchAllRows<Profile>(async (from, to) => {
          const { data, error } = await supabase.from('profiles')
            .select('id, full_name, code, role, created_at').in('role', ['member', 'trainer'])
            .order('id').range(from, to)
          return { data: data as Profile[] | null, error }
        }),
        fetchMemberships(), fetchLastCheckins(),
      ])
      const dailyMembers = new Set(memberships.filter(m => m.plan_name === 'Daily' && m.status === 'active').map(m => m.member_id))
      const today = toDay(new Date())
      return profiles.filter(p => p.role === 'trainer' || dailyMembers.has(p.id)).map((p): InactiveRow => {
        const last = lastVisits[p.id] ?? null
        const joinedAt = p.created_at ? toDay(new Date(p.created_at)) : null
        return { userId: p.id, name: p.full_name, type: p.role, code: p.code,
          lastCheckIn: last, joinedAt, daysInactive: Math.max(0, daysBetween(last ?? joinedAt ?? today, today) - 1) }
      }).filter(r => r.daysInactive >= 7)
    },
  })
  const trainersLoading = membersLoading

  const { data: feedbackData, isLoading: feedbackLoading, error: feedbackError } = useQuery({
    queryKey: ['report-feedback', feedbackRange],
    queryFn: async () => {
      const narrow = !isAllTime(feedbackRange)
      const from = narrow ? localStartIso(feedbackRange.start) : undefined
      const to = narrow ? localEndIso(feedbackRange.end) : undefined

      const data = await fetchAllRows<any>(async (start, end) => {
      let q = supabase
        .from('trainer_feedback')
        .select('*, member:profiles!trainer_feedback_member_id_fkey(full_name, code, email), trainer:profiles!trainer_feedback_trainer_id_fkey(full_name)')
      if (from) q = q.gte('created_at', from)
      if (to) q = q.lte('created_at', to)
      return await q
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .range(start, end)
      })

      return (data ?? []).map((f: any): FeedbackExportRow => ({
        id: f.id,
        memberName: f.member?.full_name ?? 'Unknown',
        memberCode: f.member?.code ?? null,
        memberEmail: f.member?.email ?? null,
        trainerName: f.trainer?.full_name ?? null,
        feedback: f.content ?? '',
        rating: f.rating ?? null,
        date: f.created_at,
        memberComment: f.member_comment ?? null,
        memberCommentedAt: f.member_commented_at ?? null,
      }))
    },
    enabled: activeTab === 'generate' && reportType === 'feedback',
  })

  // Daily Check-ins query (Generation Reports tab)
  const dailyCheckinData = useCheckinsTab(
    dailyCheckinRange,
    'all' as PlanFilter,
    'daily'
  )

  // Revenue Overview query (Generation Reports tab)
  const revenueData = useRevenueTab(
    revenueRange,
    'all' as PlanFilter,
    'monthly'
  )

  // Member Growth query (Generation Reports tab)
  const memberGrowthData = useGrowthTab(
    memberGrowthRange,
    'all' as PlanFilter,
    'daily'
  )

  // Member Overview query (Generation Reports tab)
  const memberOverviewData = useMemberOverviewTab(
    memberOverviewRange,
    'all' as PlanFilter
  )

  // Recent Activity query (Generation Reports tab)
  const recentActivityData = useActivityTab(
    recentActivityRange,
    'all' as PlanFilter,
    'all',
    'daily'
  )

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

  const isLoading = activeTab === 'inactive' || reportType === 'inactive'
    ? (membersLoading || trainersLoading)
    : reportType === 'feedback'
      ? feedbackLoading
      : reportType === 'dailyCheckins'
        ? dailyCheckinData.isLoading
        : reportType === 'revenue'
          ? revenueData.isLoading
          : reportType === 'memberGrowth'
            ? memberGrowthData.isLoading
            : reportType === 'memberOverview'
              ? memberOverviewData.isLoading
              : recentActivityData.isLoading

  const allData = inactiveData ?? []
  // Range applies to last visit, or registration date for people who never visited.
  const rangeFilteredRows = useMemo(() => {
    if (isAllTime(selectedInactiveRange)) return inactiveData ?? []
    return (inactiveData ?? []).filter(r => {
      const day = r.lastCheckIn ?? r.joinedAt
      return day != null && day >= selectedInactiveRange.start && day <= selectedInactiveRange.end
    })
  }, [inactiveData, selectedInactiveRange])

  // Filter by Member / Trainer dropdown for inactive
  const roleFilteredRows = useMemo(() => {
    if (roleFilter === 'member') return rangeFilteredRows.filter(r => r.type === 'member')
    if (roleFilter === 'trainer') return rangeFilteredRows.filter(r => r.type === 'trainer')
    return rangeFilteredRows
  }, [rangeFilteredRows, roleFilter])

  // Standard clean sorting for inactive:
  const sortedRows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return roleFilteredRows.filter(r => !q || [r.name, r.code, r.type].some(value => value?.toLowerCase().includes(q))).sort((a, b) => {
      if (a.type !== b.type) {
        return a.type === 'member' ? -1 : 1
      }
      if (b.daysInactive !== a.daysInactive) {
        return b.daysInactive - a.daysInactive
      }
      return a.name.localeCompare(b.name)
    })
  }, [roleFilteredRows, search])

  const feedbackRows = useMemo(() => {
    if (reportType !== 'feedback') return []
    const rows = feedbackData ?? []
    const q = search.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      r.memberName.toLowerCase().includes(q) ||
      (r.trainerName?.toLowerCase().includes(q)) ||
      r.feedback.toLowerCase().includes(q) ||
      (r.memberCode?.toLowerCase().includes(q))
    )
  }, [feedbackData, reportType, search])

  const dailyCheckinRows = useMemo(() => {
    if (reportType !== 'dailyCheckins') return []
    const rows = dailyCheckinData?.records ?? []
    const q = dailyCheckinSearch.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      (r.profiles?.full_name ?? '').toLowerCase().includes(q) ||
      (r.profiles?.code ?? '').toLowerCase().includes(q) ||
      (r.planName ?? '').toLowerCase().includes(q) ||
      r.check_in_date.toLowerCase().includes(q)
    )
  }, [dailyCheckinData, reportType, dailyCheckinSearch])

  const revenueRows = useMemo(() => {
    if (reportType !== 'revenue') return []
    const rows = revenueData?.records ?? []
    const q = revenueSearch.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      r.memberName.toLowerCase().includes(q) ||
      (r.memberCode ?? '').toLowerCase().includes(q) ||
      r.planName.toLowerCase().includes(q) ||
      r.startDate.toLowerCase().includes(q)
    )
  }, [revenueData, reportType, revenueSearch])

  const memberGrowthRows = useMemo(() => {
    if (reportType !== 'memberGrowth') return []
    const rows = memberGrowthData?.records ?? []
    const q = memberGrowthSearch.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      r.memberName.toLowerCase().includes(q) ||
      (r.memberCode ?? '').toLowerCase().includes(q) ||
      r.planName.toLowerCase().includes(q) ||
      r.day.toLowerCase().includes(q)
    )
  }, [memberGrowthData, reportType, memberGrowthSearch])

  const memberOverviewRows = useMemo(() => {
    if (reportType !== 'memberOverview') return []
    const rows = memberOverviewData?.records ?? []
    const q = memberOverviewSearch.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      r.memberName.toLowerCase().includes(q) ||
      (r.memberCode ?? '').toLowerCase().includes(q) ||
      r.planName.toLowerCase().includes(q) ||
      r.status.toLowerCase().includes(q)
    )
  }, [memberOverviewData, reportType, memberOverviewSearch])

  const recentActivityRows = useMemo(() => {
    if (reportType !== 'recentActivity') return []
    const rows = recentActivityData?.records ?? []
    const q = recentActivitySearch.trim().toLowerCase()
    if (!q) return rows
    return rows.filter(r =>
      r.memberName.toLowerCase().includes(q) ||
      (r.memberCode ?? '').toLowerCase().includes(q) ||
      r.message.toLowerCase().includes(q) ||
      r.type.toLowerCase().includes(q) ||
      r.day.toLowerCase().includes(q)
    )
  }, [recentActivityData, reportType, recentActivitySearch])

  // Counts for header subtitle
  const memberCount = sortedRows.filter(r => r.type === 'member').length
  const trainerCount = sortedRows.filter(r => r.type === 'trainer').length
  const feedbackCount = reportType === 'feedback' ? (feedbackData ?? []).length : 0
  const feedbackAvg = useMemo(() => {
    if (reportType !== 'feedback') return null
    const rated = (feedbackData ?? []).filter(f => f.rating != null)
    if (rated.length === 0) return null
    const sum = rated.reduce((acc, f) => acc + (f.rating ?? 0), 0)
    return sum / rated.length
  }, [feedbackData, reportType])

  const dailyCheckinCount = reportType === 'dailyCheckins' ? dailyCheckinRows.length : 0
  const revenueCount = reportType === 'revenue' ? revenueRows.length : 0
  const memberGrowthCount = reportType === 'memberGrowth' ? memberGrowthRows.length : 0
  const memberOverviewCount = reportType === 'memberOverview' ? memberOverviewRows.length : 0
  const recentActivityCount = reportType === 'recentActivity' ? recentActivityRows.length : 0

  // Export action for Generation Reports
  const handleExport = async () => {
    // If notification is enabled, notify inactive users in the exported set
    if (reportType === 'inactive' && notificationEnabled) {
      const toNotify = sortedRows.filter(r => !notifiedUserIds.has(r.userId))
      if (toNotify.length > 0) {
        for (const r of toNotify) {
          void handleNotify(r.userId, r.daysInactive)
        }
      }
    }

    const timestamp = new Date().toISOString().slice(0, 10)


    if (reportType !== 'inactive' && reportType !== 'feedback') {
      const reports = {
        dailyCheckins: { title: 'Daily Check-ins', headers: ['Date', 'Member', 'Code', 'Plan'], rows: dailyCheckinRows.map(r => [r.check_in_date, r.profiles?.full_name ?? '', r.profiles?.code ?? '', r.planName ?? '']) },
        revenue: { title: 'Revenue Overview', headers: ['Date', 'Member', 'Code', 'Plan', 'Amount'], rows: revenueRows.map(r => [r.startDate, r.memberName, r.memberCode ?? '', r.planName, r.price]) },
        memberGrowth: { title: 'Member Growth', headers: ['Date', 'Member', 'Code', 'Plan', 'Status'], rows: memberGrowthRows.map(r => [r.day, r.memberName, r.memberCode ?? '', r.planName, r.status]) },
        memberOverview: { title: 'Member Overview', headers: ['Member', 'Code', 'Plan', 'Status', 'Last Check-in'], rows: memberOverviewRows.map(r => [r.memberName, r.memberCode ?? '', r.planName, r.status, r.lastCheckIn ?? 'Never']) },
        recentActivity: { title: 'Recent Activity', headers: ['Date', 'Member', 'Code', 'Type', 'Details'], rows: recentActivityRows.map(r => [r.ts, r.memberName, r.memberCode ?? '', r.type, r.message]) },
      }
      const report = reports[reportType]
      if (format === 'PDF' || format === 'Print') {
        const doc = new jsPDF({ orientation: 'landscape' })
        doc.text(report.title, 14, 15)
        doc.setFontSize(10)
        doc.text(formatRangeLabel(currentRange), 14, 22)
        autoTable(doc, { head: [report.headers], body: report.rows, startY: 28 })
        if (format === 'Print') { doc.autoPrint(); window.open(doc.output('bloburl'), '_blank') }
        else doc.save(`${reportType}-${timestamp}.pdf`)
      } else {
        const csv = [report.headers, ...report.rows].map(row => row.map(v => '"' + String(v).replace(/"/g, '""') + '"').join(',')).join('\r\n')
        const url = URL.createObjectURL(new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' }))
        const link = document.createElement('a')
        link.href = url; link.download = `${reportType}-${timestamp}.csv`; link.click()
        URL.revokeObjectURL(url)
      }
      return
    }

    if (reportType === 'feedback') {
      const filterLabel = isAllTime(feedbackRange) ? 'All Time' : `${feedbackRange.start} to ${feedbackRange.end}`
      const avgLabel = feedbackAvg != null ? ` | Avg Rating: ${feedbackAvg.toFixed(1)}/5` : ''

      if (format === 'PDF') {
        const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' })
        doc.setFontSize(16)
        doc.setTextColor(17, 24, 39)
        doc.text('Coach Feedback Report', 14, 15)
        doc.setFontSize(9)
        doc.setTextColor(107, 114, 128)
        doc.text(`Generated on ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })} · Range: ${filterLabel} · Total: ${feedbackRows.length}${avgLabel}`, 14, 22)

        const tableData = feedbackRows.map((r, i) => [
          i + 1,
          r.memberName + (r.memberCode ? ` (${r.memberCode})` : ''),
          r.trainerName || '—',
          r.feedback.length > 80 ? r.feedback.substring(0, 77) + '...' : r.feedback,
          r.rating != null ? `${r.rating}/5` : '—',
          new Date(r.date).toLocaleDateString(),
        ])

        autoTable(doc, {
          head: [['#', 'Member', 'Trainer', 'Feedback', 'Rating', 'Date']],
          body: tableData,
          startY: 27,
          theme: 'striped',
          headStyles: { fillColor: [124, 58, 237], textColor: 255, fontStyle: 'bold', fontSize: 8 },
          styles: { fontSize: 7.5, cellPadding: 2 },
          alternateRowStyles: { fillColor: [248, 250, 252] },
        })
        doc.save(`coach-feedback-report-${timestamp}.pdf`)
        return
      }

      if (format === 'Print') {
        window.print()
        return
      }

      const headers = ['#', 'Member', 'Member Code', 'Member Email', 'Trainer', 'Feedback', 'Rating', 'Date', 'Member Comment']
      const escapeCsv = (val: unknown) => {
        if (val == null) return '""'
        return `"${String(val).replace(/"/g, '""')}"`
      }
      const rowsData = feedbackRows.map((r, i) => [
        i + 1,
        r.memberName,
        r.memberCode || '',
        r.memberEmail || '',
        r.trainerName || '',
        r.feedback,
        r.rating != null ? r.rating : '',
        new Date(r.date).toLocaleDateString(),
        r.memberComment || '',
      ])
      const csvContent = [headers.map(escapeCsv).join(','), ...rowsData.map(row => row.map(escapeCsv).join(','))].join('\r\n')
      const blob = new Blob(['\uFEFF' + csvContent], { type: format === 'Excel' ? 'application/vnd.ms-excel;charset=utf-8;' : 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `coach-feedback-report-${timestamp}.csv`
      link.click()
      URL.revokeObjectURL(url)
      return
    }

    // Inactive report export (existing logic)
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
  const roleDropdown = activeTab === 'inactive' || reportType === 'inactive' ? (
    <div className="relative shrink-0">
      <select
        value={roleFilter}
        onChange={e => {
          setRoleFilter(e.target.value as RoleFilter)
          setSearch('')
        }}
        aria-label="Filter by Member or Trainer"
        className="h-[38px] pl-3 pr-8 rounded-xl glass-input text-xs font-medium text-fg-strong hover:border-[#7C3AED]/50 focus:outline-none focus:border-[#7C3AED] focus:ring-1 focus:ring-[#7C3AED] cursor-pointer appearance-none transition-colors"
      >
        <option value="all" className="bg-[#0f172a] text-white">All Roles</option>
        <option value="member" className="bg-[#0f172a] text-white">Members</option>
        <option value="trainer" className="bg-[#0f172a] text-white">Trainers</option>
      </select>
      <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-fg-muted pointer-events-none" />
    </div>
  ) : null

  const reportTypeDropdown = activeTab === 'generate' ? (
    <PurpleSelect value={reportType} onChange={setReportType} label="Select report type" options={[
      { value: 'inactive', label: 'Inactive Members & Trainers' },
      { value: 'feedback', label: 'Coach Feedback' },
      { value: 'dailyCheckins', label: 'Daily Check-ins' },
      { value: 'revenue', label: 'Revenue Overview' },
      { value: 'memberGrowth', label: 'Member Growth' },
      { value: 'memberOverview', label: 'Member Overview' },
      { value: 'recentActivity', label: 'Recent Activity' },
    ]} />
  ) : null
  // Clean, standard columns for Inactive tab
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

  const feedbackExportColumns: RecordsColumn<FeedbackExportRow>[] = [
    {
      key: 'member',
      header: 'Member',
      render: r => (
        <div>
          <span className="font-medium text-fg-strong">{r.memberName}</span>
          {r.memberCode && <div className="text-[11px] font-mono text-fg-muted">{r.memberCode}</div>}
        </div>
      ),
    },
    {
      key: 'trainer',
      header: 'Trainer',
      render: r => <span className="text-fg">{r.trainerName ?? '—'}</span>,
    },
    {
      key: 'feedback',
      header: 'Feedback',
      render: r => (
        <span className="flex items-center gap-2 leading-5">
          <MessageSquare className="w-3.5 h-3.5 text-fg-muted shrink-0" />
          <span title={r.feedback}>{r.feedback}</span>
        </span>
      ),
    },
    {
      key: 'rating',
      header: 'Rating',
      render: r => r.rating == null
        ? <span className="text-fg-faint leading-5">Not rated</span>
        : (
          <span className="inline-flex items-center gap-1 whitespace-nowrap leading-5">
            <span className="text-[#FFC107] leading-5">
              {'★'.repeat(r.rating)}
              <span className="text-fg-faint">{'★'.repeat(5 - r.rating)}</span>
            </span>
            <span className="text-fg-muted">{r.rating}/5</span>
          </span>
        ),
    },
    {
      key: 'date',
      header: 'Date',
      align: 'right',
      render: r => <span className="whitespace-nowrap">{new Date(r.date).toLocaleDateString()}</span>,
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

  // Columns for Daily Check-ins
  const dailyCheckinColumns: RecordsColumn<CheckinRecord>[] = [
    {
      key: 'date',
      header: 'Date',
      render: r => <span className="text-fg-strong whitespace-nowrap">{fmtDay(r.check_in_date)}</span>,
    },
    {
      key: 'time',
      header: 'Time',
      render: r => {
        const d = new Date(r.check_in_time)
        return <span className="text-fg-muted text-[12px] whitespace-nowrap">{d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</span>
      },
    },
    {
      key: 'name',
      header: 'Member Name',
      render: r => <span className="font-medium text-fg-strong">{r.profiles?.full_name ?? 'Unknown'}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.profiles?.code ?? r.member_id.slice(0, 8)}</span>,
    },
    {
      key: 'plan',
      header: 'Membership Type',
      render: r => <span className="text-xs font-medium text-fg-muted">{r.planName ?? '—'}</span>,
    },
  ]

  // Columns for Revenue Overview
  const revenueColumns: RecordsColumn<RevenueRecord>[] = [
    {
      key: 'date',
      header: 'Date',
      render: r => <span className="text-fg-strong whitespace-nowrap">{fmtDay(r.startDate)}</span>,
    },
    {
      key: 'name',
      header: 'Member Name',
      render: r => <span className="font-medium text-fg-strong">{r.memberName}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span>,
    },
    {
      key: 'plan',
      header: 'Membership Type',
      render: r => <span className="text-xs font-medium text-fg-muted">{r.planName}</span>,
    },
    {
      key: 'amount',
      header: 'Amount',
      align: 'right',
      render: r => r.price > 0
        ? <span className="font-semibold text-fg-strong tabular-nums whitespace-nowrap">₱{r.price.toLocaleString()}</span>
        : <span className="text-fg-faint whitespace-nowrap">Free Trial</span>,
    },
  ]

  // Columns for Member Growth
  const memberGrowthColumns: RecordsColumn<GrowthRecord>[] = [
    {
      key: 'date',
      header: 'Date',
      render: r => <span className="text-fg-strong whitespace-nowrap">{fmtDay(r.day)}</span>,
    },
    {
      key: 'time',
      header: 'Time',
      render: r => <span className="text-fg-muted text-[12px] whitespace-nowrap">{new Date(r.createdAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</span>,
    },
    {
      key: 'name',
      header: 'Member Name',
      render: r => <span className="font-medium text-fg-strong">{r.memberName}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span>,
    },
    {
      key: 'plan',
      header: 'Membership Type',
      render: r => <span className="text-xs font-medium text-fg-muted">{r.planName}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: r => <span className={`text-xs font-medium ${r.status === 'Active' ? 'text-fg-success' : 'text-fg-faint'}`}>{r.status}</span>,
    },
  ]

  // Columns for Member Overview
  const memberOverviewColumns: RecordsColumn<MemberOverviewRecord>[] = [
    {
      key: 'name',
      header: 'Member Name',
      render: r => <span className="font-medium text-fg-strong">{r.memberName}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span>,
    },
    {
      key: 'plan',
      header: 'Membership Type',
      render: r => <span className="text-xs font-medium text-fg-muted">{r.planName}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: r => <span className={`text-xs font-medium ${r.status === 'Active' ? 'text-fg-success' : 'text-fg-faint'}`}>{r.status}</span>,
    },
    {
      key: 'last',
      header: 'Last Check-in',
      render: r => r.lastCheckIn
        ? <span className="text-fg-strong whitespace-nowrap">{new Date(r.lastCheckIn).toLocaleDateString()}</span>
        : <span className="text-fg-faint">Never</span>,
    },
  ]

  // Columns for Recent Activity
  const recentActivityColumns: RecordsColumn<ActivityItem>[] = [
    {
      key: 'date',
      header: 'Date',
      render: r => <span className="text-fg-strong whitespace-nowrap">{fmtDay(r.day)}</span>,
    },
    {
      key: 'time',
      header: 'Time',
      render: r => {
        const d = new Date(r.ts)
        return <span className="text-fg-muted text-[12px] whitespace-nowrap">{d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</span>
      },
    },
    {
      key: 'name',
      header: 'Member Name',
      render: r => <span className="font-medium text-fg-strong">{r.memberName}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.memberCode ?? '—'}</span>,
    },
    {
      key: 'type',
      header: 'Activity Type',
      render: r => <span className="text-xs font-medium text-fg-muted capitalize">{r.type}</span>,
    },
    {
      key: 'msg',
      header: 'Details',
      render: r => <span className="text-fg-muted whitespace-nowrap">{r.message}</span>,
    },
  ]

  const reportError = activeTab === 'inactive' || reportType === 'inactive' ? inactiveError
    : reportType === 'feedback' ? feedbackError
    : reportType === 'dailyCheckins' ? dailyCheckinData.error
    : reportType === 'revenue' ? revenueData.error
    : reportType === 'memberGrowth' ? memberGrowthData.error
    : reportType === 'memberOverview' ? memberOverviewData.error : recentActivityData.error

  const searchPlaceholder = activeTab === 'inactive' ? 'Search by name or ID…' :
    reportType === 'feedback'
      ? 'Search by member, trainer or feedback…'
      : reportType === 'dailyCheckins'
        ? 'Search by member name, ID or date…'
      : reportType === 'revenue'
        ? 'Search by member, plan or date…'
      : reportType === 'memberGrowth'
        ? 'Search by member name, ID or date…'
      : reportType === 'memberOverview'
        ? 'Search by member name, ID or plan…'
      : reportType === 'recentActivity'
        ? 'Search by member, type or date…'
      : roleFilter === 'member'
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
          <div role="tablist" aria-label="Reports sections" className="glass-card page-tabs">
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'inactive'}
              onClick={() => handleTabChange('inactive')}
              className="page-tab"
            >
              Inactive
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'generate'}
              onClick={() => handleTabChange('generate')}
              className="page-tab"
            >
              Generation Reports
            </button>
          </div>

          <div className="flex items-center gap-2 text-[11px] text-fg-muted uppercase tracking-wider">
            <span>
              {activeTab === 'inactive'
                ? 'Inactive Report'
                : reportType === 'feedback'
                  ? 'Coach Feedback Report'
                  : 'Export'} ·{' '}
              {activeTab === 'inactive'
                ? (roleFilter === 'member'
                  ? `${memberCount} members`
                  : roleFilter === 'trainer'
                    ? `${trainerCount} trainers`
                    : `${memberCount} members, ${trainerCount} trainers`)
                : reportType === 'feedback'
                  ? `${feedbackCount} entries${feedbackAvg != null ? ` · Avg ${feedbackAvg.toFixed(1)}/5` : ''}`
                  : reportType === 'dailyCheckins' ? `${dailyCheckinCount} check-ins`
                  : reportType === 'revenue' ? `${revenueCount} transactions`
                  : reportType === 'memberGrowth' ? `${memberGrowthCount} registrations`
                  : reportType === 'memberOverview' ? `${memberOverviewData.active} active, ${memberOverviewData.inactive} inactive / ${memberOverviewCount} members`
                  : reportType === 'recentActivity' ? `${recentActivityCount} events`
                  : (roleFilter === 'member'
                    ? `${memberCount} members`
                    : roleFilter === 'trainer'
                      ? `${trainerCount} trainers`
                      : `${memberCount} members, ${trainerCount} trainers`)}
            </span>
          </div>
        </div>

        {/* Right side controls */}
        {activeTab === 'inactive' ? (
          <DateRangePicker value={inactiveRange} onChange={setInactiveRange} presets={LIST_PRESETS} className="shrink-0" />
        ) : (
          <div className="flex flex-wrap items-center gap-2 shrink-0">
            {reportTypeDropdown}
            {activeTab === 'generate' && (
              <DateRangePicker key={viewKey} value={currentRange} onChange={setCurrentRange} presets={LIST_PRESETS} className="shrink-0" />
            )}
            <label className="flex items-center gap-1.5 text-[11px] font-medium text-fg-muted uppercase tracking-wider">
              Format
              <PurpleSelect value={format} onChange={setFormat} label="Export format" options={[
                { value: 'PDF', label: 'PDF' }, { value: 'Excel', label: 'Excel' },
                { value: 'CSV', label: 'CSV' }, { value: 'Print', label: 'Print' },
              ]} />
            </label>
            {reportType === 'inactive' && (
              <label className="flex items-center gap-1.5 text-[11px] font-medium text-fg-muted uppercase tracking-wider cursor-pointer">
                <input
                  type="checkbox"
                  checked={notificationEnabled}
                  onChange={e => setNotificationEnabled(e.target.checked)}
                  className="rounded border-line bg-overlay-8 text-[#7C3AED] focus:ring-[#7C3AED]/30 cursor-pointer"
                />
                Notify
              </label>
            )}
            <button
              type="button"
              onClick={handleExport}
              disabled={isLoading || Boolean(reportError)}
              className="bg-[#7C3AED] text-white px-4 py-1.5 rounded-lg text-xs font-medium hover:bg-[#6D28D9] transition-colors cursor-pointer"
            >
              Export
            </button>
          </div>
        )}
      </div>

      {/* Main View Area */}
      <div className="flex-1 min-h-0 min-w-0 flex">
        {reportError ? <p role="alert">Could not load report: {reportError.message}</p> : activeTab === 'inactive' ? (
          <RecordsTable
            key={`inactive:${inactiveRange.start}:${inactiveRange.end}:${roleFilter}`}
            title="Inactive Members & Trainers"
            subtitle="Daily-plan members and trainers with no check-in in 7 days. Dates filter last visit, or registration if never visited."
            pageSize={12}
            fillPage
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
        ) : reportType === 'feedback' ? (
          <RecordsTable
            key={`feedback:${feedbackRange.start}:${feedbackRange.end}`}
            title="Coach Feedback"
            subtitle="All feedback entries for the selected date range."
            pageSize={12}
            fillPage
            columns={feedbackExportColumns}
            rows={feedbackRows}
            rowKey={r => r.id}
            searchFields={r => [r.memberName, r.trainerName || '', r.feedback, r.memberCode || '']}
            searchPlaceholder={searchPlaceholder}
            searchValue={search}
            onSearchChange={setSearch}
            isLoading={isLoading}
            emptyMessage={feedbackRows.length === 0 ? 'No feedback entries found' : 'No feedback matches this search'}
          />
        ) : reportType === 'dailyCheckins' ? (
          <RecordsTable key={`dailyCheckins:${dailyCheckinRange.start}:${dailyCheckinRange.end}`}
            title="Daily Check-ins" subtitle="Check-in trends and volume over time." pageSize={12} fillPage
            columns={dailyCheckinColumns} rows={dailyCheckinRows} rowKey={r => r.id}
            searchFields={r => [r.profiles?.full_name, r.profiles?.code, r.check_in_date, r.planName]} searchPlaceholder={searchPlaceholder}
            searchValue={dailyCheckinSearch} onSearchChange={setDailyCheckinSearch}
            isLoading={isLoading} emptyMessage="No records for the selected dates" />
        ) : reportType === 'revenue' ? (
          <RecordsTable key={`revenue:${revenueRange.start}:${revenueRange.end}`}
            title="Revenue Overview" subtitle="Monthly or custom-range revenue and membership plan breakdowns." pageSize={12} fillPage
            columns={revenueColumns} rows={revenueRows} rowKey={r => r.id}
            searchFields={r => [r.memberName, r.memberCode, r.planName, r.startDate]} searchPlaceholder={searchPlaceholder}
            searchValue={revenueSearch} onSearchChange={setRevenueSearch}
            isLoading={isLoading} emptyMessage="No records for the selected dates" />
        ) : reportType === 'memberGrowth' ? (
          <RecordsTable key={`memberGrowth:${memberGrowthRange.start}:${memberGrowthRange.end}`}
            title="Member Growth" subtitle="New registration trends for the selected dates." pageSize={12} fillPage
            columns={memberGrowthColumns} rows={memberGrowthRows} rowKey={r => r.id}
            searchFields={r => [r.memberName, r.memberCode, r.day, r.planName]} searchPlaceholder={searchPlaceholder}
            searchValue={memberGrowthSearch} onSearchChange={setMemberGrowthSearch}
            isLoading={isLoading} emptyMessage="No records for the selected dates" />
        ) : reportType === 'memberOverview' ? (
          <RecordsTable key={`memberOverview:${memberOverviewRange.start}:${memberOverviewRange.end}`}
            title="Member Overview" subtitle="Active and inactive members for the selected dates." pageSize={12} fillPage
            columns={memberOverviewColumns} rows={memberOverviewRows} rowKey={r => r.id}
            searchFields={r => [r.memberName, r.memberCode, r.status, r.planName]} searchPlaceholder={searchPlaceholder}
            searchValue={memberOverviewSearch} onSearchChange={setMemberOverviewSearch}
            isLoading={isLoading} emptyMessage="No records for the selected dates" />
        ) : reportType === 'recentActivity' ? (
          <RecordsTable key={`recentActivity:${recentActivityRange.start}:${recentActivityRange.end}`}
            title="Recent Activity" subtitle="Recent events and visits for the selected dates." pageSize={12} fillPage
            columns={recentActivityColumns} rows={recentActivityRows} rowKey={r => r.id}
            searchFields={r => [r.memberName, r.memberCode, r.message, r.type, r.day]} searchPlaceholder={searchPlaceholder}
            searchValue={recentActivitySearch} onSearchChange={setRecentActivitySearch}
            isLoading={isLoading} emptyMessage="No records for the selected dates" />
        ) : (
          <RecordsTable
            key={`generate-inactive:${generateInactiveRange.start}:${generateInactiveRange.end}:${roleFilter}`}
            title="Inactive Members & Trainers – Export Preview"
            subtitle="All rows will be included in the selected export format."
            pageSize={12}
            fillPage
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
