import { cn } from '@/lib/utils'

export default function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    active: 'bg-[#22C55E]/15 text-accent-green',
    inactive: 'bg-[#F59E0B]/15 text-accent-amber',
    expired: 'bg-[#EF4444]/15 text-accent-red',
    cancelled: 'bg-[#55557A]/20 text-fg',
    in_progress: 'bg-[#3B82F6]/15 text-accent-blue',
    expiring: 'bg-[#F59E0B]/15 text-accent-amber',
    ending_soon: 'bg-[#3B82F6]/15 text-accent-blue',
    high: 'bg-[#22C55E]/15 text-accent-green',
    medium: 'bg-[#F59E0B]/15 text-accent-amber',
    low: 'bg-[#EF4444]/15 text-accent-red',
  }

  return (
    <span className={cn(
      'px-2 py-0.5 rounded-full text-xs font-medium',
      colors[status] || 'bg-[#55557A]/20 text-fg'
    )}>
      {status.replace('_', ' ')}
    </span>
  )
}
