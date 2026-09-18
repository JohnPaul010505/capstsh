import { LogOut } from 'lucide-react'
import { useEffect } from 'react'
import { createPortal } from 'react-dom'

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
  // Escape-to-close while the dialog is open.
  useEffect(function () {
    if (!open) return
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', onKey)
    return function () {
      window.removeEventListener('keydown', onKey)
    }
  }, [open, onCancel])

  if (!open) return null

  return createPortal(
    <div className="fixed inset-0 z-[70] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4" onClick={function (e) { if (e.target === e.currentTarget) onCancel() }}>
      <div className="glass-strong w-full max-w-sm" onClick={function (e) { e.stopPropagation() }}>
        <div className="px-6 py-5 text-center">
          <div className="w-12 h-12 bg-[#EF4444]/15 rounded-full flex items-center justify-center mx-auto mb-4">
            <LogOut className="w-6 h-6 text-[#EF4444]" />
          </div>
          <h2 className="text-lg font-semibold text-fg-strong mb-2">{title}</h2>
          <p className="text-sm text-fg">{message}</p>
        </div>
        <div className="px-6 py-4 border-t border-line flex justify-end gap-3">
          <button onClick={onCancel} className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">
            {cancelLabel}
          </button>
          <button onClick={onConfirm} className="px-4 py-2 text-sm bg-[#EF4444] text-white rounded-lg hover:bg-[#DC2626]">
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>,
    document.body
  )
}
