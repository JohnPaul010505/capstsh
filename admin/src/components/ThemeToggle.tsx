import { useTheme } from '@/contexts/ThemeContext'
import './ThemeToggle.css'

const STAR_PATH =
  'M 0 10 C 10 10,10 10 ,0 10 C 10 10 , 10 10 , 10 20 C 10 10 , 10 10 , 20 10 C 10 10 , 10 10 , 10 0 C 10 10,10 10 ,0 10 Z'

export default function ThemeToggle() {
  const { theme, toggleTheme } = useTheme()
  const isDark = theme === 'dark'

  return (
    <label
      className="theme-switch"
      title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
    >
      <input
        type="checkbox"
        role="switch"
        checked={isDark}
        onChange={toggleTheme}
        aria-label="Dark mode"
      />
      <span className="theme-slider round">
        <span className="theme-cloud theme-cloud-1" aria-hidden="true">
          <svg viewBox="0 0 64 32">
            <ellipse cx="22" cy="20" rx="18" ry="11" />
            <ellipse cx="40" cy="16" rx="14" ry="12" />
            <ellipse cx="50" cy="22" rx="12" ry="9" />
          </svg>
        </span>
        <span className="theme-cloud theme-cloud-2" aria-hidden="true">
          <svg viewBox="0 0 64 32">
            <ellipse cx="22" cy="20" rx="18" ry="11" />
            <ellipse cx="40" cy="16" rx="14" ry="12" />
            <ellipse cx="50" cy="22" rx="12" ry="9" />
          </svg>
        </span>
        <span className="theme-cloud theme-cloud-3" aria-hidden="true">
          <svg viewBox="0 0 64 32">
            <ellipse cx="22" cy="20" rx="18" ry="11" />
            <ellipse cx="40" cy="16" rx="14" ry="12" />
            <ellipse cx="50" cy="22" rx="12" ry="9" />
          </svg>
        </span>

        <span className="theme-stars" aria-hidden="true">
          <svg className="theme-star theme-star-1" viewBox="0 0 20 20">
            <path d={STAR_PATH} />
          </svg>
          <svg className="theme-star theme-star-2" viewBox="0 0 20 20">
            <path d={STAR_PATH} />
          </svg>
          <svg className="theme-star theme-star-3" viewBox="0 0 20 20">
            <path d={STAR_PATH} />
          </svg>
          <svg className="theme-star theme-star-4" viewBox="0 0 20 20">
            <path d={STAR_PATH} />
          </svg>
        </span>

        <span className="theme-sun-moon">
          <svg className="moon-dot moon-dot-1" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="50" />
          </svg>
          <svg className="moon-dot moon-dot-2" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="50" />
          </svg>
          <svg className="moon-dot moon-dot-3" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="50" />
          </svg>
        </span>
      </span>
    </label>
  )
}