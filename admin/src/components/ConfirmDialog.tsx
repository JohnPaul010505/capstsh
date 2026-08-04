import { LogOut } from 'lucide-react'

interface ConfirmDialogProps {
  open: boolean
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  onConfirm: () => void
  onCancel: () => void
}

export default function ConfirmDialog({ open, title, message, confirmLabel = 'Yes', cancelLabel = 'Cancel', onConfirm, onCancel }: ConfirmDialogProps) {
  if (!open) return null

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={onCancel}>
      <div className="glass-card rounded-xl shadow-xl max-w-sm w-full mx-4 border border-white/10" onClick={e => e.stopPropagation()}>
        <div className="px-6 py-5 text-center">
          <div className="w-12 h-12 bg-[#EF4444]/15 rounded-full flex items-center justify-center mx-auto mb-4">
            <LogOut className="w-6 h-6 text-[#EF4444]" />
          </div>
          <h2 className="text-lg font-semibold text-[#ECECFC] mb-2">{title}</h2>
          <p className="text-sm text-[#B4B4D0]">{message}</p>
        </div>
        <div className="px-6 py-4 border-t border-white/10 flex justify-end gap-3">
          <button onClick={onCancel} className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">
            {cancelLabel}
          </button>
          <button onClick={onConfirm} className="px-4 py-2 text-sm bg-[#EF4444] text-white rounded-lg hover:bg-[#DC2626]">
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
