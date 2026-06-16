# Pyxis UX And Performance Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Pyxis perceived speed, everyday usability, and UI clarity without changing the local-first product scope.

**Architecture:** Keep the current SwiftUI + SwiftData app shape. Move expensive image and derived collection work out of render paths, then tighten interaction affordances around filtering, importing, outfit building, and saved fits. Prefer small view-model or helper additions over broad rewrites.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, UIKit image loading, XCTest, XcodeBuildMCP simulator build tooling.

---

## Audit Context

This audit was performed on June 16, 2026 from the current workspace. Re-check `git status --short --branch` before implementation because this plan may be executed from a feature branch or worktree.

Evidence collected:

- `swift test` passes with 57 XCTest cases.
- XcodeBuildMCP compile-only iOS simulator build passes for `Pyxis.xcodeproj`, scheme `Pyxis`, target `iPhone 17`, with no warnings.
- No simulator was booted or launched during the original audit because all available simulators were shutdown and the user asked not to interrupt another chat/process.
- At review time after plan cleanup, the only known untracked workspace content is `docs/superpowers/plans/`; do not rely on earlier notes about prototype carousel or mockup files.

High-impact findings:

1. `LocalImageView` synchronously decodes file-backed images in `body` (`Pyxis/Views/Shared/LocalImageView.swift:8-13`). This can hitch the closet grid, outfit carousel, saved-fit strip, and detail screens.
2. Closet filtering and sorting are recomputed inside the grid view builder (`Pyxis/Views/ClosetGrid/ClosetGridView.swift:93-96`) and the filtering service lowercases/searches every matching item on each pass (`Pyxis/Services/ClosetFilteringService.swift:40-65`).
3. Navigation and filters rely on horizontally hidden text rows with limited feedback (`Pyxis/Views/Navigation/TopNavigationView.swift:21-63`), and only seven colors are exposed even though the model supports more.
4. Image import has quiet failure paths and can attempt both URL and image-provider handling for one drop (`Pyxis/Views/AddItem/ImageImportView.swift:42-101`).
5. Saved fits are discoverable but thin: cards have generic accessibility labels (`Pyxis/Views/OutfitBuilder/SavedFitsStrip.swift:102-104`), the gallery empty state has no next action, and outfit detail has no delete action.
6. The outfit builder recalculates rows/draft from full `items` in computed properties (`Pyxis/Views/OutfitBuilder/OutfitBuilderView.swift:26-35`) and repeats service calls from `body`.
7. Fixed tiny monospaced typography creates a premium look, but it risks Dynamic Type/accessibility readability across forms and compact screens (`Pyxis/DesignSystem/PyxisTypography.swift`).

## File Structure

Create:

- `Pyxis/Views/Shared/AsyncLocalImageView.swift` - asynchronous, downsampled image renderer and loader state for local file URLs.
- `Pyxis/Utilities/LocalImageCache.swift` - in-memory image cache for display-sized local images shared by grid, carousel, detail, and saved-fit thumbnails.
- `Pyxis/ViewModels/OutfitBuilderViewModel.swift` - derived builder rows, selections, and draft state.
- `Tests/PyxisTests/OutfitBuilderViewModelTests.swift` - pure tests for builder derived state where possible.
- `Tests/PyxisTests/ClosetGridViewModelTests.swift` - tests for derived visible-items update behavior.

Modify:

- `Pyxis/Views/Shared/LocalImageView.swift` - replace synchronous decode implementation or turn into a compatibility wrapper around `AsyncLocalImageView`.
- `Pyxis/Views/ClosetGrid/ClosetGridView.swift` - consume view-model visible items, add clear filter affordance, avoid filtering in `body`.
- `Pyxis/ViewModels/ClosetGridViewModel.swift` - own visible-items derivation and active-filter summary.
- `Pyxis/Services/ClosetFilteringService.swift` - add reusable active-filter helpers and optional searchable-text helper.
- `Pyxis/Views/Navigation/TopNavigationView.swift` - clarify active filter state and expose all colors through a compact picker/menu.
- `Pyxis/Views/Search/SearchAndFilterView.swift` - add active filter count/clear action and better compact layout.
- `Pyxis/Views/AddItem/ImageImportView.swift` - add loading/error state and single-path drop handling.
- `Pyxis/Views/AddItem/MetadataEditorView.swift` - add labels/hints for auto-filled metadata and improve form grouping.
- `Pyxis/Views/OutfitBuilder/OutfitBuilderView.swift` - delegate derived state to `OutfitBuilderViewModel`.
- `Pyxis/Views/OutfitBuilder/SavedFitsStrip.swift` - improve saved-fit labels and accessibility.
- `Pyxis/Views/OutfitBuilder/SavedFitsGalleryView.swift` - add empty-state action to start building.
- `Pyxis/Views/OutfitBuilder/OutfitDetailView.swift` - add delete action with confirmation.
- `Pyxis/Views/ItemDetail/ItemDetailView.swift` - add destructive confirmation and clearer background-removal status.
- `Pyxis/DesignSystem/PyxisTypography.swift` - introduce scalable variants while preserving the current brand feel.
- `docs/MANUAL_QA.md` - add checks for performance polish, import errors, saved-fit management, and accessibility.

Do not modify unrelated untracked files. If new untracked files appear before implementation, inspect them and confirm ownership before staging or editing them.

---

### Task 1: Move Local Image Decode Out Of SwiftUI Body

**Files:**

- Create: `Pyxis/Utilities/LocalImageCache.swift`
- Create: `Pyxis/Views/Shared/AsyncLocalImageView.swift`
- Modify: `Pyxis/Views/Shared/LocalImageView.swift:4-26`
- Verify affected callers:
  - `Pyxis/Views/ClosetGrid/ClosetGridItemView.swift`
  - `Pyxis/Views/OutfitBuilder/OutfitCarouselItemView.swift`
  - `Pyxis/Views/OutfitBuilder/SavedFitsStrip.swift`
  - `Pyxis/Views/ItemDetail/ItemDetailView.swift`
  - `Pyxis/Views/AddItem/AddItemFlow.swift`

- [ ] **Step 1: Add an in-memory image cache**

Create `Pyxis/Utilities/LocalImageCache.swift`. Cache keys include the display pixel target so thumbnails, carousel cells, and detail previews do not accidentally reuse the wrong resolution:

```swift
import UIKit

@MainActor
final class LocalImageCache {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private var keysByURL: [String: Set<String>] = [:]

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        cache.object(forKey: key(for: url, maxPixelSize: maxPixelSize) as NSString)
    }

    func store(_ image: UIImage, for url: URL, maxPixelSize: CGFloat) {
        let cacheKey = key(for: url, maxPixelSize: maxPixelSize)
        let pixelCount = Int(image.size.width * image.scale * image.size.height * image.scale)
        cache.setObject(image, forKey: cacheKey as NSString, cost: pixelCount * 4)
        keysByURL[url.path, default: []].insert(cacheKey)
    }

    func removeImage(for url: URL) {
        for key in keysByURL[url.path, default: []] {
            cache.removeObject(forKey: key as NSString)
        }
        keysByURL[url.path] = nil
    }

    private func key(for url: URL, maxPixelSize: CGFloat) -> String {
        "\(url.path)#\(Int(maxPixelSize.rounded()))"
    }
}
```

- [ ] **Step 2: Add async local image rendering**

Create `Pyxis/Views/Shared/AsyncLocalImageView.swift`:

```swift
import ImageIO
import SwiftUI
import UIKit

struct AsyncLocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var maxPixelSize: CGFloat = 640

    @State private var loadedURL: URL?
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .overlay {
                        Text(isLoading ? "LOADING" : "NO IMAGE")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.inactiveText)
                    }
            }
        }
        .accessibilityLabel("Clothing image")
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url else {
            loadedURL = nil
            image = nil
            isLoading = false
            return
        }

        if loadedURL == url, image != nil {
            return
        }

        if let cached = LocalImageCache.shared.image(for: url, maxPixelSize: maxPixelSize) {
            loadedURL = url
            image = cached
            isLoading = false
            return
        }

        loadedURL = url
        image = nil
        isLoading = true

        let targetPixelSize = maxPixelSize
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.downsampledImage(at: url, maxPixelSize: targetPixelSize)
        }.value

        guard loadedURL == url else {
            return
        }

        if let decoded {
            LocalImageCache.shared.store(decoded, for: url, maxPixelSize: maxPixelSize)
        }
        image = decoded
        isLoading = false
    }

    private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return UIImage(contentsOfFile: url.path)?.preparingForDisplay()
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded()))
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(contentsOfFile: url.path)?.preparingForDisplay()
        }

        return UIImage(cgImage: image)
    }
}
```

- [ ] **Step 3: Convert `LocalImageView` to a wrapper**

Replace `Pyxis/Views/Shared/LocalImageView.swift` with:

```swift
import SwiftUI

struct LocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var maxPixelSize: CGFloat = 640

    var body: some View {
        AsyncLocalImageView(url: url, contentMode: contentMode, maxPixelSize: maxPixelSize)
    }
}
```

- [ ] **Step 4: Verify app target compiles**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds with no new warnings.

- [ ] **Step 5: Manual performance check**

Run the app on a simulator only after confirming no other chat owns the simulator. Seed or import at least 30 items. Scroll the closet grid, open `BUILD`, swipe every carousel row, open a detail view, and open saved fits. Expected: no obvious first-scroll or first-swipe hitch from image decoding; first image loads may show `LOADING` briefly.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/Utilities/LocalImageCache.swift Pyxis/Views/Shared/AsyncLocalImageView.swift Pyxis/Views/Shared/LocalImageView.swift
git commit -m "perf: load local clothing images asynchronously"
```

### Task 2: Move Closet Visible-Item Derivation Out Of `body`

**Files:**

- Modify: `Pyxis/ViewModels/ClosetGridViewModel.swift:1-25`
- Modify: `Pyxis/Views/ClosetGrid/ClosetGridView.swift:93-136`
- Modify: `Pyxis/Services/ClosetFilteringService.swift:12-117`
- Create: `Tests/PyxisTests/ClosetGridViewModelTests.swift`

- [ ] **Step 1: Add filter-state convenience**

Append to `ClosetFilterState` in `Pyxis/Services/ClosetFilteringService.swift`:

```swift
public var hasActiveFilters: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || category != nil
        || subtype != nil
        || color != nil
        || favoritesOnly
        || sort != .newest
}

public var activeFilterCount: Int {
    var count = 0
    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
    if category != nil { count += 1 }
    if subtype != nil { count += 1 }
    if color != nil { count += 1 }
    if favoritesOnly { count += 1 }
    if sort != .newest { count += 1 }
    return count
}

public mutating func reset() {
    self = ClosetFilterState()
}
```

- [ ] **Step 2: Write view-model tests**

Create `Tests/PyxisTests/ClosetGridViewModelTests.swift`:

```swift
import XCTest
@testable import PyxisCore

@MainActor
final class ClosetGridViewModelTests: XCTestCase {
    func testUpdateVisibleItemsAppliesFilterAndSort() {
        let blackTop = ClosetItem(
            itemCode: "TS-002",
            displayName: "Black Tee",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .black,
            dateAdded: Date(timeIntervalSince1970: 10),
            imageOriginalPath: "Images/Originals/top.png"
        )
        let whiteShoe = ClosetItem(
            itemCode: "SH-001",
            displayName: "White Sneaker",
            category: .footwear,
            subtype: .sneakers,
            primaryColor: .white,
            dateAdded: Date(timeIntervalSince1970: 20),
            imageOriginalPath: "Images/Originals/shoe.png"
        )

        let viewModel = ClosetGridViewModel()
        viewModel.filterState.category = .tops
        viewModel.updateVisibleItems(from: [whiteShoe, blackTop])

        XCTAssertEqual(viewModel.visibleItems.map(\.itemCode), ["TS-002"])
        XCTAssertTrue(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.activeFilterCount, 1)
    }

    func testClearFiltersRestoresNewestSort() {
        let oldItem = ClosetItem(
            itemCode: "TS-001",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .black,
            dateAdded: Date(timeIntervalSince1970: 1),
            imageOriginalPath: "Images/Originals/old.png"
        )
        let newItem = ClosetItem(
            itemCode: "PT-001",
            category: .bottoms,
            subtype: .pants,
            primaryColor: .blue,
            dateAdded: Date(timeIntervalSince1970: 2),
            imageOriginalPath: "Images/Originals/new.png"
        )

        let viewModel = ClosetGridViewModel()
        viewModel.filterState.searchText = "missing"
        viewModel.updateVisibleItems(from: [oldItem, newItem])
        XCTAssertTrue(viewModel.visibleItems.isEmpty)

        viewModel.clearFilters()
        viewModel.updateVisibleItems(from: [oldItem, newItem])

        XCTAssertEqual(viewModel.visibleItems.map(\.itemCode), ["PT-001", "TS-001"])
        XCTAssertFalse(viewModel.hasActiveFilters)
    }

    func testItemFingerprintChangesWhenFilterRelevantMetadataChanges() {
        let item = ClosetItem(
            itemCode: "TS-001",
            displayName: "Black Tee",
            category: .tops,
            subtype: .tShirt,
            primaryColor: .black,
            dateAdded: Date(timeIntervalSince1970: 1),
            imageOriginalPath: "Images/Originals/top.png"
        )
        let viewModel = ClosetGridViewModel()
        let originalFingerprint = viewModel.itemFingerprint(for: [item])

        item.displayName = "Washed Black Tee"
        item.favorite = true
        item.wearCount = 3

        XCTAssertNotEqual(viewModel.itemFingerprint(for: [item]), originalFingerprint)
    }
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --filter ClosetGridViewModelTests
```

Expected: fail because `visibleItems`, `updateVisibleItems(from:)`, `itemFingerprint(for:)`, `clearFilters()`, `hasActiveFilters`, and `activeFilterCount` are not implemented.

- [ ] **Step 4: Update `ClosetGridViewModel`**

Replace `Pyxis/ViewModels/ClosetGridViewModel.swift` with:

```swift
import Foundation

@MainActor
final class ClosetGridViewModel: ObservableObject {
    @Published var filterState = ClosetFilterState()
    @Published private(set) var visibleItems: [ClosetItem] = []

    private let filteringService: ClosetFilteringService

    init(filteringService: ClosetFilteringService = ClosetFilteringService()) {
        self.filteringService = filteringService
    }

    var hasActiveFilters: Bool {
        filterState.hasActiveFilters
    }

    var activeFilterCount: Int {
        filterState.activeFilterCount
    }

    func updateVisibleItems(from items: [ClosetItem]) {
        visibleItems = filteringService.filteredItems(items, state: filterState)
    }

    func itemFingerprint(for items: [ClosetItem]) -> [ClosetGridItemFingerprint] {
        items.map(ClosetGridItemFingerprint.init(item:))
    }

    func clearFilters() {
        filterState.reset()
    }

    func selectCategory(_ category: ClothingCategory?) {
        filterState.category = category
    }

    func selectColor(_ color: ClosetColor?) {
        filterState.color = color
    }
}

struct ClosetGridItemFingerprint: Equatable {
    let id: UUID
    let itemCode: String
    let displayName: String?
    let brand: String?
    let notes: String?
    let tags: [String]
    let category: ClothingCategory
    let subtype: ClothingSubtype
    let color: ClosetColor
    let favorite: Bool
    let wearCount: Int
    let dateAdded: Date

    init(item: ClosetItem) {
        self.id = item.id
        self.itemCode = item.itemCode
        self.displayName = item.displayName
        self.brand = item.brand
        self.notes = item.notes
        self.tags = item.tags
        self.category = item.category
        self.subtype = item.subtype
        self.color = item.primaryColor
        self.favorite = item.favorite
        self.wearCount = item.wearCount
        self.dateAdded = item.dateAdded
    }
}
```

- [ ] **Step 5: Use derived visible items from the grid**

In `Pyxis/Views/ClosetGrid/ClosetGridView.swift`, remove:

```swift
let filteredItems = viewModel.filteredItems(from: items)
```

Use `viewModel.visibleItems` in the empty and grid branches:

```swift
} else if viewModel.visibleItems.isEmpty {
    Spacer()
    VStack(spacing: PyxisSpacing.sm) {
        Text("NO MATCHES")
            .font(PyxisTypography.body)
            .foregroundStyle(PyxisColors.inactiveText)

        if viewModel.hasActiveFilters {
            Button("CLEAR FILTERS") {
                viewModel.clearFilters()
                viewModel.updateVisibleItems(from: items)
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }
    Spacer()
} else {
    ScrollView {
        LazyVGrid(columns: columns, spacing: PyxisSpacing.xl) {
            ForEach(viewModel.visibleItems) { item in
                ClosetGridItemView(item: item) {
                    selectedItem = item
                }
            }
        }
        .padding(.top, PyxisSpacing.md)
    }
}
```

Add these modifiers to the root view chain after `.background(PyxisColors.background)`:

```swift
.onAppear {
    viewModel.updateVisibleItems(from: items)
}
.onChange(of: viewModel.itemFingerprint(for: items)) { _, _ in
    viewModel.updateVisibleItems(from: items)
}
.onChange(of: viewModel.filterState) { _, _ in
    viewModel.updateVisibleItems(from: items)
}
```

- [ ] **Step 6: Run focused and full tests**

Run:

```bash
swift test --filter ClosetGridViewModelTests
swift test
```

Expected: both pass.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/ViewModels/ClosetGridViewModel.swift Pyxis/Views/ClosetGrid/ClosetGridView.swift Pyxis/Services/ClosetFilteringService.swift Tests/PyxisTests/ClosetGridViewModelTests.swift
git commit -m "perf: derive closet grid results outside body"
```

### Task 3: Make Navigation And Filters More Obvious

**Files:**

- Modify: `Pyxis/Views/Navigation/TopNavigationView.swift:21-83`
- Modify: `Pyxis/Views/Search/SearchAndFilterView.swift:7-90`
- Modify: `Pyxis/Views/ClosetGrid/ClosetGridView.swift:21-65`
- Verify: `Tests/PyxisTests/FilteringTests.swift`

- [ ] **Step 1: Add a clear action to `SearchAndFilterView`**

Change the initializer inputs:

```swift
struct SearchAndFilterView: View {
    @Binding var filterState: ClosetFilterState
    let isSearchFocused: FocusState<Bool>.Binding
    let activeFilterCount: Int
    let clearAction: () -> Void
```

In `body`, add a compact status row below the controls:

```swift
VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
    ViewThatFits(in: .horizontal) {
        HStack(spacing: PyxisSpacing.md) {
            searchField
            sortPicker
            favoritesToggle
        }
        .fixedSize(horizontal: true, vertical: false)

        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            HStack(spacing: PyxisSpacing.md) {
                searchField
                sortPicker
            }

            favoritesToggle
        }
    }

    if activeFilterCount > 0 {
        HStack(spacing: PyxisSpacing.sm) {
            Text("\(activeFilterCount) FILTER\(activeFilterCount == 1 ? "" : "S") ACTIVE")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)

            Button("CLEAR") {
                clearAction()
            }
            .buttonStyle(.plain)
            .font(PyxisTypography.label)
            .foregroundStyle(PyxisColors.text)
            .accessibilityLabel("Clear closet filters")
        }
    }
}
.foregroundStyle(PyxisColors.text)
```

- [ ] **Step 2: Wire clear action from the grid**

Update `SearchAndFilterView` call in `ClosetGridView`:

```swift
SearchAndFilterView(
    filterState: $viewModel.filterState,
    isSearchFocused: $isSearchFocused,
    activeFilterCount: viewModel.activeFilterCount,
    clearAction: {
        viewModel.clearFilters()
        viewModel.updateVisibleItems(from: items)
    }
)
```

- [ ] **Step 3: Expose all colors without growing the nav row**

In `TopNavigationView`, replace the hard-coded seven-color `ForEach` with a compact picker plus common swatches:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: PyxisSpacing.md) {
        colorButton(nil, title: "All Colors")
        ForEach([ClosetColor.black, .white, .gray, .brown, .blue, .green, .red], id: \.self) { color in
            colorButton(color, title: color.rawValue)
        }

        Menu("MORE") {
            ForEach(ClosetColor.allCases, id: \.self) { color in
                Button(color.rawValue.uppercased()) {
                    filterState.color = color
                }
            }
        }
        .font(PyxisTypography.nav)
        .foregroundStyle(PyxisColors.secondaryText)
        .accessibilityLabel("More colors")
    }
    .padding(.horizontal, PyxisSpacing.xs)
}
```

- [ ] **Step 4: Improve accessibility values for category and color buttons**

Add to `categoryButton`:

```swift
.accessibilityLabel(title == "All" ? "Show all categories" : "Filter category \(title)")
.accessibilityValue(filterState.category == category ? "Selected" : "Not selected")
```

Add to `colorButton`:

```swift
.accessibilityLabel(color == nil ? "Show all colors" : "Filter color \(title)")
.accessibilityValue(filterState.color == color ? "Selected" : "Not selected")
```

- [ ] **Step 5: Build and manually inspect**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Manual checks:

- Category and color active states are visible.
- `CLEAR` appears only when filters/search/sort/favorites are active.
- `MORE` color menu includes `cream`, `tan`, `navy`, `olive`, `burgundy`, `pink`, `purple`, `yellow`, `orange`, `multicolor`, and `unknown`.
- Search and filter controls do not overlap on iPhone-sized widths.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/Views/Navigation/TopNavigationView.swift Pyxis/Views/Search/SearchAndFilterView.swift Pyxis/Views/ClosetGrid/ClosetGridView.swift
git commit -m "feat: clarify closet filters"
```

### Task 4: Make Image Import Feel Safer And More Informative

**Files:**

- Modify: `Pyxis/Views/AddItem/ImageImportView.swift:6-143`
- Modify: `Pyxis/Views/AddItem/MetadataEditorView.swift:6-36`

`AddItemFlow` already exposes processing, retry, save, and fallback status through `viewModel.stage`; leave it unchanged in this task unless implementation discovers a concrete compile or UX regression from the import-state changes.

- [ ] **Step 1: Add import status state**

Inside `ImageImportView`, add:

```swift
private enum ImportStatus: Equatable {
    case idle
    case loading
    case failed(String)
}

@State private var status: ImportStatus = .idle
```

- [ ] **Step 2: Show status below import actions**

After `Text("DROP IMAGE")`, add:

```swift
switch status {
case .idle:
    EmptyView()
case .loading:
    Text("IMPORTING")
        .font(PyxisTypography.label)
        .foregroundStyle(PyxisColors.secondaryText)
case .failed(let message):
    Text(message.uppercased())
        .font(PyxisTypography.label)
        .foregroundStyle(PyxisColors.error)
        .multilineTextAlignment(.center)
}
```

- [ ] **Step 3: Make PhotosPicker loading explicit**

Replace the `.task(id: selectedPhoto)` body with:

```swift
.task(id: selectedPhoto) {
    guard let selectedPhoto else {
        return
    }

    status = .loading
    do {
        guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
            status = .failed("Could not load photo")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-photo-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        status = .idle
        onSelect(url)
    } catch {
        status = .failed("Photo import failed")
    }
}
```

- [ ] **Step 4: Prevent double handling for one drop**

Replace `loadFirstURL(from:)` with:

```swift
private func loadFirstURL(from providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else {
        status = .failed("No image found")
        return false
    }

    status = .loading

    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                resolvedURL = item as? URL
            }

            DispatchQueue.main.async {
                guard let resolvedURL else {
                    status = .failed("Dropped file could not be read")
                    return
                }
                status = .idle
                onSelect(resolvedURL)
            }
        }
        return true
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
            guard let url else {
                DispatchQueue.main.async {
                    status = .failed("Dropped image could not be read")
                }
                return
            }

            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Pyxis-drop-\(UUID().uuidString)")
                .appendingPathExtension(url.pathExtension.isEmpty ? "png" : url.pathExtension)

            do {
                try FileManager.default.copyItem(at: url, to: temporaryURL)
                DispatchQueue.main.async {
                    status = .idle
                    onSelect(temporaryURL)
                }
            } catch {
                DispatchQueue.main.async {
                    status = .failed("Dropped image could not be copied")
                }
            }
        }
        return true
    }

    status = .failed("Drop a photo or image file")
    return false
}
```

- [ ] **Step 5: Add metadata confidence hints**

In `MetadataEditorView`, after the color picker, add:

```swift
if viewModel.classificationConfidence > 0 || viewModel.colorConfidence > 0 {
    Text("AUTO FILLED FROM IMAGE")
        .font(PyxisTypography.label)
        .foregroundStyle(PyxisColors.secondaryText)
        .accessibilityLabel("Metadata was auto filled from the image")
}
```

- [ ] **Step 6: Build and manually inspect import**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Manual checks:

- Picking a photo shows `IMPORTING` until the file is ready.
- Invalid drops show a visible failure message.
- A normal file/photo import still starts background removal.
- Category/color auto-fill remains editable.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/Views/AddItem/ImageImportView.swift Pyxis/Views/AddItem/MetadataEditorView.swift
git commit -m "feat: clarify image import states"
```

### Task 5: Make Saved Fits Manageable And Accessible

**Files:**

- Modify: `Pyxis/Views/OutfitBuilder/SavedFitsStrip.swift:50-121`
- Modify: `Pyxis/Views/OutfitBuilder/SavedFitsGalleryView.swift:12-48`
- Modify: `Pyxis/Views/OutfitBuilder/OutfitDetailView.swift:4-98`
- Modify: `Tests/PyxisTests/PersistenceTests.swift`

- [ ] **Step 1: Improve saved-fit card accessibility**

In `SavedFitCard`, add:

```swift
private var accessibilitySummary: String {
    let names = selectedItems.map { item in
        item.displayName ?? item.itemCode
    }
    return names.isEmpty ? "Open saved fit" : "Open saved fit with \(names.joined(separator: ", "))"
}
```

Replace:

```swift
.accessibilityLabel("Open saved fit")
```

with:

```swift
.accessibilityLabel(accessibilitySummary)
```

- [ ] **Step 2: Add an empty-gallery build action**

Update `SavedFitsGalleryView` to accept an optional build action. The action should request the parent to open the builder after the gallery dismisses, not present another sheet directly from inside this sheet:

```swift
struct SavedFitsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var selectedOutfit: Outfit?
    let buildAction: (() -> Void)?

    init(buildAction: (() -> Void)? = nil) {
        self.buildAction = buildAction
    }
```

In the empty branch, replace the single text with:

```swift
VStack(spacing: PyxisSpacing.md) {
    Text("NO SAVED FITS")
        .font(PyxisTypography.body)
        .foregroundStyle(PyxisColors.inactiveText)

    if let buildAction {
        Button("BUILD FIRST FIT") {
            dismiss()
            buildAction()
        }
        .buttonStyle(MinimalButtonStyle())
    }
}
```

In `ClosetGridView`, add parent-owned handoff state:

```swift
@State private var shouldOpenBuilderAfterSavedFitsDismiss = false
```

Then update the saved-fits sheet:

```swift
.sheet(
    isPresented: $isShowingSavedFits,
    onDismiss: {
        guard shouldOpenBuilderAfterSavedFitsDismiss else {
            return
        }
        shouldOpenBuilderAfterSavedFitsDismiss = false
        builderFocusItem = nil
        isShowingBuilder = true
    }
) {
    SavedFitsGalleryView {
        shouldOpenBuilderAfterSavedFitsDismiss = true
    }
}
```

- [ ] **Step 3: Add outfit delete confirmation**

In `OutfitDetailView`, add state:

```swift
@State private var isConfirmingDelete = false
```

Add a destructive button below the favorite toggle:

```swift
Button("DELETE FIT") {
    isConfirmingDelete = true
}
.buttonStyle(MinimalButtonStyle())
```

Add confirmation to the root view:

```swift
.confirmationDialog("Delete this fit?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
    Button("DELETE FIT", role: .destructive) {
        modelContext.delete(outfit)
        try? modelContext.save()
        dismiss()
    }
    Button("CANCEL", role: .cancel) {}
}
```

- [ ] **Step 4: Add an item-delete confirmation too**

In `ItemDetailView`, replace immediate deletion (`Pyxis/Views/ItemDetail/ItemDetailView.swift:129-134`) with `@State private var isConfirmingDelete = false` and:

```swift
Button("DELETE ITEM") {
    isConfirmingDelete = true
}
.buttonStyle(MinimalButtonStyle())
```

Add:

```swift
.confirmationDialog("Delete this item?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
    Button("DELETE ITEM", role: .destructive) {
        viewModel.deleteImages(for: item)
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
    Button("CANCEL", role: .cancel) {}
}
```

- [ ] **Step 5: Build and manually inspect**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Manual checks:

- Empty saved-fits gallery offers `BUILD FIRST FIT`.
- Saved-fit VoiceOver labels include at least one selected item name or code.
- Deleting a fit requires confirmation and removes it from strip/gallery.
- Deleting an item requires confirmation and still deletes related images.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/Views/OutfitBuilder/SavedFitsStrip.swift Pyxis/Views/OutfitBuilder/SavedFitsGalleryView.swift Pyxis/Views/OutfitBuilder/OutfitDetailView.swift Pyxis/Views/ItemDetail/ItemDetailView.swift
git commit -m "feat: improve saved fit management"
```

### Task 6: Introduce An Outfit Builder View Model

**Files:**

- Create: `Pyxis/ViewModels/OutfitBuilderViewModel.swift`
- Modify: `Pyxis/Views/OutfitBuilder/OutfitBuilderView.swift:4-224`
- Create: `Tests/PyxisTests/OutfitBuilderViewModelTests.swift`

- [ ] **Step 1: Write view-model tests**

Create `Tests/PyxisTests/OutfitBuilderViewModelTests.swift`:

```swift
import XCTest
@testable import PyxisCore

@MainActor
final class OutfitBuilderViewModelTests: XCTestCase {
    func testUpdateBuildsRowsAndDefaultSelections() {
        let top = item("TS-001", .tops, .tShirt)
        let bottom = item("PT-001", .bottoms, .pants)
        let shoe = item("SH-001", .footwear, .sneakers)

        let viewModel = OutfitBuilderViewModel()
        viewModel.updateItems([shoe, bottom, top])

        XCTAssertEqual(viewModel.requiredRows.map(\.slot), [.top, .bottom, .footwear])
        XCTAssertTrue(viewModel.canSave)
    }

    func testFocusSelectsMatchingItem() {
        let first = item("TS-001", .tops, .tShirt)
        let second = item("TS-002", .tops, .tShirt)

        let viewModel = OutfitBuilderViewModel(initialItemID: second.id)
        viewModel.updateItems([first, second, item("PT-001", .bottoms, .pants), item("SH-001", .footwear, .sneakers)])

        XCTAssertEqual(viewModel.selectedIndex(for: .top), 1)
    }

    func testItemFingerprintChangesWhenBuildRelevantFieldsChange() {
        let top = item("TS-001", .tops, .tShirt)
        let viewModel = OutfitBuilderViewModel()
        let originalFingerprint = viewModel.itemFingerprint(for: [top])

        top.favorite = true
        top.itemCode = "TS-099"
        top.category = .outerwear

        XCTAssertNotEqual(viewModel.itemFingerprint(for: [top]), originalFingerprint)
    }

    private func item(_ code: String, _ category: ClothingCategory, _ subtype: ClothingSubtype) -> ClosetItem {
        ClosetItem(
            itemCode: code,
            category: category,
            subtype: subtype,
            primaryColor: .black,
            imageOriginalPath: "Images/Originals/\(code).png"
        )
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter OutfitBuilderViewModelTests
```

Expected: fail because `OutfitBuilderViewModel` and `itemFingerprint(for:)` do not exist.

- [ ] **Step 3: Add the view model**

Create `Pyxis/ViewModels/OutfitBuilderViewModel.swift`:

```swift
import Foundation

@MainActor
final class OutfitBuilderViewModel: ObservableObject {
    @Published private(set) var rows: [OutfitRow] = []
    @Published private(set) var requiredRows: [OutfitRow] = []
    @Published private(set) var draft = OutfitDraft()
    @Published var selections: [OutfitSlot: Int] = [:]
    @Published var notes = ""
    @Published var savedConfirmationID: UUID?

    private let service: OutfitBuilderService
    private var focusedItemID: UUID?

    init(
        initialItemID: UUID? = nil,
        service: OutfitBuilderService = OutfitBuilderService()
    ) {
        self.focusedItemID = initialItemID
        self.service = service
    }

    var canSave: Bool {
        service.canSave(draft)
    }

    func updateItems(_ items: [ClosetItem]) {
        requiredRows = service.requiredRows(from: items)
        rows = requiredRows + service.optionalRows(from: items).filter { !$0.items.isEmpty }
        reconcileSelections()
        draft = service.draft(from: rows, selections: selections)
    }

    func itemFingerprint(for items: [ClosetItem]) -> [OutfitBuilderItemFingerprint] {
        items.map(OutfitBuilderItemFingerprint.init(item:))
    }

    func selectedIndex(for slot: OutfitSlot) -> Int? {
        selections[slot]
    }

    func select(_ index: Int, for slot: OutfitSlot) {
        selections[slot] = index
        draft = service.draft(from: rows, selections: selections)
    }

    func advance(_ slot: OutfitSlot, by offset: Int) {
        guard let row = rows.first(where: { $0.slot == slot }) else {
            return
        }
        selections[slot] = service.advancedIndex(
            from: selections[slot],
            offset: offset,
            itemCount: row.items.count
        )
        draft = service.draft(from: rows, selections: selections)
    }

    func focusItem(_ itemID: UUID?) {
        focusedItemID = itemID
        reconcileSelections()
        draft = service.draft(from: rows, selections: selections)
    }

    func makeOutfit() -> Outfit? {
        guard canSave else {
            return nil
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return service.outfit(
            from: draft,
            name: nil,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
    }

    func markSaved(_ outfitID: UUID) {
        notes = ""
        savedConfirmationID = outfitID
    }

    func clearSavedConfirmation(ifMatching outfitID: UUID) {
        guard savedConfirmationID == outfitID else {
            return
        }
        savedConfirmationID = nil
    }

    func defaultSubtype(for slot: OutfitSlot) -> ClothingSubtype {
        service.defaultSubtype(for: slot)
    }

    private func reconcileSelections() {
        let defaults = service.defaultSelections(for: rows)
        for row in rows {
            guard !row.items.isEmpty else {
                selections[row.slot] = nil
                continue
            }

            if let index = selections[row.slot], row.items.indices.contains(index) {
                continue
            }

            selections[row.slot] = defaults[row.slot]
        }

        if let focusedItemID,
           let target = service.selectionTarget(for: focusedItemID, in: rows) {
            selections[target.slot] = target.index
            self.focusedItemID = nil
        }
    }
}

struct OutfitBuilderItemFingerprint: Equatable {
    let id: UUID
    let itemCode: String
    let category: ClothingCategory
    let subtype: ClothingSubtype
    let favorite: Bool

    init(item: ClosetItem) {
        self.id = item.id
        self.itemCode = item.itemCode
        self.category = item.category
        self.subtype = item.subtype
        self.favorite = item.favorite
    }
}
```

- [ ] **Step 4: Refactor `OutfitBuilderView` to use the view model**

Replace local state:

```swift
@State private var selections: [OutfitSlot: Int] = [:]
@State private var notes = ""
@State private var focusedItemID: UUID?
@State private var savedConfirmationID: UUID?
private let service = OutfitBuilderService()
private let initialItemID: UUID?
```

with:

```swift
@StateObject private var viewModel: OutfitBuilderViewModel
private let initialItemID: UUID?
private let service = OutfitBuilderService()
```

Update `init`:

```swift
init(initialItem: ClosetItem? = nil) {
    self.initialItemID = initialItem?.id
    self._viewModel = StateObject(wrappedValue: OutfitBuilderViewModel(initialItemID: initialItem?.id))
}
```

Replace `rows`, `requiredRows`, and `draft` computed properties with `viewModel.rows`, `viewModel.requiredRows`, and `viewModel.draft`.

Update carousel call:

```swift
OutfitCarouselRow(
    row: row,
    selectedIndex: viewModel.selectedIndex(for: row.slot),
    selectIndex: { viewModel.select($0, for: row.slot) },
    advance: { offset in viewModel.advance(row.slot, by: offset) },
    openItem: { selectedItem = $0 }
)
```

Update lifecycle:

```swift
.onAppear {
    viewModel.updateItems(items)
}
.onChange(of: initialItemID) { _, newValue in
    viewModel.focusItem(newValue)
    viewModel.updateItems(items)
}
.onChange(of: viewModel.itemFingerprint(for: items)) { _, _ in
    viewModel.updateItems(items)
}
```

Update add flow:

```swift
AddItemFlow(
    initialCategory: pendingAddSlot?.category,
    initialSubtype: pendingAddSlot.map(viewModel.defaultSubtype(for:)),
    onSave: { item in
        viewModel.focusItem(item.id)
    }
)
```

Update `SavedFitsStrip`:

```swift
SavedFitsStrip(outfits: outfits, items: items, recentOutfitID: viewModel.savedConfirmationID) { outfit in
    selectedOutfit = outfit
}
```

Update `notesField`:

```swift
TextField("FIT NOTES", text: $viewModel.notes, axis: .vertical)
```

Update `saveButton`:

```swift
.disabled(!viewModel.canSave)
.opacity(viewModel.canSave ? 1 : 0.35)
```

Replace `saveFit()` body:

```swift
guard let outfit = viewModel.makeOutfit() else {
    return
}
modelContext.insert(outfit)
try? modelContext.save()
withAnimation(.easeOut(duration: 0.24)) {
    viewModel.markSaved(outfit.id)
}
Task {
    try? await Task.sleep(nanoseconds: 1_600_000_000)
    await MainActor.run {
        withAnimation(.easeOut(duration: 0.2)) {
            viewModel.clearSavedConfirmation(ifMatching: outfit.id)
        }
    }
}
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
swift test --filter OutfitBuilderViewModelTests
swift test
```

Expected: both pass.

- [ ] **Step 6: Build app target**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/ViewModels/OutfitBuilderViewModel.swift Pyxis/Views/OutfitBuilder/OutfitBuilderView.swift Tests/PyxisTests/OutfitBuilderViewModelTests.swift
git commit -m "refactor: derive outfit builder state in view model"
```

### Task 7: Add Accessibility And Dynamic-Type Guardrails

**Files:**

- Modify: `Pyxis/DesignSystem/PyxisTypography.swift`
- Modify call sites only where build errors require it.
- Modify: `docs/MANUAL_QA.md`

- [ ] **Step 1: Make font tokens scalable**

Replace `Pyxis/DesignSystem/PyxisTypography.swift` with:

```swift
import SwiftUI

enum PyxisTypography {
    static let nav = Font.system(size: 12, weight: .medium, design: .monospaced, relativeTo: .caption)
    static let code = Font.system(size: 11, weight: .regular, design: .monospaced, relativeTo: .caption2)
    static let body = Font.system(size: 12, weight: .regular, design: .monospaced, relativeTo: .body)
    static let label = Font.system(size: 10, weight: .regular, design: .monospaced, relativeTo: .caption2)
    static let title = Font.system(size: 18, weight: .medium, design: .monospaced, relativeTo: .title3)
}
```

- [ ] **Step 2: Add minimum scale only to tight labels**

For `UppercaseNavLabel` in `Pyxis/DesignSystem/PyxisComponents.swift`, add:

```swift
.minimumScaleFactor(0.82)
.accessibilityAddTraits(isActive ? .isSelected : [])
```

For `ItemCodeLabel`, add:

```swift
.minimumScaleFactor(0.82)
```

- [ ] **Step 3: Update manual QA**

Append to `docs/MANUAL_QA.md`:

```markdown

## UX And Performance Polish Checks

28. With at least 30 closet items, scroll the grid twice and confirm image loading does not visibly freeze the first scroll.
29. Open `BUILD`, swipe every populated carousel row, and confirm the selected item updates without stutter.
30. Apply category, color, favorites, sort, and search filters; confirm active filter count appears and `CLEAR` resets the grid.
31. Open the color `MORE` menu and confirm every `ClosetColor` case is reachable.
32. Try an invalid image drop and confirm a visible error appears.
33. Save a fit, open it from `FITS`, rename it, mark worn, and delete it with confirmation.
34. Turn on a larger Dynamic Type size and confirm nav labels, item codes, buttons, and form fields remain readable without overlap.
35. With VoiceOver enabled, confirm saved-fit cards announce the fit contents and filter buttons announce selected state.
```

- [ ] **Step 4: Build app target**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/DesignSystem/PyxisTypography.swift Pyxis/DesignSystem/PyxisComponents.swift docs/MANUAL_QA.md
git commit -m "polish: add accessibility guardrails"
```

---

## Final Verification

- [ ] Run package tests:

```bash
swift test
```

Expected: all XCTest cases pass.

- [ ] Run compile-only app build:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: build succeeds with no new warnings.

- [ ] If no other chat/session owns the simulator, boot and run the app, then execute `docs/MANUAL_QA.md` steps 1-35.

- [ ] Capture before/after notes for:
  - grid first scroll
  - builder carousel swipe
  - filter clear flow
  - invalid import feedback
  - saved-fit delete confirmation
  - larger Dynamic Type
  - VoiceOver labels for saved fits and filters

## Implementation Notes For The Agent

- Keep all changes local-first. Do not add network calls, analytics, cloud sync, remote image processing, or accounts.
- Keep the visual language calm: white/near-white surfaces, restrained lines, compact type, no gradients, no decorative chrome.
- Prefer focused helpers and view models over restructuring the app shell.
- Avoid touching unrelated untracked files. Stage only the files named by the active task unless the user explicitly expands scope.
- If simulator inspection is needed, first check whether another worker is using Simulator. Use compile-only builds when in doubt.

## Self-Review

Spec coverage:

- Speed: Tasks 1, 2, and 6 address downsampled async image loading, grid derivation, and builder derivation.
- Intuitiveness: Tasks 3, 4, and 5 address filter clarity, import feedback, saved-fit management, and delete confirmation.
- UI/accessibility: Tasks 3, 5, and 7 address active states, VoiceOver labels, Dynamic Type, and manual QA.
- Non-interruption: plan uses compile-only builds by default and explicitly gates simulator launch.

Placeholder scan:

- No placeholder instructions are included.

Type consistency:

- New helpers reference existing project types: `ClosetItem`, `ClosetFilterState`, `OutfitRow`, `OutfitSlot`, `OutfitDraft`, `OutfitBuilderService`, `PyxisTypography`, and `PyxisColors`.
- Grid derivation uses `ClosetGridItemFingerprint` so `visibleItems` updates when filter-relevant item metadata changes, not only when item IDs are inserted or removed.
- Saved-fits gallery opens the builder through a parent-owned dismissal handoff so it does not present a new sheet while the gallery sheet is still dismissing.
