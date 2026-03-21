# Emax Forge — UX Audit & World-Class Roadmap

**Date:** 2026-03-02  
**Current Version:** v0.3.1  
**Goal:** Elevate from "good" to "world-class" macOS app UX

---

## 🎯 EXECUTIVE SUMMARY

**Current State:** Functional, clean, professional  
**Target:** World-class (Logic Pro / Final Cut Pro / Ableton level)  
**Gap:** Polish, discoverability, workflow optimization, edge cases

**Priority Fixes:**
1. **Critical** (Ship blockers) — 0 issues ✅
2. **High** (Next week) — 8 issues
3. **Medium** (Next sprint) — 12 issues
4. **Low** (Nice to have) — 5 issues

---

## 📊 SYSTEMATIC AUDIT

### 1️⃣ INFORMATION ARCHITECTURE

**Current State:**
✅ Clear 3-column layout (Sidebar → List → Detail)
✅ Logical grouping (volumes, images, banks)
✅ Toolbar actions well-organized

**Gaps:**
❌ No breadcrumb navigation
❌ Search not prominent
❌ Recent files not accessible
❌ No favorites/bookmarks

**World-Class Standard:**
- Finder: Breadcrumbs, favorites sidebar, smart folders
- Logic Pro: Browser with favorites, recents, smart collections

**Recommendation:**
- Add breadcrumb trail (Volume > Image > Bank)
- Add "Favorites" section in sidebar
- Add "Recent" section (last 10 volumes/images)
- Search should be Cmd+F with live filtering

---

### 2️⃣ VISUAL HIERARCHY

**Current State:**
✅ Good use of color (orange accent)
✅ Typography readable
✅ Icons clear (SF Symbols)
✅ Spacing adequate

**Gaps:**
❌ Status bar too subtle (easy to miss)
❌ Primary actions not visually dominant
❌ Empty states could be more engaging
❌ No visual feedback for long operations

**World-Class Standard:**
- Final Cut Pro: Clear primary/secondary action distinction
- Xcode: Progress indicators everywhere
- Sketch: Inline validation, instant feedback

**Recommendation:**
- Make status bar more prominent (color-coded states)
- Primary buttons: Larger, gradient, shadows
- Add progress indicators for all operations >1s
- Skeleton loading states for image list
- Success animations (subtle checkmarks)

---

### 3️⃣ USER FLOWS

**Current State:**
✅ Open folder → Browse images → Import banks (clear)
✅ Create bootable disk wizard (guided)
✅ Keyboard shortcuts extensive

**Gaps:**
❌ No undo/redo (critical!)
❌ Drag & drop not intuitive everywhere
❌ Multi-select limited
❌ Batch operations require modal
❌ No "Save" reminder for edits

**World-Class Standard:**
- All macOS apps: Cmd+Z works everywhere
- Finder: Multi-select with Cmd/Shift, drag anywhere
- Logic Pro: Non-destructive editing, version history

**Recommendation:**
- Implement undo/redo system (NSUndoManager)
- Multi-select images (Cmd+Click, Shift+Click)
- Drag images between folders
- Inline rename (click title to edit)
- Auto-save with dirty state indicator

---

### 4️⃣ DISCOVERABILITY

**Current State:**
✅ Tooltips on hover (now working!)
✅ Knowledge Base accessible
✅ WelcomeView shows getting started

**Gaps:**
❌ Hidden features not obvious (multi-image slots?)
❌ No onboarding tour for first launch
❌ No "What's New" on updates
❌ Context-sensitive help missing

**World-Class Standard:**
- Logic Pro: Tooltips show keyboard shortcuts + demos
- Figma: In-app tutorials, contextual tips
- Things: First-run tour with highlights

**Recommendation:**
- First-launch tour (5 steps, skippable)
- Tooltips with GIFs/animations
- "What's New" sheet on updates
- Help button in toolbars → contextual docs
- Keyboard shortcut cheatsheet (Cmd+/)

---

### 5️⃣ FEEDBACK & STATUS

**Current State:**
✅ Status bar shows messages
✅ Activity feed exists
✅ Eject shows confirmation

**Gaps:**
❌ No progress for long operations (import 100 banks)
❌ Destructive actions lack confirmation dialogs
❌ Success/error states too subtle
❌ No "operation complete" sound

**World-Class Standard:**
- macOS: Progress bars, determinate when possible
- Xcode: Notifications for background tasks
- Mail: Undo toast after delete

**Recommendation:**
- Progress bars for all operations >2s
- Confirmation dialogs for:
  - Delete image
  - Overwrite file
  - Format/create bootable disk
- Toast notifications (bottom-right)
- Undo toast (3s timeout, clickable)
- System sounds (subtle) for success/error

---

### 6️⃣ ERROR PREVENTION & RECOVERY

**Current State:**
✅ File validation before operations
✅ Trash instead of delete
✅ Backup/restore wizard

**Gaps:**
❌ No duplicate name prevention
❌ No "unsaved changes" warning
❌ Crash recovery not implemented
❌ No file version history

**World-Class Standard:**
- macOS: Auto-save, versions, resume
- Logic Pro: Automatic backups, project alternatives
- Sketch: Cloud sync, version history

**Recommendation:**
- Duplicate name → Auto-append " 2"
- Dirty state tracking → Alert on quit
- Auto-save every 30s (to temp location)
- Crash recovery (reopen last session)
- Version browser (Time Machine style)

---

### 7️⃣ AESTHETICS & POLISH

**Current State:**
✅ Dark mode theme
✅ Consistent colors
✅ SF Symbols icons
✅ Clean typography

**Gaps:**
❌ Animations missing (list updates, transitions)
❌ No hover states on list items
❌ No selection highlight in sidebar
❌ Window resize not smooth
❌ No custom app icon

**World-Class Standard:**
- macOS: Smooth animations (120fps)
- Things: Delightful micro-interactions
- Airmail: Beautiful custom icons

**Recommendation:**
- List item animations (insert/delete)
- Hover states everywhere
- Smooth transitions (0.2s ease-out)
- Custom app icon (professional, recognizable)
- Launch screen (avoid white flash)
- Window resize: Maintain proportions

---

### 8️⃣ PERFORMANCE PERCEPTION

**Current State:**
✅ Fast on small datasets
✅ No lag on UI interactions

**Gaps:**
❌ Large image lists (100+) slow to load
❌ No lazy loading
❌ No caching strategy
❌ Hex preview loads synchronously

**World-Class Standard:**
- Photos: Virtual scrolling, thumbnails
- Xcode: Lazy indexing, background tasks
- Finder: Instant display, load in background

**Recommendation:**
- Virtual scrolling (LazyVStack)
- Image thumbnails (cached)
- Background loading with spinners
- Optimize hex preview (load on-demand)
- Debounce search (300ms)

---

### 9️⃣ ACCESSIBILITY

**Current State:**
⚠️ Not explicitly tested
⚠️ No VoiceOver optimization
⚠️ No reduced motion support

**Gaps:**
❌ VoiceOver labels missing
❌ Keyboard navigation incomplete
❌ No high contrast mode
❌ Font size not adjustable

**World-Class Standard:**
- All Apple apps: Full VoiceOver support
- Xcode: Tab navigation, focus indicators
- macOS Settings: Accessibility preferences

**Recommendation:**
- Add accessibility labels
- Full keyboard navigation
- Focus indicators visible
- Test with VoiceOver
- Support reduced motion (disable animations)
- Dynamic Type support

---

### 🔟 CONSISTENCY

**Current State:**
✅ Follows macOS HIG generally
✅ SF Symbols used correctly
✅ Keyboard shortcuts logical

**Gaps:**
❌ Some buttons use .bordered, some don't
❌ Modal sizing inconsistent
❌ Padding varies (10, 12, 14, 16)
❌ No design system documented

**World-Class Standard:**
- Apple apps: Strict adherence to HIG
- Figma: Design tokens, component library
- Sketch: Style guide, shared styles

**Recommendation:**
- Define design system:
  - Spacing: 4, 8, 12, 16, 24, 32
  - Border radius: 8, 12, 16
  - Button styles: primary, secondary, tertiary
- Document in DESIGN.md
- Refactor views to use Theme constants
- SwiftUI ViewModifiers for consistency

---

## 🎯 PRIORITIZED RECOMMENDATIONS

### 🔴 HIGH PRIORITY (Ship Next Week)

1. **Undo/Redo System** (8h)
   - NSUndoManager integration
   - Support: delete, rename, import, create
   - Cmd+Z, Cmd+Shift+Z

2. **Progress Indicators** (4h)
   - Import banks progress bar
   - Image creation spinner
   - Background task notifications

3. **Confirmation Dialogs** (2h)
   - Delete image
   - Overwrite existing file
   - Format bootable disk

4. **Multi-Select Images** (4h)
   - Cmd+Click, Shift+Click
   - Batch operations (delete, duplicate)
   - Visual selection state

5. **Custom App Icon** (3h)
   - Professional design
   - 1024x1024 source
   - All sizes (@1x, @2x, @3x)

6. **Breadcrumb Navigation** (3h)
   - Volume > Image > Bank
   - Clickable segments
   - Truncate long names

7. **Search Prominence** (2h)
   - Cmd+F opens search
   - Live filtering
   - Clear button

8. **Status Bar Polish** (2h)
   - Color-coded states (green=success, red=error)
   - Larger font
   - Icons for state types

**Total: ~28 hours (1 week full-time)**

---

### 🟡 MEDIUM PRIORITY (Next Sprint)

9. Toast Notifications (3h)
10. Undo Toast (2h)
11. Favorites Section (4h)
12. Recent Files (3h)
13. First-Launch Tour (6h)
14. List Item Animations (4h)
15. Hover States (2h)
16. Dirty State Tracking (3h)
17. Auto-Save (4h)
18. Lazy Loading (5h)
19. Keyboard Shortcut Cheatsheet (3h)
20. Custom Launch Screen (2h)

**Total: ~41 hours (1.5 weeks)**

---

### 🟢 LOW PRIORITY (Future)

21. Version History (8h)
22. Crash Recovery (6h)
23. VoiceOver Support (8h)
24. Design System Documentation (4h)
25. What's New Sheet (3h)

**Total: ~29 hours**

---

## 📐 DESIGN SYSTEM (Proposed)

### Colors
```swift
enum Theme {
    // Primary
    static let accent = Color.orange
    static let accentGradient = LinearGradient(...)
    
    // Status
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    static let info = Color.blue
    
    // Backgrounds
    static let bgDeep = Color(hex: "0A0A0A")
    static let bgCard = Color(hex: "1C1C1E")
    static let bgHover = Color(hex: "2C2C2E")
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.gray
    static let textTertiary = Color(white: 0.5)
}
```

### Spacing
```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
```

### Typography
```swift
enum Typography {
    static let title = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
}
```

### Components
- PrimaryButton (gradient, shadow, hover)
- SecondaryButton (bordered, no fill)
- TertiaryButton (plain, subtle)
- Card (background, padding, radius)
- Toast (bottom-right, auto-dismiss)
- ProgressBar (determinate/indeterminate)

---

## 🏆 BENCHMARKING

### Apps to Study

**Music/Audio:**
- Logic Pro X (workflow, browser, inspector)
- Ableton Live (session view, device chains)
- Pro Tools (track management, routing)

**Design/Creative:**
- Final Cut Pro (magnetic timeline, media browser)
- Sketch (layers, inspector, plugins)
- Figma (components, auto-layout, collaboration)

**Productivity:**
- Things 3 (task management, projects, areas)
- Bear (notes, tags, organization)
- Craft (documents, blocks, templates)

**System:**
- Finder (sidebar, columns, quick look)
- Photos (albums, smart albums, editing)
- Mail (threading, search, rules)

### Key Takeaways

**Logic Pro:**
- Browser: Favorites, recents, search
- Inspector: Context-sensitive parameters
- Transport: Always visible, status clear
- Undo: Unlimited, named actions

**Final Cut Pro:**
- Magnetic timeline: Non-destructive
- Browser: Metadata-rich, fast search
- Inspector: Grouped parameters
- Background tasks: Visible, cancellable

**Things 3:**
- Animations: Delightful, not distracting
- Keyboard: Everything accessible
- Gestures: Swipe to complete
- Empty states: Encouraging, actionable

**Sketch:**
- Inspector: Auto-layout, smart suggestions
- Components: Reusable, nested
- Plugins: Extensible architecture
- Performance: Instant, smooth

---

## 🎨 VISUAL MOCKUPS (Proposed)

### 1. Enhanced Status Bar
```
┌──────────────────────────────────────────────────────────┐
│ [🟢] Ready  •  3 images  •  1.2 GB / 2 GB used          │
└──────────────────────────────────────────────────────────┘
   ↑         ↑               ↑
 Color    Message        Space usage (progress bar)
```

### 2. Toast Notification
```
                                    ┌─────────────────────┐
                                    │ ✅ Image duplicated │
                                    │    Undo (3s)        │
                                    └─────────────────────┘
                                           ↑
                                    Bottom-right corner
                                    Auto-dismiss 3s
```

### 3. Breadcrumb Navigation
```
┌─────────────────────────────────────────────────┐
│ 🗂️ SD Card > HD1.hda > Bank 01                │
│    ↑         ↑          ↑                       │
│  Volume    Image      Bank (clickable)         │
└─────────────────────────────────────────────────┘
```

### 4. Multi-Select State
```
┌──────────────────────────────────────────────────┐
│ [✓] HD0.hda        2 MB   SCSI 0  [Bootable]    │  ← Selected
│ [✓] HD1.hda       10 MB   SCSI 1                │  ← Selected
│ [ ] HD2.hda        5 MB   SCSI 2                │
└──────────────────────────────────────────────────┘
      ↑
   Checkboxes
   
   Toolbar shows: "2 images selected" + batch actions
```

---

## 📋 IMPLEMENTATION PLAN

### Phase 1: Critical Polish (Week 1)
**Goal:** Ship-ready quality

- [ ] Undo/Redo system
- [ ] Progress indicators
- [ ] Confirmation dialogs
- [ ] Multi-select
- [ ] Custom app icon
- [ ] Breadcrumb nav
- [ ] Search (Cmd+F)
- [ ] Status bar polish

**Deliverable:** v0.4 Beta

---

### Phase 2: Workflow Enhancement (Week 2-3)
**Goal:** Professional-grade UX

- [ ] Toast notifications
- [ ] Undo toast
- [ ] Favorites section
- [ ] Recent files
- [ ] First-launch tour
- [ ] List animations
- [ ] Hover states
- [ ] Dirty state tracking
- [ ] Auto-save
- [ ] Lazy loading
- [ ] Keyboard cheatsheet
- [ ] Launch screen

**Deliverable:** v0.5 RC

---

### Phase 3: Future Enhancements (Ongoing)
**Goal:** World-class refinement

- [ ] Version history
- [ ] Crash recovery
- [ ] VoiceOver support
- [ ] Design system docs
- [ ] What's New sheet
- [ ] Plugin system
- [ ] Cloud sync
- [ ] Collaboration features

**Deliverable:** v1.0 Gold Master

---

## 🎓 LESSONS FROM WORLD-CLASS APPS

### 1. Performance is UX
- Instant feedback (perceived < 100ms)
- Background operations (don't block UI)
- Optimistic updates (show change immediately)
- Skeleton loading (show structure while loading)

### 2. Discoverability
- Tooltips everywhere (with shortcuts)
- Empty states that teach
- Progressive disclosure (advanced features hidden initially)
- Contextual help (where you need it)

### 3. Error Resilience
- Undo everything
- Confirmation for destructive actions
- Auto-save by default
- Graceful degradation (work offline)

### 4. Consistency
- Design system (colors, spacing, typography)
- Component library (reusable)
- Keyboard shortcuts (logical patterns)
- Interaction patterns (same gesture = same action)

### 5. Delight
- Micro-interactions (button press, list insert)
- Smooth animations (ease-out, 0.2s)
- Sound design (subtle, satisfying)
- Easter eggs (hidden features)

---

## 📊 METRICS TO TRACK

**User Success:**
- Time to first action (target: <30s)
- Task completion rate (target: >95%)
- Error rate (target: <5%)
- Undo usage (indicates mistakes)

**Performance:**
- App launch time (target: <2s)
- Image load time (target: <500ms)
- UI responsiveness (target: 60fps)
- Memory footprint (target: <200MB)

**Engagement:**
- Daily active users
- Features discovered (from analytics)
- Keyboard shortcut usage
- Help article views

---

## ✅ NEXT STEPS

**Immediate (This Week):**
1. Review this audit with stakeholders
2. Prioritize HIGH items
3. Create GitHub issues for each item
4. Assign to sprint

**Short-term (Next 2 Weeks):**
1. Implement Phase 1 (Critical Polish)
2. User testing with beta testers
3. Iterate based on feedback
4. Ship v0.4 Beta

**Long-term (Next Month):**
1. Phase 2 (Workflow Enhancement)
2. Beta feedback cycle
3. Ship v0.5 RC
4. Plan v1.0 features

---

**Status:** READY FOR REVIEW  
**Next:** Stakeholder meeting → Prioritization → Implementation

