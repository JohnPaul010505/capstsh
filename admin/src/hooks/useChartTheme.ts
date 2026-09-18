import { useMemo } from 'react'
import { useTheme } from '@/contexts/ThemeContext'

/**
 * Recharts accepts colours as JavaScript props, so the `html.theme-light`
 * overrides in index.css cannot reach them. This hook supplies the axis, grid
 * and tooltip colours for the active theme.
 *
 * The dark values are byte-for-byte the literals that were previously inline in
 * the pages, so dark mode is unchanged.
 */

const DARK = {
  axis: '#9494BD',
  grid: 'rgba(255, 255, 255, 0.04)',
  axisLine: 'rgba(255, 255, 255, 0.06)',
  cursor: 'rgba(255, 255, 255, 0.04)',
  tooltipBg: 'rgba(20, 20, 42, 0.9)',
  tooltipBorder: 'rgba(255, 255, 255, 0.1)',
  tooltipFg: '#ECECFC',
  tooltipLabel: '#B4B4D0',
} as const

const LIGHT = {
  axis: '#64748B',
  grid: 'rgba(15, 23, 42, 0.07)',
  axisLine: 'rgba(15, 23, 42, 0.1)',
  cursor: 'rgba(15, 23, 42, 0.04)',
  tooltipBg: 'rgba(255, 255, 255, 0.97)',
  tooltipBorder: 'rgba(15, 23, 42, 0.1)',
  tooltipFg: '#0F172A',
  tooltipLabel: '#475569',
} as const

export interface ChartTheme {
  axis: string
  grid: string
  axisLine: string
  cursor: string
  tooltipBg: string
  tooltipBorder: string
  tooltipFg: string
  tooltipLabel: string
  axisTick: { fill: string; fontSize: number }
  axisTickSm: { fill: string; fontSize: number }
  axisLineStyle: { stroke: string }
  tooltipStyle: {
    backgroundColor: string
    backdropFilter: string
    border: string
    borderRadius: number
    color: string
  }
}

export function useChartTheme(): ChartTheme {
  const { theme } = useTheme()

  return useMemo(() => {
    const t = theme === 'light' ? LIGHT : DARK
    return {
      ...t,
      axisTick: { fill: t.axis, fontSize: 11 },
      axisTickSm: { fill: t.axis, fontSize: 12 },
      axisLineStyle: { stroke: t.axisLine },
      tooltipStyle: {
        backgroundColor: t.tooltipBg,
        backdropFilter: 'blur(8px)',
        border: `1px solid ${t.tooltipBorder}`,
        borderRadius: 10,
        color: t.tooltipFg,
      },
    }
  }, [theme])
}