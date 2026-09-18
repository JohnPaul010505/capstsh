/**
 * Shared app background: deep navy base + the "futuristic neon" light-trail
 * atmosphere + dark vignette. Rendered once per route (AdminLayout, Login,
 * public QR enrollment) so every screen shares the same backdrop.
 */
export default function AppBackground() {
  return (
    <>
      {/* Base background */}
      <div
        className="fixed inset-0 -z-30 admin-base-bg bg-page"
        aria-hidden="true"
      />

      {/* Main atmospheric background */}
      <div
        className="pointer-events-none fixed inset-0 -z-20 overflow-hidden theme-atmosphere [contain:paint]"
        aria-hidden="true"
      >
        {/* =================================
            LARGE PURPLE LIGHT TRAIL - TOP LEFT
            ================================= */}
        <div className="absolute -left-[420px] -top-[420px] h-[850px] w-[1450px] rotate-[-18deg] rounded-[50%] bg-gradient-to-br from-purple-500/42 via-indigo-500/24 to-transparent blur-[3px] shadow-[0_0_70px_rgba(139,92,246,0.55),0_0_150px_rgba(139,92,246,0.32)]" />

        {/* Soft glow around top-left trail.
            Radial gradient instead of blur(130px): same softness, but it does
            not cost a 1000x600 composited filter layer on every repaint. */}
        <div className="absolute -left-[340px] -top-[340px] h-[780px] w-[1180px] bg-[radial-gradient(closest-side,rgba(139,92,246,0.34),rgba(139,92,246,0.12)_58%,transparent)]" />

        {/* =================================
            BLUE LIGHT TRAIL - TOP RIGHT
            ================================= */}
        <div className="absolute -right-[500px] -top-[320px] h-[700px] w-[1300px] rotate-[12deg] rounded-[50%] bg-gradient-to-bl from-blue-500/42 via-indigo-500/24 to-transparent blur-[3px] shadow-[0_0_75px_rgba(59,130,246,0.55),0_0_160px_rgba(59,130,246,0.32)]" />

        {/* Blue atmospheric glow */}
        <div className="absolute right-[-150px] top-[-190px] h-[640px] w-[820px] bg-[radial-gradient(closest-side,rgba(59,130,246,0.34),rgba(59,130,246,0.12)_58%,transparent)]" />

        {/* =================================
            LARGE INDIGO SWEEP - CENTER
            ================================= */}
        <div className="absolute left-[15%] top-[5%] h-[850px] w-[1500px] rotate-[-8deg] rounded-[50%] bg-gradient-to-br from-indigo-500/26 via-indigo-500/14 to-transparent blur-[3px] shadow-[0_0_90px_rgba(99,102,241,0.34),0_0_180px_rgba(99,102,241,0.20)]" />

        {/* Center blue/purple atmosphere */}
        <div className="absolute left-[33%] top-[12%] h-[640px] w-[820px] bg-[radial-gradient(closest-side,rgba(99,102,241,0.30),rgba(99,102,241,0.10)_58%,transparent)]" />

        {/* =================================
            PURPLE SWEEP - BOTTOM RIGHT
            ================================= */}
        <div className="absolute -right-[420px] -bottom-[480px] h-[900px] w-[1500px] rotate-[-15deg] rounded-[50%] bg-gradient-to-tl from-purple-500/44 via-violet-500/22 to-transparent blur-[3px] shadow-[0_0_80px_rgba(139,92,246,0.58),0_0_170px_rgba(139,92,246,0.34)]" />

        {/* Stronger bottom-right glow */}
        <div className="absolute right-[-130px] bottom-[-210px] h-[680px] w-[800px] bg-[radial-gradient(closest-side,rgba(139,92,246,0.40),rgba(139,92,246,0.14)_58%,transparent)]" />

        {/* =================================
            BLUE SWEEP - BOTTOM LEFT
            ================================= */}
        <div className="absolute -left-[500px] -bottom-[500px] h-[850px] w-[1400px] rotate-[12deg] rounded-[50%] bg-gradient-to-tr from-blue-500/42 via-indigo-500/24 to-transparent blur-[3px] shadow-[0_0_75px_rgba(59,130,246,0.55),0_0_160px_rgba(59,130,246,0.32)]" />

        {/* Bottom-left blue glow */}
        <div className="absolute left-[-170px] bottom-[-180px] h-[600px] w-[720px] bg-[radial-gradient(closest-side,rgba(59,130,246,0.34),rgba(59,130,246,0.12)_58%,transparent)]" />

        {/* =================================
            SMALL LIGHT SOURCES
            ================================= */}
        <div className="absolute left-[42%] top-[-110px] h-[380px] w-[520px] bg-[radial-gradient(closest-side,rgba(168,85,247,0.30),rgba(168,85,247,0.10)_58%,transparent)]" />
        <div className="absolute right-[24%] top-[9%] h-[360px] w-[480px] bg-[radial-gradient(closest-side,rgba(59,130,246,0.28),rgba(59,130,246,0.10)_58%,transparent)]" />

        {/* Extra ambient bloom: keeps the middle-left and mid-right from
            going flat without adding another composited blur layer. */}
        <div className="absolute left-[6%] top-[34%] h-[520px] w-[560px] bg-[radial-gradient(closest-side,rgba(139,92,246,0.24),rgba(139,92,246,0.08)_60%,transparent)]" />
        <div className="absolute right-[8%] top-[40%] h-[460px] w-[520px] bg-[radial-gradient(closest-side,rgba(56,189,248,0.20),rgba(56,189,248,0.07)_60%,transparent)]" />
      </div>

      {/* =================================
          DARK VIGNETTE
          Keeps the center readable
          ================================= */}
      <div
        className="pointer-events-none fixed inset-0 -z-10 theme-vignette"
        aria-hidden="true"
      />
    </>
  )
}