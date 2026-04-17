# VOR Request System — Canvas App specification

Paste the sections below into Claude Code after running `/generate-canvas-app`. Claude Code will ask clarifying questions as it parses the spec; answer them from context, and let it generate the YAML in passes rather than all at once. Start-simple-and-iterate is the right approach — the plugin handles incremental edits well via `/edit-canvas-app`.

## Context

This Canvas App is the internal Vehicle Off Road (VOR) parts request workflow for BCI Sales Pty Ltd. BCI distributes SITRAK/Sinotruk heavy truck parts in Australia. A VOR request is raised when a truck is out of service and a part is needed; the request moves through validation, orderer processing, ordering, receiving, dispatch, and closure.

Primary users:
- **Workshop technicians** — submit their own VOR requests when a truck they're working on needs a part
- **Parts team** — submit requests on behalf of external customers (who phone or email in), plus handle all downstream stages
- **Reviewer** (parts team lead) — signs off or rejects requests before ordering

The app targets tablets (workshop iPads) and desktops (parts team PCs). Use Microsoft Fluent styling to match Teams and Loop, which the team already uses daily.

## Prerequisite (do this before running /generate-canvas-app)

The SharePoint list that backs the app must already exist in the BCI tenant. Provision the list named `VORRequests` with the columns specified in the *Data source* section below before connecting the app to it. If the list doesn't exist yet, ask Claude Code to write a PnP.PowerShell script to create it first — that's a separate step from Canvas App generation.

## Data source

SharePoint Online list: `VORRequests`

| Column | Type | Notes |
|---|---|---|
| Title | Single line of text | Auto-generated VOR reference, format `VOR-NNNN` |
| IdentifierType | Choice | `VIN` / `Stock#` |
| VehicleIdentifier | Single line of text | The VIN or Stock# itself |
| SubmittedOnBehalfOf | Choice | `Workshop (self)` / `Customer` |
| CustomerName | Single line of text | Required only when SubmittedOnBehalfOf = Customer |
| FaultDescription | Multiple lines of text | |
| PartName | Single line of text | |
| PartNumber | Single line of text | Optional |
| Quantity | Number | Integer ≥ 1 |
| Urgency | Choice | `Safety critical` / `Operational` / `Scheduled` |
| RequestorName | Single line of text | Defaults to User().FullName |
| DateSubmitted | Date and time | Auto-set on submission |
| CurrentStatus | Choice | `Draft` / `Submitted` / `Validation` / `Orderer processing` / `Parts ordered` / `Parts received` / `Dispatched` / `Closed` / `Rejected` |
| AssignedReviewer | Person or group | |
| AssignedOrderer | Person or group | |
| RejectionReason | Multiple lines of text | Populated only on rejection |
| SignOffDate | Date and time | Set when reviewer signs off |
| PONumber | Single line of text | |
| EstimatedDeliveryDate | Date only | |
| ActualDeliveryDate | Date only | |
| DispatchRoute | Choice | `Workshop` / `Customer` |
| HandoverReference | Single line of text | Technician name for Workshop route; customer name / docket reference for Customer route |
| StageNotes | Multiple lines of text | Append-only running log, one line per stage transition: `[YYYY-MM-DD HH:mm] <actor>: <event> — <optional note>` |

## Screens

### 1. Home / Dashboard (start screen)

Scannable view of requests relevant to the current user.

- Top bar: app title "VOR Requests", logged-in user name and avatar (User() function)
- Left navigation rail: Home, New Request, My Queue, All Requests, Closed
- Main content: gallery of open requests (everything except Closed and Rejected), newest first, each row showing:
  - VOR reference
  - Vehicle identifier and type
  - Urgency badge — red for Safety critical, amber for Operational, gray for Scheduled
  - Current status badge
  - Age in days since submission
  - Requestor name, and "on behalf of" info if applicable
- Above the gallery: filter dropdowns for Status and Urgency, plus a text search box that matches against VOR reference, vehicle identifier, customer name, and part name
- Primary button top-right: "New VOR request" → navigates to screen 2

Sort order within the gallery: Safety critical always first, then Operational, then Scheduled, and within each urgency bucket, newest first.

### 2. New VOR Request (submission form)

Step 1 of the workflow. Fields in this order:

1. **Submitted on behalf of** — required, default `Workshop (self)`; radio or dropdown
2. **Customer name** — single-line text; visible and required only when #1 = Customer; hidden otherwise
3. **Vehicle identifier type** — required; `VIN` / `Stock#`
4. **Vehicle identifier** — required single-line text; the field label and placeholder change based on #3 (e.g., label reads "VIN" when VIN is selected, "Stock#" when Stock# is selected)
5. **Fault description** — required, multiline
6. **Part name** — required, single line
7. **Part number** — optional, single line
8. **Quantity** — required number, integer ≥ 1, default 1
9. **Urgency** — required radio buttons: Safety critical / Operational / Scheduled
10. **Requestor name** — auto-populated from User().FullName, editable
11. **Date submitted** — read-only, set to Now() on save

Footer:
- "Save as draft" secondary button — saves with CurrentStatus = `Draft`, returns to dashboard
- "Submit" primary button — validates, auto-generates the next VOR reference (format `VOR-NNNN`, sequential, never reused, based on max existing + 1), sets CurrentStatus = `Submitted`, appends a StageNotes entry, writes to SharePoint, returns to dashboard with a confirmation toast

Client-side validation:
- All required fields must be non-empty
- If #1 = Customer, Customer name must be non-empty
- Quantity must be a positive integer
- Do not allow Submit if validation fails; highlight offending fields inline

### 3. Request Detail

View one request; see its history; take the next action if the current user is assigned to it.

- Header: VOR reference, status badge, urgency badge
- Summary panel: all submitted fields, read-only once past `Submitted` status
- Stage progress indicator: horizontal row of 7 pills (Submitted → Validation → Orderer processing → Parts ordered → Parts received → Dispatched → Closed), current stage highlighted in primary blue, completed stages filled, upcoming stages muted grey. If status = `Rejected`, show all pipeline pills muted and display a prominent red banner above the row reading "Rejected — awaiting resubmission", with the RejectionReason text visible immediately below.
- Stage history: gallery rendering the parsed StageNotes entries in reverse chronological order — timestamp, actor, event, note
- Action panel at the bottom, contextual to current stage and current user:
  - `Submitted` or `Validation`: no user action (automated by Power Automate)
  - `Orderer processing` and current user = AssignedReviewer: **Sign off** button (sets status to `Parts ordered`, captures SignOffDate = Now(), prompts for optional note) and **Reject** button (prompts for RejectionReason, sets status to `Rejected`)
  - `Parts ordered` and current user = AssignedOrderer: **Capture PO** (fields: PONumber, EstimatedDeliveryDate — on save, no status change, just writes the PO details) and **Mark as received** (sets status to `Parts received`, sets ActualDeliveryDate = today by default, editable)
  - `Parts received` and current user is in the parts team: **Mark as dispatched** — opens a small sub-form capturing DispatchRoute (Workshop or Customer) and HandoverReference; on save, status → `Dispatched`
  - `Dispatched`: **Close VOR** — confirms completion, status → `Closed`
  - `Rejected` and current user = original requestor (for 1a submissions) OR any parts team member (for 1b submissions): the originally captured form fields become editable inline on the detail screen; the rejection reason is shown in a red callout at the top; **Resubmit** button re-runs client-side validation, appends a StageNotes entry (e.g. `[2026-04-17 14:22] J Citizen: Resubmitted after rejection — part number corrected`), clears RejectionReason, sets CurrentStatus → `Submitted`, and the request re-enters the pipeline at the validation step. The VOR reference number does not change.

### 4. My Queue

Focused view for the current user: only requests where they are the assignee AND the current status is actionable for their role.

- AssignedReviewer = current user AND CurrentStatus = `Orderer processing` → reviewer sees items awaiting sign-off
- AssignedOrderer = current user AND CurrentStatus IN (`Parts ordered`, `Parts received`) → orderer sees items needing PO capture or mark-received

Same gallery visual style as Home, but without the status filter (since it's implicit).

### 5. All Requests

Simple gallery with extensive filtering: date range (DateSubmitted), requestor, customer, urgency, status, assigned reviewer, assigned orderer. Includes Closed and Rejected.

## Design direction

- Clean Microsoft Fluent styling — matches Teams and Loop
- **BCI brand palette:**
  - Primary `#244982` (deep blue) — main buttons, nav rail background, headers, active states, links, the progress indicator's current/completed pill fill
  - Surface `#f4f4f4` (light grey) — page background, card surfaces, inactive gallery row background
  - Secondary accent `#a38039` (brand gold) — use sparingly for the VOR reference badge on each request (it should stand out as the primary identifier), section divider accents, and branded header treatments
  - Secondary accent light `#d7bb84` (pale gold) — hover state for gallery rows, subtle highlight for the row in My Queue that belongs to the current user, info callout backgrounds
- **Urgency colours (keep semantic, do not replace with brand):** Safety critical `#A32D2D` (red), Operational `#854F0B` (amber), Scheduled `#5F5E5A` (grey). These match universal conventions and shouldn't be brand-washed.
- Status badges colour-coded per stage — suggest using tints derived from the primary blue for in-progress stages, gold for reviewer-touched stages, green for Closed, red for Rejected.
- Segoe UI or system default sans-serif
- Responsive: usable on iPad in portrait for workshop floor, full-width on desktop
- Compact gallery rows (parts team scans many requests per day) — no large thumbnail images
- Status and urgency badges always visible on every screen a request appears on

## Behaviour notes

- `SubmittedOnBehalfOf` drives downstream Power Automate routing (e.g., customer-path dispatch uses a different email template). Surface a small info tooltip next to the field explaining that choosing Customer routes differently downstream.
- Urgency affects sort order across every gallery.
- VOR reference numbers increment sequentially and are never reused. If the current highest is `VOR-0127` and `VOR-0125` was deleted, the next new one is `VOR-0128`.
- `StageNotes` is append-only — never edit or overwrite previous entries. Each stage transition appends a new line.
- Rejection is NOT terminal. A rejected request can be fixed and resubmitted by the original requestor (for 1a workshop submissions) or by any parts team member (for 1b customer submissions). **Resubmission keeps the same VOR reference number** — the full history of the rejection and resubmission is preserved in StageNotes. On resubmit, CurrentStatus returns to `Submitted` and RejectionReason is cleared (but the rejection event stays visible in the StageNotes history).
- Read-only after Submitted: once a request is past `Draft` and into the main pipeline, the originally captured fields cannot be edited from the app. **Exception:** when status = `Rejected`, the originally captured fields become editable again so the submitter can fix the issue, and a visible banner explains why. Stage-specific fields (PONumber, EstimatedDeliveryDate, ActualDeliveryDate, DispatchRoute, HandoverReference) are writable only by the assigned person at their own stage.

## Out of scope for this first generation — but planned follow-ups

These are built separately after the Canvas App shell is generated, in their own Claude Code sessions:

- **Power Automate flows** for validation (step 2), reviewer notification (step 3 entry), orderer notification (step 4 onwards), and automatic status progression. These will integrate into BCI's existing Outlook workflow — the reviewer gets an email in their existing inbox rather than having to learn a new notification channel. Planned for a dedicated Claude Code session after the app shell is tested end-to-end.
- **Outlook Adaptive Cards** for inline approve/reject from email — reviewers can sign off from the email itself without opening the app. JSON templates will be authored in a dedicated Claude Code session and wired into the Power Automate flows above.
- Integration with SIMSCLOUD for part number validation (future phase)
- Attaching photos at handover (part of the workshop-parts handover improvement initiative — future phase)
- Reporting dashboard / Power BI views

When the flows and Adaptive Cards come online, this Canvas App may need small additions (e.g. surface flow run status on a request, add a "Resend notification" button on a stuck request, visibly acknowledge when approval came via email rather than the app). Those changes will be applied via `/edit-canvas-app` rather than full regeneration.

## Suggested generation order

Don't ask Claude Code to generate everything in one pass. Better sequence:

1. First pass: Home dashboard and New Request form (screens 1 and 2) with all fields wired to the SharePoint list. Test that submission works end-to-end.
2. Second pass: Request Detail (screen 3), read-only view only, no actions yet.
3. Third pass: Add the contextual action panel to Request Detail, one stage at a time (reviewer actions first, then orderer, then dispatch, then close).
4. Fourth pass: My Queue and All Requests (screens 4 and 5).
5. Fifth pass: polish — sort orders, filters, badge colors, validation messages.

Between each pass, open the app in Power Apps Studio (via the live coauthoring session) and test. Describe what's broken or missing to Claude Code in plain English; it will use `/edit-canvas-app` to patch the YAML.
