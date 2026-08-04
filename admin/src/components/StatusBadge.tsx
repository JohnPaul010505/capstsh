import { cn } from '@/lib/utils'

export default function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    active: 'bg-[#22C55E]/15 text-[#4ADE80]',
    inactive: 'bg-[#F59E0B]/15 text-[#FBBF24]',
    expired: 'bg-[#EF4444]/15 text-[#F87171]',
    cancelled: 'bg-[#55557A]/20 text-[#B4B4D0]',
    in_progress: 'bg-[#3B82F6]/15 text-[#60A5FA]',
    expiring: 'bg-[#F59E0B]/15 text-[#FBBF24]',
    ending_soon: 'bg-[#3B82F6]/15 text-[#60A5FA]',
    high: 'bg-[#22C55E]/15 text-[#4ADE80]',
    medium: 'bg-[#F59E0B]/15 text-[#FBBF24]',
    low: 'bg-[#EF4444]/15 text-[#F87171]',
  }

  return (
    <span className={cn(
      'px-2 py-0.5 rounded-full text-xs font-medium',
      colors[status] || 'bg-[#55557A]/20 text-[#B4B4D0]'
    )}>
      {status.replace('_', ' ')}
    </span>
  )
}
