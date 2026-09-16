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
        }
      }
    },
  },
  plugins: [],
} satisfies Config
