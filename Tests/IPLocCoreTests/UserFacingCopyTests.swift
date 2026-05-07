import Testing
@testable import IPLocCore

@Test func initialDatabaseDownloadCopyIsEnglishAndAvoidsImplementationDetails() {
    #expect(DownloadPromptCopy.initialDatabaseTitle == "Download IP Location Database")
    #expect(DownloadPromptCopy.initialDatabaseMessage == "IPLoc needs to download the DB-IP City Lite database, about 125 MB, to show country, region, and city. You can update it later from the menu.")
    #expect(!DownloadPromptCopy.initialDatabaseMessage.contains("not bundled"))
    #expect(!DownloadPromptCopy.initialDatabaseMessage.contains("Application Support"))
}

@Test func databaseUpdateCopyExplainsMonthlyCadence() {
    #expect(DownloadPromptCopy.databaseAttributionAndCadence == "Data source: DB-IP.com. Lite databases are updated monthly.")
}

@Test func databaseUpdateErrorCopyIsBrief() {
    #expect(DownloadPromptCopy.briefDatabaseUpdateError == "Could not update the database. Check your connection and try again.")
}

@Test func menuCopyUsesEnglishLabelsAndMonthlyDatabaseHint() {
    #expect(AppMenuCopy.publicIP("173.44.178.162") == "Public IP: 173.44.178.162")
    #expect(AppMenuCopy.publicIP(nil) == "Public IP: Unknown")
    #expect(AppMenuCopy.location("United States / Virginia / Ashburn") == "Location: United States / Virginia / Ashburn")
    #expect(AppMenuCopy.localIP("192.168.0.245") == "LAN IP: 192.168.0.245")
    #expect(AppMenuCopy.databaseInstalled(release: DBIPDatabaseRelease(year: 2026, month: 5)) == "Database: DB-IP City Lite 2026-05")
    #expect(AppMenuCopy.databaseNotInstalled == "Database: Not installed")
    #expect(AppMenuCopy.status("Refreshing") == "Status: Refreshing")
    #expect(AppMenuCopy.refresh == "Refresh")
    #expect(AppMenuCopy.updateDatabase == "Update Database")
    #expect(AppMenuCopy.downloadDatabase == "Download Database")
    #expect(AppMenuCopy.deleteDatabase == "Delete Database...")
    #expect(AppMenuCopy.quit == "Quit")
}

@Test func deleteDatabaseCopyIsBriefAndEnglish() {
    #expect(DownloadPromptCopy.deleteDatabaseTitle == "Delete Downloaded Database?")
    #expect(DownloadPromptCopy.deleteDatabaseMessage == "This removes the downloaded IP location database. The app itself will not be deleted.")
    #expect(DownloadPromptCopy.deleteDatabaseConfirm == "Delete Database")
    #expect(DownloadPromptCopy.cancel == "Cancel")
}

@Test func statusBarIconUsesSystemTemplateSymbol() {
    #expect(StatusBarIconSpec.symbolName == "location.fill")
}
