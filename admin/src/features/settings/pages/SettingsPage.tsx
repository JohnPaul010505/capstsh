import AdminProfileCard from '../components/AdminProfileCard'

/**
 * The settings page is no longer in the sidebar - the admin's own profile and
 * the sign-out button live in the menu behind their name in the header - but the
 * route stays, so a bookmarked or typed `/settings` still lands somewhere real
 * and the release-gate route sweep has a page to check.
 */
export default function SettingsPage() {
  return (
    <div className="space-y-3">
      <AdminProfileCard />
    </div>
  )
}
