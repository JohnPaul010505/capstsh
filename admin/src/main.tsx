import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { ThemeProvider } from './contexts/ThemeContext'
import App from './App'
import './index.css'

/**
 * Global cache policy.
 *
 * Every dashboard tab used to run with TanStack Query's defaults, which are
 * `staleTime: 0` — so a cached result was considered stale the instant it
 * arrived. Switching tabs, or re-picking a date range you had already viewed,
 * therefore re-ran the whole multi-page fetch (6,400-42,100 rows) and the panel
 * sat on "Loading…" for seconds each time.
 *
 * These defaults make a range load ONCE. A result stays fresh for 5 minutes
 * (returning to a tab or re-picking a previous range is a 0ms cache read), and
 * is kept in memory for 30 minutes so it survives tab switches without being
 * garbage collected. `refetchOnWindowFocus` is off for the same reason:
 * alt-tabbing back to the window used to silently trigger a full refetch of
 * every visible tab.
 */
const FIVE_MIN = 5 * 60_000
const THIRTY_MIN = 30 * 60_000

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: FIVE_MIN,
      gcTime: THIRTY_MIN,
      refetchOnWindowFocus: false,
      refetchOnReconnect: false,
      retry: 1,
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <ThemeProvider>
          <App />
        </ThemeProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
)
