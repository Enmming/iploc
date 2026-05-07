import AppKit
import IPLocCore
import Network

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let store: DatabaseStore
    private let publicIPClient = PublicIPClient()
    private let refreshPolicy = RefreshPolicy(timerInterval: 60, networkDebounceInterval: 2)
    private let monitorQueue = DispatchQueue(label: "app.iploc.network-monitor")
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    private var networkMonitor: NWPathMonitor?
    private var timer: Timer?
    private var spinnerTimer: Timer?
    private var spinnerFrameIndex = 0
    private var resolver: GeoIPResolver?
    private var metadata: DatabaseMetadata?
    private var snapshot = IPSnapshot(publicIP: nil, localIP: nil, location: nil, message: "Starting")
    private var transientStatus: String?
    private var lastRefreshAt: Date?
    private var lastNetworkRefreshAt: Date?
    private var isRefreshing = false
    private var isUpdatingDatabase = false

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = (try? DatabaseStore.userApplicationSupport()) ?? DatabaseStore(
            applicationSupportDirectory: URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        )

        super.init()

        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.delegate = self
        configureStatusItem()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadLocalDatabaseState()
        rebuildMenu()
        startNetworkMonitoring()
        startTimer()

        if store.databaseExists() {
            requestRefresh(trigger: .launch)
        } else {
            promptForInitialDatabaseDownload()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkMonitor?.cancel()
        timer?.invalidate()
        spinnerTimer?.invalidate()
    }

    private func configureStatusItem() {
        configureStatusBarIcon()
        statusItem.button?.title = StatusFormatter.statusBarTitle(for: snapshot, isBusy: true, spinnerFrame: spinnerFrames[0])
        statusItem.menu = menu
        rebuildMenu()
    }

    private func configureStatusBarIcon() {
        guard let image = NSImage(systemSymbolName: StatusBarIconSpec.symbolName, accessibilityDescription: "IPLoc")
        else {
            return
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let configuredImage = image.withSymbolConfiguration(configuration) ?? image
        configuredImage.isTemplate = true
        statusItem.button?.image = configuredImage
        statusItem.button?.imagePosition = .imageLeading
    }

    private func promptForInitialDatabaseDownload() {
        let alert = NSAlert()
        alert.messageText = DownloadPromptCopy.initialDatabaseTitle
        alert.informativeText = DownloadPromptCopy.initialDatabaseMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            updateDatabaseThenRefresh()
        } else {
            snapshot = IPSnapshot(publicIP: nil, localIP: LocalIPAddressProvider.current(), location: nil, message: "Database required")
            applyStatusTitle()
            rebuildMenu()
        }
    }

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestRefresh(trigger: .networkChange)
            }
        }
        monitor.start(queue: monitorQueue)
        networkMonitor = monitor
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshPolicy.timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestRefresh(trigger: .timer)
            }
        }
    }

    private func requestRefresh(trigger: RefreshTrigger) {
        guard !isRefreshing, !isUpdatingDatabase else {
            return
        }
        guard store.databaseExists() else {
            snapshot = IPSnapshot(publicIP: snapshot.publicIP, localIP: LocalIPAddressProvider.current(), location: snapshot.location, message: "Database required")
            applyStatusTitle()
            rebuildMenu()
            return
        }

        let now = Date()
        guard refreshPolicy.shouldRefresh(
            trigger: trigger,
            now: now,
            lastRefreshAt: lastRefreshAt,
            lastNetworkRefreshAt: lastNetworkRefreshAt
        ) else {
            return
        }

        lastRefreshAt = now
        if trigger == .networkChange {
            lastNetworkRefreshAt = now
        }

        Task { [weak self] in
            await self?.refreshSnapshot()
        }
    }

    private func refreshSnapshot() async {
        isRefreshing = true
        transientStatus = "Refreshing"
        applyStatusTitle()
        rebuildMenu()

        let localIP = LocalIPAddressProvider.current()
        do {
            let publicIP = try await publicIPClient.fetch()
            let resolver = try resolver ?? GeoIPResolver(databaseURL: store.activeDatabaseURL)
            self.resolver = resolver
            let location = try resolver.location(for: publicIP)
            snapshot = IPSnapshot(publicIP: publicIP, localIP: localIP, location: location, message: nil)
        } catch {
            snapshot = IPSnapshot(
                publicIP: snapshot.publicIP,
                localIP: localIP,
                location: snapshot.location,
                message: "Refresh failed"
            )
        }

        transientStatus = nil
        isRefreshing = false
        applyStatusTitle()
        rebuildMenu()
    }

    private func updateDatabaseThenRefresh() {
        guard !isUpdatingDatabase else {
            return
        }

        isUpdatingDatabase = true
        transientStatus = "Preparing database download"
        applyStatusTitle()
        rebuildMenu()

        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let updater = DBIPDatabaseUpdater(store: store)
                let metadata = try await updater.update { event in
                    await MainActor.run {
                        self.handleDatabaseUpdateEvent(event)
                    }
                }
                self.metadata = metadata
                self.resolver = try GeoIPResolver(databaseURL: self.store.activeDatabaseURL)
                self.snapshot = IPSnapshot(publicIP: self.snapshot.publicIP, localIP: LocalIPAddressProvider.current(), location: self.snapshot.location, message: nil)
                self.transientStatus = nil
                self.isUpdatingDatabase = false
                self.applyStatusTitle()
                self.rebuildMenu()
                self.requestRefresh(trigger: .manual)
            } catch {
                self.transientStatus = nil
                self.isUpdatingDatabase = false
                self.snapshot = IPSnapshot(
                    publicIP: self.snapshot.publicIP,
                    localIP: LocalIPAddressProvider.current(),
                    location: self.snapshot.location,
                    message: "Database update failed"
                )
                self.applyStatusTitle()
                self.rebuildMenu()
                self.showDatabaseUpdateError(error)
            }
        }
    }

    private func handleDatabaseUpdateEvent(_ event: DBIPUpdateEvent) {
        switch event {
        case let .trying(release):
            transientStatus = "Checking \(release.year)-\(String(format: "%02d", release.month))"
        case .downloading:
            transientStatus = "Downloading database"
        case .decompressing:
            transientStatus = "Extracting database"
        case .installing:
            transientStatus = "Installing database"
        case .finished:
            transientStatus = "Database updated"
        }
        applyStatusTitle()
        rebuildMenu()
    }

    private func showDatabaseUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Database Update Failed"
        alert.informativeText = DownloadPromptCopy.briefDatabaseUpdateError
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func loadLocalDatabaseState() {
        metadata = try? store.readMetadata()
        if store.databaseExists() {
            resolver = try? GeoIPResolver(databaseURL: store.activeDatabaseURL)
            snapshot = IPSnapshot(publicIP: nil, localIP: LocalIPAddressProvider.current(), location: nil, message: "Refreshing")
        } else {
            snapshot = IPSnapshot(publicIP: nil, localIP: LocalIPAddressProvider.current(), location: nil, message: "Database required")
        }
        applyStatusTitle()
    }

    private func applyStatusTitle() {
        updateSpinnerTimer()
        let frame = spinnerFrames[spinnerFrameIndex % spinnerFrames.count]
        statusItem.button?.title = StatusFormatter.statusBarTitle(for: snapshot, isBusy: isBusy, spinnerFrame: frame)
    }

    private var isBusy: Bool {
        isRefreshing || isUpdatingDatabase || transientStatus != nil
    }

    private func updateSpinnerTimer() {
        if isBusy {
            guard spinnerTimer == nil else {
                return
            }

            let animationTimer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.advanceSpinner()
                }
            }
            RunLoop.main.add(animationTimer, forMode: .common)
            spinnerTimer = animationTimer
        } else {
            spinnerTimer?.invalidate()
            spinnerTimer = nil
            spinnerFrameIndex = 0
        }
    }

    private func advanceSpinner() {
        guard isBusy else {
            updateSpinnerTimer()
            applyStatusTitle()
            return
        }

        spinnerFrameIndex = (spinnerFrameIndex + 1) % spinnerFrames.count
        let frame = spinnerFrames[spinnerFrameIndex]
        statusItem.button?.title = StatusFormatter.statusBarTitle(for: snapshot, isBusy: true, spinnerFrame: frame)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addDisabledItem(AppMenuCopy.publicIP(snapshot.publicIP))
        addDisabledItem(AppMenuCopy.location(locationSummary()))
        addDisabledItem(AppMenuCopy.localIP(snapshot.localIP))

        if let metadata {
            menu.addItem(.separator())
            addDisabledItem(AppMenuCopy.databaseInstalled(release: metadata.release))
        } else {
            menu.addItem(.separator())
            addDisabledItem(AppMenuCopy.databaseNotInstalled)
        }
        addDisabledItem(DownloadPromptCopy.databaseAttributionAndCadence)

        if let transientStatus {
            addDisabledItem(AppMenuCopy.status(transientStatus))
        } else if let message = snapshot.message {
            addDisabledItem(AppMenuCopy.status(message))
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: AppMenuCopy.refresh, action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing && !isUpdatingDatabase && store.databaseExists()
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: store.databaseExists() ? AppMenuCopy.updateDatabase : AppMenuCopy.downloadDatabase, action: #selector(updateDatabaseFromMenu), keyEquivalent: "u")
        updateItem.target = self
        updateItem.isEnabled = !isUpdatingDatabase
        menu.addItem(updateItem)

        let deleteDatabaseItem = NSMenuItem(title: AppMenuCopy.deleteDatabase, action: #selector(deleteDatabaseFromMenu), keyEquivalent: "")
        deleteDatabaseItem.target = self
        deleteDatabaseItem.isEnabled = !isRefreshing && !isUpdatingDatabase && store.databaseExists()
        menu.addItem(deleteDatabaseItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: AppMenuCopy.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func locationSummary() -> String? {
        guard let location = snapshot.location else {
            return nil
        }

        let parts = [location.countryName, location.regionName, location.cityName].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    @objc private func refreshNow() {
        requestRefresh(trigger: .manual)
    }

    @objc private func updateDatabaseFromMenu() {
        updateDatabaseThenRefresh()
    }

    @objc private func deleteDatabaseFromMenu() {
        let alert = NSAlert()
        alert.messageText = DownloadPromptCopy.deleteDatabaseTitle
        alert.informativeText = DownloadPromptCopy.deleteDatabaseMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: DownloadPromptCopy.deleteDatabaseConfirm)
        alert.addButton(withTitle: DownloadPromptCopy.cancel)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try store.deleteDownloadedData()
            metadata = nil
            resolver = nil
            snapshot = IPSnapshot(
                publicIP: snapshot.publicIP,
                localIP: LocalIPAddressProvider.current(),
                location: nil,
                message: "Database required"
            )
            transientStatus = nil
            applyStatusTitle()
            rebuildMenu()
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Could Not Delete Database"
            errorAlert.informativeText = "Close IPLoc and try again."
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
