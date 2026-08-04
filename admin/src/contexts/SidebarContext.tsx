import { createContext, useContext, useState, type ReactNode } from 'react'

interface SidebarContextType {
  collapsed: boolean
  setCollapsed: (v: boolean) => void
}

const SidebarContext = createContext<SidebarContextType>({
  collapsed: true,
  setCollapsed: () => {},
})

export function SidebarProvider({ children }: { children: ReactNode }) {
  const [collapsed, setCollapsed] = useState(true)

  return (
    <SidebarContext.Provider value={{ collapsed, setCollapsed }}>
      {children}
    </SidebarContext.Provider>
  )
}

export function useSidebar() {
  return useContext(SidebarContext)
}
