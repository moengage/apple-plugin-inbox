---
name: native-feature-implementation
description: Create a minor version PR for apple-plugin-inbox based on a new native SDK API and SDK contract. Reads contracts remotely, implements the bridge method, updates CHANGELOG and version — then creates a PR.
parameters:
  - name: "ticket_id"
    description: "JIRA ticket ID, e.g. 'MOEN-44072'. Extracted from command text if not supplied."
    optional: true
  - name: "feature_description"
    description: "Natural language description of the feature. E.g. 'get unread inbox count', 'delete inbox entry'."
  - name: "contract_pr_url"
    description: "GitHub PR URL in mobile-sdk-contracts that adds the feature contract. E.g. 'https://github.com/moengage/mobile-sdk-contracts/pull/12'."
  - name: "ios_native_version"
    description: "Minimum native iOS SDK version required for this feature. Updates sdkVerMin in package.json and adds a '[bump] Updated MoEngage-iOS-SDK to X' CHANGELOG entry. E.g. '10.13.0'. Optional — if not provided, sdkVerMin is not updated."
    optional: true
  - name: "pluginbase_version"
    description: "MoEngagePluginBase version required for this feature. Updates pluginbaseVerMin in package.json. Optional."
    optional: true
  - name: "native_sdk_pr_url"
    description: "GitHub PR URL in MoEngage-iPhone-SDK that adds the native API. Optional — if not provided, master branch is used."
    optional: true
---

# Minor Version PR — apple-plugin-inbox

You are implementing a minor version change in `apple-plugin-inbox` that bridges a new native
iOS SDK API to hybrid frameworks via the inbox plugin bridge.

---

## Architecture overview (read before implementing)

**Inbox architecture:**

| Concern            | How inbox does it                                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Bridge entry point | `MoEngagePluginInboxBridge.swift` — single `@objc final public class`                                                   |
| Native calls       | Directly via `MoEngageSDKInbox.sharedInstance` — no handler protocol                                                    |
| identifier         | `Optional<String>` — always `guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)` |
| Guard failure      | `return` (no log call — unlike cards)                                                                                   |
| Constants          | `MoEngagePluginInboxConstants` — `struct` with nested `struct Inbox`                                                    |
| Utils              | `MoEngagePluginInboxUtils` — static helpers for payload building                                                        |
| Response building  | `MoEngagePluginInboxUtils` static methods build the return dict                                                         |
| Type 2 response    | Pass completion handler directly; build payload in Utils                                                                |
| Supported types    | **Type 1** (fire-and-forget) and **Type 2** (completionHandler) only                                                    |

---

## Phase 0 — Clarify Inputs

### 0.1 Extract ticket ID
Scan the user's full command for `MOEN-\d+` → **`ticketId`**.
If not found, ask before proceeding.

### 0.2 Confirm all required inputs
If either `feature_description` or `contract_pr_url` is missing, ask for them before proceeding.
`ios_native_version` is optional — do not ask for it if absent.

Derive:
- **`featureName`** — lowercase slug from `feature_description` (e.g. `getunreadcount`)
- **`prNumber`** — numeric part of `contract_pr_url` (e.g. `12`)
- **`branchName`** — `feature/<ticketId>-<featureName>` (e.g. `feature/MOEN-44072-getunreadcount`)

---

## Phase 1 — Read Contracts from PR (Hybrid ↔ InboxPlugin boundary)

### 1.1 Fetch PR file list

```bash
gh pr view <prNumber> --repo moengage/mobile-sdk-contracts --json title,body,files,headRefName
```

Extract:
- **`contractBranch`** — `headRefName`
- **`hybridToNativeFiles`** — changed files under `json/hybridToNative/`
- **`nativeToHybridFiles`** — changed files under `json/nativeToHybrid/`

### 1.2 Read contract files

For each file in `hybridToNativeFiles`:
```
https://raw.githubusercontent.com/moengage/mobile-sdk-contracts/<contractBranch>/<path>
```
- Filename (without `.json`) = **method name**
- Content = **input payload shape**

For each file in `nativeToHybridFiles`:
```
https://raw.githubusercontent.com/moengage/mobile-sdk-contracts/<contractBranch>/<path>
```
- Content = **response payload shape**

### 1.3 Classify

| File status                | Meaning                                                           |
| -------------------------- | ----------------------------------------------------------------- |
| **New file** added         | New method — full bridge implementation needed (Phase 2 required) |
| **Existing file** modified | Payload change only — update existing method, skip Phase 2        |

For new files:

| New contract files                         | Classification                                                                  |
| ------------------------------------------ | ------------------------------------------------------------------------------- |
| `hybridToNative` only                      | **Fire-and-forget** (Type 1) — no response                                      |
| both `hybridToNative` and `nativeToHybrid` | **Completion handler** (Type 2) — bridge method takes `completionHandler` param |

Print a `### Contract Summary` with method name(s), file status, payload schema, and classification.

---

## Phase 2 — Find the Native API (InboxPlugin ↔ Native boundary)

### 2a — Resolve source

**If `native_sdk_pr_url` was provided:**
```bash
gh pr view <prNumber> --repo moengage/MoEngage-iPhone-SDK --json title,body,files,headRefName
```
Read each changed `.swift` file:
```
https://raw.githubusercontent.com/moengage/MoEngage-iPhone-SDK/<nativeBranch>/<path>
```

**If `native_sdk_pr_url` was NOT provided:**
Fetch `MoEngageSDKInbox` from master:
```
https://raw.githubusercontent.com/moengage/MoEngage-iPhone-SDK/master/Sources/MoEngageInbox/Public/MoEngageSDKInbox.swift
```
If not found there, search:
```
https://api.github.com/search/code?q=<featureName>+repo:moengage/MoEngage-iPhone-SDK+language:Swift+path:Sources/MoEngageInbox
```

### 2b — Extract native signature

Extract:
- **Full method signature** (name, parameters, return type, completion closure shape)
- **Response model type** — what the completion closure receives (e.g. `[MoEngageInboxEntry]`, `Int`, `Bool`)
- **Availability guards** — `@available`, `#if os(tvOS)`
- **Parameter label** — `forAppID:`, `forAppId:`, or `withCampaignID:forAppID:`

The type is always **Type 1** or **Type 2** for inbox — no delegate/event patterns.

Determine:
- Does the input payload need more than just `identifier`? (e.g. a campaign ID)
  If yes → extract from payload using existing `MoEngagePluginInboxUtils.fetchCampaignIdFromPayload` or add a new extractor in Utils
- Does the response need a new Utils helper?
  If yes → add a `static func create<X>Payload(...)` in `MoEngagePluginInboxUtils`

Print a `### Native API Summary` with the finalized type, native signature, and notes on any new Utils helper needed.

---

## Phase 3 — Read Current InboxPlugin State

Read these files:

1. `Sources/MoEngagePluginInbox/MoEngagePluginInboxBridge.swift`
2. `Sources/MoEngagePluginInbox/MoEngagePluginInboxConstants.swift`
3. `Sources/MoEngagePluginInbox/MoEngagePluginInboxUtils.swift`
4. `package.json` — current version, `sdkVerMin`, `pluginbaseVerMin`
5. `CHANGELOG.md` — format reference

Identify:
- Current version (e.g. `4.9.0`) → new minor version (e.g. `4.10.0`)
- Whether a new constant is needed in `MoEngagePluginInboxConstants`
- Whether a new Utils helper is needed or an existing one can be reused
- Closest existing bridge method to use as template

---

## Phase 4 — Propose Implementation Plan

Output a numbered checklist under `### Implementation Plan`:

1. Branch: `<branchName>`
2. Files to change and exactly what to add/modify in each:
   - `MoEngagePluginInboxBridge.swift` — new bridge method (type 1 or 2)
   - `MoEngagePluginInboxConstants.swift` — new constant keys (or "no change")
   - `MoEngagePluginInboxUtils.swift` — new helper (or "no change")
   - `package.json` — minor version bump + optionally `sdkVerMin` + optionally `pluginbaseVerMin`
   - `CHANGELOG.md` — new entry
3. tvOS guard if native API is iOS-only

Ask: *"Does this plan look right before I implement?"* Wait for approval.

---

## Phase 5 — Implement

Once approved, implement **in this order**:

### 5a — Constants

Open `Sources/MoEngagePluginInbox/MoEngagePluginInboxConstants.swift`.
Add new key constants inside `struct Inbox` using `static let camelCaseName = "camelCaseName"`.
Do not create a new struct.

### 5b — Utils helper (if needed)

Open `MoEngagePluginInboxUtils.swift`.
Add a `static func create<X>Payload(...)` following the existing pattern:
```swift
static func create<X>Payload(<params>) -> [String: Any] {
    let accountMeta = MoEngagePluginUtils.createAccountPayload(identifier: identifier)
    let data: [String: Any] = [...]
    return [MoEngagePluginConstants.General.accountMeta: accountMeta,
            MoEngagePluginConstants.General.data: data]
}
```

### 5c — Bridge method in MoEngagePluginInboxBridge.swift

**Rules that apply to all types:**
- Always `@objc public` — hybrid SDKs reach this via ObjC runtime or direct Swift call
- First parameter is always `_ payload: [String: Any]` (or named dict param matching existing style)
- Always `guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload) else { return }`
- Call native via `MoEngageSDKInbox.sharedInstance.<method>` — never use a handler protocol
- **Always pass `identifier` to every native API call** — the parameter label varies:

  | Label                      | Used for                                                      |
  | -------------------------- | ------------------------------------------------------------- |
  | `forAppID:`                | most inbox methods                                            |
  | `withCampaignID:forAppID:` | campaign-specific methods (trackInboxClick, deleteInboxEntry) |

- Add `#if os(tvOS)` guard with a descriptive log if the native API is iOS-only
- Response payload keys must exactly match the `nativeToHybrid` contract

Read the relevant example file before generating code:

| Type                       | Example file                          |
| -------------------------- | ------------------------------------- |
| Type 1 — fire-and-forget   | `examples/Type1_FireAndForget.swift`  |
| Type 2 — completion handler | `examples/Type2_CompletionHandler.swift` |

---

### 5d + 5e — Version bump and CHANGELOG

Invoke the `version-update` skill with:
- `new_version` = next minor version (e.g. `4.9.0` → `4.10.0`)
- `changelog_entries` = `["[minor] Added support for <feature_description>"]` — **do NOT include the ticket ID**
- `native_sdk_version` = `<ios_native_version>` — **only if `ios_native_version` was provided**; omit otherwise
- `pluginbase_version` = `<pluginbase_version>` (if provided)

When `ios_native_version` is provided:
- Set `sdkVerMin` → `<ios_native_version>` in `package.json`
- Add `[<sdk_bump_type>] Updated MoEngage-iOS-SDK to <ios_native_version>` to CHANGELOG
- **Omit PluginBase line** (mutual exclusion rule)

When `ios_native_version` is **not** provided:
- `sdkVerMin` unchanged
- No SDK version line added

---

## Phase 6 — Branch, Commit, Push and PR

### 6.1 — Create branch and commit

```bash
git status
git checkout -b <branchName>
git add -A
git commit -m "<ticketId>: Added support for <feature_description>"
```

If `git checkout -b` fails because the branch already exists, stop and ask the user.

### 6.2 — Push and create PR

```bash
git push -u origin <branchName>

gh pr create \
  --repo moengage/apple-plugin-inbox \
  --base development \
  --title "<ticketId>: Added support for <feature_description>" \
  --body "$(cat <<'EOF'
### Jira Ticket
https://moengagetrial.atlassian.net/browse/<ticketId>

### Description
Added support for <feature_description>

### Contract PR
<contract_pr_url>

### Native SDK
<native_sdk_pr_url or "moengage/MoEngage-iPhone-SDK @ master">

### Changes
- `MoEngagePluginInboxBridge.swift` — <new/updated method: methodName, type: 1/2>
- `MoEngagePluginInboxConstants.swift` — <new constants or "no change">
- `MoEngagePluginInboxUtils.swift` — <new helper or "no change">
- `package.json` — version <old> → <new><, sdkVerMin <old> → <ios_native_version> if provided><, pluginbaseVerMin <old> → <pluginbase_version> if provided>
- `CHANGELOG.md` — new entry
EOF
)"
```

Print the PR URL on completion.

---

## Phase 7 — Summary

Print:

```
PR:               <pr_url>
Branch:           <branchName>
Version:          <old> → <new>
sdkVerMin:        <old> → <ios_native_version>            ← omit if ios_native_version not provided
pluginbaseVerMin: <old> → <pluginbase_version>            ← omit if pluginbase_version not provided
Ticket:           <ticketId>
Contract PR:      <contract_pr_url>

Files changed:
  - MoEngagePluginInboxBridge.swift      (<new/updated> method: <methodName>, type: <1/2>)
  - MoEngagePluginInboxConstants.swift   (new constants: <list> or "no change")
  - MoEngagePluginInboxUtils.swift       (new helper: <funcName> or "no change")
  - package.json                         (version bump<+ sdkVerMin><+ pluginbaseVerMin>)
  - CHANGELOG.md                         (new entry)

Native SDK source: <native_sdk_pr_url or "moengage/MoEngage-iPhone-SDK @ master">
```
