// Type 1 — Fire and forget
// Use when: native API returns Void, no nativeToHybrid contract file.
// Example: trackInboxClick, deleteInboxEntry
// RULE: identifier is Optional<String> — use guard let and return on failure.
// RULE: if the method needs a campaignID, also guard it from MoEngagePluginInboxUtils.fetchCampaignIdFromPayload.

@objc public func <methodName>(_ payload: [String: Any]) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    else { return }
    MoEngageSDKInbox.sharedInstance.<nativeMethod>(forAppID: identifier)
}

// Real example — trackInboxClick (needs campaignID in addition to identifier)
@objc public func trackInboxClick(_ inboxDict: [String: Any]) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: inboxDict),
          let campaignID = MoEngagePluginInboxUtils.fetchCampaignIdFromPayload(inboxDict: inboxDict)
    else { return }
    MoEngageSDKInbox.sharedInstance.trackInboxClick(withCampaignID: campaignID, forAppID: identifier)
}

// Real example — deleteInboxEntry (needs campaignID in addition to identifier)
@objc public func deleteInboxEntry(_ inboxDict: [String: Any]) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: inboxDict),
          let campaignID = MoEngagePluginInboxUtils.fetchCampaignIdFromPayload(inboxDict: inboxDict)
    else { return }
    MoEngageSDKInbox.sharedInstance.removeInboxMessage(withCampaignID: campaignID, forAppID: identifier)
}
