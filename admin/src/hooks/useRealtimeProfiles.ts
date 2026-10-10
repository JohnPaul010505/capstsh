import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

/**
 * Keeps profile-keyed queries live while the page is open.
 *
 * Once migration 0041 puts `profiles` in the `supabase_realtime` publication,
 * any edit to a member/trainer row — from this panel, another admin tab, or
 * the mobile app — invalidates the matching cache keys here instead of waiting
 * for a reload. When the publication is not applied yet (or realtime drops),
 * the subscription simply never fires and the explicit invalidations on every
 * mutation still carry the save, so the page degrades to refresh-on-save.
 *
 * @param ids focus the channel on these profile ids; omit for "all profiles".
 *            A focused filter keeps the Members list page from re-rendering on
 *            every trainer heartbeat-style change and vice versa.
 */
export function useRealtimeProfiles(ids?: string[]) {
  const qc = useQueryClient()

  useEffect(() => {
    const topic =
      ids && ids.length > 0 ? `profiles-${ids.length}-${ids[0]}` : 'profiles-all'
    const channel = supabase.channel(topic)

    const invalidate = (profileId?: string) => {
      qc.invalidateQueries({ queryKey: ['members'] })
      qc.invalidateQueries({ queryKey: ['trainers'] })
      if (profileId) {
        qc.invalidateQueries({ queryKey: ['member', profileId] })
        qc.invalidateQueries({ queryKey: ['trainer', profileId] })
      } else {
        qc.invalidateQueries({ queryKey: ['member'] })
        qc.invalidateQueries({ queryKey: ['trainer'] })
      }
    }

    if (ids && ids.length > 0) {
      for (const profileId of ids) {
        channel.on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'profiles',
            filter: `id=eq.${profileId}`,
          },
          () => invalidate(profileId),
        )
      }
    } else {
      channel.on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'profiles' },
        (payload: { new?: { id?: string } }) => invalidate(payload?.new?.id),
      )
    }

    channel.subscribe()
    return () => {
      void supabase.removeChannel(channel)
    }
    // ids is a render-local array in most callers; joining it keeps the effect
    // from re-subscribing on every render while still reacting to real changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qc, ids == null ? 'all' : ids.join(',')])
}
