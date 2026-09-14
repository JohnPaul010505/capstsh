import { type LucideIcon } from 'lucide-react'
import { AreaChart, Area, ResponsiveContainer } from 'recharts'

type IconVariant = 'purple' | 'blue' | 'green'

interface StatsCardProps {
  title: string
  value: number
  icon: LucideIcon
  trend?: {
    value: number
    label: string
  }
  sparkData?: Array<{ value: number }>
  iconVariant?: IconVariant
  sparkColor?: string
}

const variantStyles: Record<IconVariant, string> = {
  purple: 'bg-[#7C3AED]/20 border border-[#7C3AED]/25 text-[#C084FC]',
  blue: 'bg-[#3B82F6]/20 border border-[#3B82F6]/25 text-[#60A5FA]',
  green: 'bg-[#22C55E]/20 border border-[#22C55E]/25 text-[#4ADE80]',
  emerald: 'bg-[#10B981]/20 border border-[#10B981]/25 text-[#34D399]',
}

export default function StatsCard({ title, value, icon: Icon, trend, sparkData, iconVariant = 'purple', sparkColor }: StatsCardProps) {
  const displaySpark = sparkData && sparkData.length > 1
  const stroke = sparkColor || '#7C3AED'
  return (
    <div className="glass-card rounded-[12px] p-4 border border-white/10 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[12px] text-[#7A7AA0] truncate">{title}</p>
          <p className="text-[30px] font-bold text-[#ECECFC] mt-1 leading-none">{value.toLocaleString()}</p>
          {trend && (
            <p className={`text-[11px] mt-1.5 font-medium ${trend.value >= 0 ? 'text-[#4ADE80]' : 'text-[#EF4444]'}`}>
              {trend.value >= 0 ? '+' : ''}{trend.value}% {trend.label}
            </p>
          )}
        </div>
        <div className="flex items-center gap-3 shrink-0">
          {displaySpark && (
            <div className="w-16 h-10">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={sparkData}>
                  <Area type="monotone" dataKey="value" stroke={stroke} strokeWidth={2} fill="transparent" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
          {Icon && <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${variantStyles[iconVariant]}`}>
            <Icon className="w-4 h-4" />
          </div>}
        </div>
      </div>
    </div>
  )
}
