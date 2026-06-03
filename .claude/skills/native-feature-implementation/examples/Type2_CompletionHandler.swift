// Type 2 — Completion handler
// Use when: nativeToHybrid contract exists AND native API has a completion closure.
// Example: getInboxMessages, getUnreadMessageCount
// RULE: build response via a MoEngagePluginInboxUtils.create<X>Payload helper.
// RULE: response keys must exactly match the nativeToHybrid contract.

@objc public func <methodName>(_ payload: [String: Any], completionHandler: @escaping(([String: Any]) -> Void)) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)
    else { return }
    MoEngageSDKInbox.sharedInstance.<nativeMethod>(forAppID: identifier) { [weak self] result, _ in
        let responsePayload = MoEngagePluginInboxUtils.create<X>Payload(result, identifier: identifier)
        completionHandler(responsePayload)
    }
}

// Real example — getUnreadMessageCount (response is Int)
@objc public func getUnreadMessageCount(_ inboxDict: [String: Any], completionHandler: @escaping(([String: Any]) -> Void)) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: inboxDict) else { return }
    MoEngageSDKInbox.sharedInstance.getUnreadNotificationCount(forAppID: identifier) { [weak self] count, _ in
        let payload = MoEngagePluginInboxUtils.createUnreadCountPayload(count: count, identifier: identifier)
        completionHandler(payload)
    }
}

// Real example — getInboxMessages (response is [MoEngageInboxEntry])
@objc public func getInboxMessages(_ inboxDict: [String: Any], completionHandler: @escaping(([String: Any]) -> Void)) {
    guard let identifier = MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: inboxDict) else { return }
    MoEngageSDKInbox.sharedInstance.getInboxMessages(forAppID: identifier) { [weak self] inboxMessages, _ in
        let payload = MoEngagePluginInboxUtils.inboxEntryToJSON(inboxMessages: inboxMessages, identifier: identifier)
        completionHandler(payload)
    }
}
