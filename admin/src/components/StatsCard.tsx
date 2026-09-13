import { type LucideIcon } from 'lucide-react'
import { AreaChart, Area, ResponsiveContainer } from 'recharts'

interface StatsCardProps {
  title: string
  value: number
  icon: LucideIcon
  trend?: {
    value: number
    label: string
  }
  sparkData?: Array<{ value: number }>
}

export default function StatsCard({ title, value, icon: Icon, trend, sparkData }: StatsCardProps) {
  const displaySpark = sparkData && sparkData.length > 1
  return (
    <div className="glass-card rounded-xl p-4 border border-white/10 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs text-[#7A7AA0] truncate">{title}</p>
          <p className="text-xl font-bold text-[#ECECFC] mt-1">{value.toLocaleString()}</p>
          {trend && (
            <p className={`text-xs mt-1 font-medium ${trend.value >= 0 ? 'text-[#4ADE80]' : 'text-[#EF4444]'}`}>
              {trend.value >= 0 ? '+' : ''}{trend.value}% {trend.label}
            </p>
          )}
        </div>
        <div className="flex items-center gap-3 shrink-0">
          {displaySpark && (
            <div className="w-16 h-10">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={sparkData}>
                  <Area type="monotone" dataKey="value" stroke="#7C3AED" strokeWidth={2} fill="rgba(124,58,237,0.15)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
          <div className="w-9 h-9 rounded-lg bg-[#7C3AED]/20 border border-[#7C3AED]/25 flex items-center justify-center">
            <Icon className="w-4 h-4 text-[#C084FC]" />
          </div>
        </div>
      </div>
    </div>
  )
}
