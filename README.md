# daycarebackoffice

Daycare Backoffice

## Latest Release

- Version `1.0.33+34`
- Added a `Signed Parent Documents` section so backoffice can open and print the daycare contract and each child photo permission saved by the parent
- Parent documents now open in printable PDF preview with the written form content and stored signature
- Parent-signed PDFs are now also persisted in Firebase Storage from the parent app under `tenants/{tenantId}/parent_forms/{parentId}/...`
- `Today Summary` and `Latest Update` now also mirror into the child root document for faster and more reliable parent reads
- `Parent Updates` now reloads the saved `Today Summary` tags and `Latest Update` note/photo for the selected child
- Clarified `Parent Updates` so the selected child is explicit when saving `Today Summary` or publishing `Latest Update`
- Added a real `Parent Updates` composer in backoffice to publish `Latest Update` photos only for children with signed photo permission
- Added functional `Today Summary` publishing from backoffice for parent-facing daily tags
- Refined mobile `Quick Actions` into a 2x2 grid so actions fit cleanly on phones
- Added a dedicated mobile `Quick Actions` strip so `Add Staff`, `Household`, `Add Parent`, and `Add Child` stay visible on phones
- Restyled the `Add Household Member` dialog to match the wider card-based layout used by `Add Staff`
- Household member form now supports `Upload Photo` and `Take Photo` for physical exam and fingerprint documents
- Household document images now store under a dedicated `household_documents` path in Firebase Storage
- Household member form no longer depends on selecting a child
- Reordered sidebar quick actions to `Add Staff`, `Add Household Member`, `Add Parent`, `Add Child`
- Added a real Staff module with role tracking, DOB, and compliance documents
- Staff records now support submitted/expire dates for background check, physical, drug administration license, and CPR
- Added photo upload/take-photo options for each staff document
- Refreshed the backoffice UI with a warmer, more colorful visual style closer to the parent app
- Reorganized the main layout for cleaner desktop and tablet presentation
- Removed duplicated action sections from the profile screen and centralized actions in the sidebar
- Added `Add Staff` to the sidebar quick actions and unified button styling
- Simplified the tenant profile screen by removing extra lists and the children filter dropdown
- Added a global `Notifications` button in the app bar for pickup alerts
- Notification button turns red when pending alerts exist
- Notifications open in a modal and show sent time, ETA, and estimated arrival time
- Added sound when a new pickup alert arrives
- Notifications now show all child names linked to the parent when more than one child exists
- Pickup notification text now prioritizes the parent name instead of the child name
- Parent name is now shown more prominently inside each pickup notification
- Parent name now resolves from the real parent record when older notifications are missing that field

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
