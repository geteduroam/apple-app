import Dependencies
import Foundation
import OSLog
import UserNotifications

extension String {
    public static let renewCategoryId = "RENEW_CATEGORY"
    public static let renewNowActionId = "RENEW_NOW_ACTION"
    public static let remindMeActionId = "REMIND_ME_ACTION"
    public static let providerIdKey = "PROVIDER_ID"
    public static let profileIdKey = "PROFILE_ID"
    public static let validUntilKey = "VALID_UNTIL"
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
    
    public enum NotificationClientKey: TestDependencyKey {
        public static var testValue = NotificationClient.mock
    }
}

extension DependencyValues.NotificationClientKey: DependencyKey {
    public static let liveValue = NotificationClient.live
}

public struct NotificationClient {
    public var scheduleRenewReminder: (/* validUntil: */ Date, /* providerId: */ String, /* profileId: */ String) async throws -> Void
    public var delegate: @Sendable () -> AsyncStream<DelegateEvent>
    
    public enum DelegateEvent: Equatable {
        case renewActionTriggered(providerId: String, profileId: String)
        case remindMeLaterActionTriggered(validUntil: Date, providerId: String, profileId: String)
    }
}

extension NotificationClient {
    static var mock: Self = .init(
        scheduleRenewReminder: unimplemented("\(Self.self).scheduleRenewReminder"),
        delegate: unimplemented("\(Self.self).delegate"))
}

extension Logger {
    static var notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NotificationClient", category: "notifications")
}

extension NotificationClient {
    static var live: Self = .init(
        scheduleRenewReminder: { validUntil, providerId, profileId in
            Logger.notifications.info("Try to schedule renew reminder for provider \(providerId) profile \(profileId) valid until \(validUntil)")
            
            @Dependency(\.calendar) var calendar
            @Dependency(\.date.now) var now
            
            let center = UNUserNotificationCenter.current()
            
            // Check if user has granted permission
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
            guard granted else { return }
            
            // Declare custom actions: Renew Now | Remind Me Later
            let renewNowAction = UNNotificationAction(identifier: .renewNowActionId, title: NSLocalizedString("Renew Now", comment: "Renew Now"), options: [.authenticationRequired], icon: UNNotificationActionIcon(systemImageName:  "arrow.triangle.2.circlepath"))
            let remindMeAction = UNNotificationAction(identifier: .remindMeActionId, title: NSLocalizedString("Remind Me Later", comment: "Remind Me Later"), options: [], icon: UNNotificationActionIcon(systemImageName: "alarm"))
            
            let renewCategory = UNNotificationCategory(identifier: .renewCategoryId, actions: [renewNowAction, remindMeAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: NSLocalizedString("Renew your connection to extend your access.", comment: "Renew your connection to extend your access."), categorySummaryFormat: nil, options: [.hiddenPreviewsShowTitle])
            center.setNotificationCategories([renewCategory])
            
            // Cancel any pending reminders
            let identifierParts: [String] = [.renewCategoryId, providerId, profileId]
            let requestId = identifierParts.joined(separator: "|")
            center.removePendingNotificationRequests(withIdentifiers: [requestId])
            
            // Check notification settings
            let settings = await center.notificationSettings()
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Your network access is about to expire", comment: "Your network access is about to expire")
            content.body = String(format: NSLocalizedString("You have access until %@. Renew your connection to extend your access.", comment: "You have access until <date>. Renew your connection to extend your access."), DateFormatter.localizedString(from: validUntil, dateStyle: .medium, timeStyle: .short))
            let userInfo: [String: Any] = [.providerIdKey: providerId, .profileIdKey: profileId, .validUntilKey: validUntil]
            content.userInfo = userInfo
            content.categoryIdentifier = .renewCategoryId
            content.sound = settings.soundSetting == .enabled ? .default : nil
      
            // Specify delivery
            
            // validUntil date must be in the future
            let secondsUntilExpiration = validUntil.timeIntervalSince(now)
            guard secondsUntilExpiration > 0 else { return }
            
            var triggerDate: Date?
            
            // Try to warn 5 days before at 9 AM, then each day, then halfway between now and expiration
            for daysBefore in -5...0 {
                guard let earliestReminderDate = calendar.date(byAdding: .day, value: daysBefore, to: validUntil) else { continue }
                
                // Find 9 AM after earliest reminder for day
                guard let candidateDate = calendar.nextDate(after: earliestReminderDate, matching: DateComponents(hour: 9, minute: 0), matchingPolicy: .nextTime) else { continue }
                
                // Candidate should be at least 60 minutes into the future, but before validUntil
                let timeFromNow = candidateDate.timeIntervalSince(now)
                let candidateIsBeforeValidUntil = validUntil.timeIntervalSince(candidateDate) > 0
                if candidateIsBeforeValidUntil && timeFromNow > 3600 {
                    triggerDate = candidateDate
                    break
                }
                
                // If at 0 days, schedule for half of remaining time until validUntil
                if daysBefore == 0 {
                    let remainingTime = validUntil.timeIntervalSince(now)
                    triggerDate = Date(timeInterval: 0.5 * remainingTime, since: now)
                    break
                }
            }
            
            guard let time = triggerDate?.timeIntervalSince(now), time > 0 else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: time, repeats: false)
            
            // Create and add request
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
            try await center.add(request)
            
            Logger.notifications.info("Scheduled renew reminder for provider \(providerId) profile \(profileId) valid until \(validUntil) on \(triggerDate!)")
        },
        delegate: {
            AsyncStream { continuation in
                let delegate = Delegate(continuation: continuation)
                UNUserNotificationCenter.current().delegate = delegate
                continuation.onTermination = { [delegate] _ in
                    // We need to use the delegate in some way or the compiler won't keep it alive
                    Logger.notifications.debug("continuation.onTermination with \(delegate)")
                }
            }
        })
}

extension NotificationClient {
    fileprivate class Delegate: NSObject, UNUserNotificationCenterDelegate {
        let continuation: AsyncStream<NotificationClient.DelegateEvent>.Continuation
        
        init(continuation: AsyncStream<NotificationClient.DelegateEvent>.Continuation) {
            self.continuation = continuation
            Logger.notifications.debug("NotificationClient.Delegate init")
        }
        
        deinit {
            Logger.notifications.debug("NotificationClient.Delegate deinit")
        }
        
        @MainActor
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard response.notification.request.content.categoryIdentifier == .renewCategoryId else { return }
            let userInfo = response.notification.request.content.userInfo
            guard let providerId = userInfo[String.providerIdKey] as? String, let profileId = userInfo[String.profileIdKey] as? String, let validUntil = userInfo[String.validUntilKey] as? Date else { return }
            
            switch response.actionIdentifier {
            case .renewNowActionId:
                Logger.notifications.info("Renew now for provider \(providerId) profile \(profileId)")
                continuation.yield(.renewActionTriggered(providerId: providerId, profileId: profileId))
                
            case .remindMeActionId:
                Logger.notifications.info("Remind me later for provider \(providerId) profile \(profileId) valid until \(validUntil)")
                continuation.yield(.remindMeLaterActionTriggered(validUntil: validUntil, providerId: providerId, profileId: profileId))
                
            default:
                break
            }
        }
    }
}
