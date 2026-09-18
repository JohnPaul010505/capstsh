import type { Config } from 'tailwindcss'

export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          950: '#080A1F',
          900: '#0D1028',
          800: '#121632',
          700: '#181D40',
        },
        // Theme-aware neutrals. The values live in index.css: :root holds the
        // original dark colours, html.theme-light swaps them, so dark mode is
        // unaffected and light mode adapts without any `dark:` variants.
        'fg-strong': 'var(--fg-strong)',
        fg: 'var(--fg)',
        'fg-muted': 'var(--fg-muted)',
        'fg-faint': 'var(--fg-faint)',
        line: 'var(--line)',
        'line-soft': 'var(--line-soft)',
        'overlay-3': 'var(--overlay-3)',
        'overlay-4': 'var(--overlay-4)',
        'overlay-5': 'var(--overlay-5)',
        'overlay-6': 'var(--overlay-6)',
        'overlay-8': 'var(--overlay-8)',
        'overlay-10': 'var(--overlay-10)',
        // RGB triplets so opacity modifiers keep working (bg-elevated/90).
        page: 'rgb(var(--page-rgb) / <alpha-value>)',
        'page-deep': 'rgb(var(--page-deep-rgb) / <alpha-value>)',
        elevated: 'rgb(var(--elevated-rgb) / <alpha-value>)',
        skeleton: 'rgb(var(--skeleton-rgb) / <alpha-value>)',
        // Accent text colours (bright on dark, darkened on light).
        'accent-purple': 'var(--accent-purple)',
        'accent-green': 'var(--accent-green)',
        'accent-blue': 'var(--accent-blue)',
        'accent-amber': 'var(--accent-amber)',
        'accent-red': 'var(--accent-red)',
      }
    },
  },
  plugins: [],
} satisfies Config
