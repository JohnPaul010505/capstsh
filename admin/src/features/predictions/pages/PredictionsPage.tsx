import { useState } from 'react'
import { usePredictions, useGeneratePredictions, useMembersSimple, type MemberOption } from '../hooks/usePredictions'
import { TrendingUp, TrendingDown, RefreshCw, Sparkles, AlertCircle } from 'lucide-react'
import StatusBadge from '@/components/StatusBadge'
import { MemberSelect } from '@/components/MemberSelect'

export default function PredictionsPage() {
  const [selectedMemberId, setSelectedMemberId] = useState('')
  const [aiResults, setAiResults] = useState<any[] | null>(null)
  const [aiResultSource, setAiResultSource] = useState<'ai' | 'fallback' | null>(null)
  const [generating, setGenerating] = useState(false)

  const { data: predictions } = usePredictions()
  const { data: members } = useMembersSimple()
  const generateMutation = useGeneratePredictions()

  const generatePredictions = async () => {
    if (!selectedMemberId) return
    setGenerating(true)
    setAiResults(null)
    setAiResultSource(null)
    try {
      const result: { data: any; source: 'ai' | 'fallback' } = await generateMutation.mutateAsync({ memberId: selectedMemberId, daysAhead: 30 })
      setAiResults(Array.isArray(result.data) ? result.data : (result.data.results ?? result.data))
      setAiResultSource(result.source)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to generate predictions')
    } finally {
      setGenerating(false)
    }
  }

  const memberOptions: { id: string; label: string }[] = (members ?? []).map((m: MemberOption) => ({
    id: m.id,
    label: `${m.full_name} (${m.code ?? '—'}) — ${m.email}`,
  }))
  const selectedMember = members?.find(m => m.id === selectedMemberId)

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div className="glass-card p-4 rounded-xl">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <TrendingUp className="w-4 h-4 text-[#22C55E]" />
            <span>Total Predictions</span>
          </div>
          <p className="text-xl font-bold text-fg-strong">{predictions?.length ?? 0}</p>
          <p className="text-xs text-fg-muted mt-1">Latest 50 persisted forecasts</p>
        </div>
        <div className="glass-card p-4 rounded-xl relative z-30">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <Sparkles className="w-4 h-4 text-accent-purple" />
            <span>Generate New</span>
          </div>
          <div className="flex items-center gap-2">
            <MemberSelect
              options={memberOptions}
              value={selectedMemberId}
              onChange={setSelectedMemberId}
              placeholder="Select member..."
              className="flex-1 min-w-0"
            />
            <button
              onClick={generatePredictions}
              disabled={!selectedMemberId || generating}
              className="flex items-center gap-1 px-3 py-2 text-sm bg-gradient-to-r from-[#7C3AED] to-[#3B82F6] text-white rounded-lg hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {generating ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
              {generating ? 'Generating...' : 'Generate'}
            </button>
          </div>
        </div>
        <div className="glass-card p-4 rounded-xl">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <TrendingDown className="w-4 h-4 text-[#F59E0B]" />
            <span>High Confidence</span>
          </div>
          <p className="text-xl font-bold text-fg-strong">
            {predictions?.filter(p => p.confidence >= 0.7).length ?? 0}
          </p>
          <p className="text-xs text-fg-muted mt-1">Confidence &gt;= 70%</p>
        </div>
      </div>

      {aiResults && aiResults.length > 0 && (
        <div className="bg-gradient-to-r from-[#7C3AED]/10 to-[#3B82F6]/10 p-4 rounded-xl border border-[#7C3AED]/30 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base font-semibold text-fg-strong">
              Last Generated Results — {selectedMember?.full_name ?? 'Member'}
            </h2>
            {aiResultSource === 'fallback' && (
              <div className="flex items-center gap-1 px-2 py-1 text-xs rounded-full bg-[#F59E0B]/15 text-[#F59E0B]">
                <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                <span>AI service offline — local estimate, not persisted</span>
              </div>
            )}
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {aiResults.map((r, i) => (
              <div key={i} className="bg-overlay-8 p-4 rounded-lg border border-line shadow-sm">
                <p className="text-sm font-medium capitalize text-fg">{String(r.prediction_type).replace(/_/g, ' ')}</p>
                <p className="text-xl font-bold text-fg-strong mt-1">{r.predicted_value}</p>
                <p className="text-xs text-fg-muted">
                  Current: {r.current_value} {r.unit} &middot; {r.days_ahead}d ahead
                </p>
                <div className="mt-2">
                  <StatusBadge status={r.confidence >= 0.7 ? 'high' : r.confidence >= 0.4 ? 'medium' : 'low'} />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
        <div className="px-4 py-3 border-b border-line">
          <h2 className="font-semibold text-fg-strong">Recent Predictions</h2>
        </div>
        {predictions?.length === 0 ? (
          <div className="text-center py-6 text-fg-muted">No predictions yet. Select a member and click Generate.</div>
        ) : (
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Metric</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Predicted</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Confidence</th>
                </tr>
              </thead>
              <tbody>
                {predictions?.map(p => (
                  <tr key={p.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-fg-strong">{p.profiles?.full_name}</td>
                    <td className="px-3 py-2 text-sm text-fg capitalize">{String(p.metric_name).replace(/_/g, ' ')}</td>
                    <td className="px-3 py-2 text-sm text-fg">{p.predicted_value}</td>
                    <td className="px-3 py-2">
                      <StatusBadge status={p.confidence >= 0.7 ? 'high' : p.confidence >= 0.4 ? 'medium' : 'low'} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
