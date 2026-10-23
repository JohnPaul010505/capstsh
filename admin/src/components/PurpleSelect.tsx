import * as Select from '@radix-ui/react-select'
import { Check, ChevronDown } from 'lucide-react'

interface Props<T extends string> {
  value: T
  onChange: (value: T) => void
  label: string
  options: readonly { value: T; label: string }[]
}

export default function PurpleSelect<T extends string>({ value, onChange, label, options }: Props<T>) {
  return (
    <Select.Root value={value} onValueChange={value => onChange(value as T)}>
      <Select.Trigger aria-label={label} className="purple-control inline-flex h-[40px] shrink-0 items-center justify-between gap-3 rounded-xl px-3 text-xs font-medium cursor-pointer">
        <Select.Value />
        <Select.Icon><ChevronDown className="h-3.5 w-3.5" /></Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content position="popper" sideOffset={6} collisionPadding={12} className="purple-menu z-50 min-w-[var(--radix-select-trigger-width)] max-h-[var(--radix-select-content-available-height)] overflow-hidden rounded-xl p-1.5">
          <Select.Viewport>
            {options.map(option => (
              <Select.Item key={option.value} value={option.value} className="relative cursor-pointer rounded-lg py-2.5 pl-8 pr-3 text-xs outline-none data-[highlighted]:bg-violet-500/20 data-[state=checked]:bg-violet-500/15">
                <Select.ItemIndicator className="absolute left-2"><Check className="h-4 w-4" /></Select.ItemIndicator>
                <Select.ItemText>{option.label}</Select.ItemText>
              </Select.Item>
            ))}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  )
}
