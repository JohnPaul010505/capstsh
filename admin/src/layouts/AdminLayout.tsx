import { type ReactNode } from 'react'
import { SidebarProvider } from '@/contexts/SidebarContext'
import Sidebar from './Sidebar'
import Header from './Header'

function LayoutInner({ children }: { children: ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden bg-[#0D0D1A]">
      <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:px-4 focus:py-2 focus:rounded-lg focus:bg-[#7C3AED] focus:text-white focus:text-sm">Skip to content</a>
      <div className="fixed inset-0 app-bg-image -z-10" aria-hidden="true" />
      <div className="fixed inset-0 bg-[#0D0D1A]/70 backdrop-blur-[3px] -z-10" aria-hidden="true" />
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header />
        <main id="main-content" className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider>
      <LayoutInner>{children}</LayoutInner>
    </SidebarProvider>
  )
}
