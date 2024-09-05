import Dependencies
import DependenciesMacros
import Foundation
import OSLog
import UserNotifications

extension String {
    public static let willExpireCategoryId = "WILL_EXPIRE_CATEGORY"
    public static let hasExpiredCategoryId = "HAS_EXPIRED_CATEGORY"
    public static let renewNowActionId = "RENEW_NOW_ACTION"
    public static let remindMeActionId = "REMIND_ME_ACTION"
    public static let organizationIdKey = "ORGANIZATION_ID"
    public static let organizationURLKey = "ORGANIZATION_URL"
    public static let profileIdKey = "PROFILE_ID"
    public static let validUntilKey = "VALID_UNTIL"
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

extension NotificationClient: TestDependencyKey {
    public static let testValue = Self()
}

@DependencyClient
public struct NotificationClient {
    public var scheduleRenewReminder: (_ validUntil: Date, _ organizationId: String, _ organizationURLString: String?, _ profileId: String) async throws -> Void
    public var unscheduleRenewReminder: () -> Void
    public var scheduledRenewReminder: () async -> ((validUntil: Date, organizationId: String, organizationURLString: String?, profileId: String)?) = { nil }
    public var delegate: @Sendable () -> AsyncStream<DelegateEvent> = { .never }
    
    public enum DelegateEvent: Equatable {
        case renewActionTriggered(organizationId: String, organizationURLString: String?, profileId: String)
        case remindMeLaterActionTriggered(validUntil: Date, organizationId: String, organizationURLString: String?, profileId: String)
    }
}

extension Logger {
    public static var notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NotificationClient", category: "notifications")
}

extension NotificationClient: DependencyKey {
    public static let liveValue = Self(
        scheduleRenewReminder: { validUntil, organizationId, organizationURLString, profileId in
            Logger.notifications.info("Try to schedule renew reminder for organization \(organizationId) profile \(profileId) valid until \(validUntil)")
            
            @Dependency(\.calendar) var calendar
            @Dependency(\.date.now) var now
            
            let center = UNUserNotificationCenter.current()
            
            // Check if user has granted permission
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
            guard granted else { return }
            
            // Declare custom actions: Renew Now | Remind Me Later
            let renewNowAction = UNNotificationAction(identifier: .renewNowActionId, title: NSLocalizedString("Renew Now", bundle: .module, comment: "Renew Now"), options: [.authenticationRequired, .foreground], icon: UNNotificationActionIcon(systemImageName: "arrow.triangle.2.circlepath"))
            let remindMeAction = UNNotificationAction(identifier: .remindMeActionId, title: NSLocalizedString("Remind Me Later", bundle: .module, comment: "Remind Me Later"), options: [], icon: UNNotificationActionIcon(systemImageName: "alarm"))
            
            let willExpireCategory = UNNotificationCategory(identifier: .willExpireCategoryId, actions: [renewNowAction, remindMeAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: NSLocalizedString("Renew your connection to extend your access.", bundle: .module, comment: "Renew your connection to extend your access."), categorySummaryFormat: nil, options: [.hiddenPreviewsShowTitle])
            let hasExpiredCategory = UNNotificationCategory(identifier: .hasExpiredCategoryId, actions: [renewNowAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: NSLocalizedString("Renew your connection to extend your access.", bundle: .module, comment: "Renew your connection to extend your access."), categorySummaryFormat: nil, options: [.hiddenPreviewsShowTitle])
            center.setNotificationCategories([willExpireCategory, hasExpiredCategory])
            
            // Cancel any pending or delivered reminders
            center.removeDeliveredNotifications(withIdentifiers: [.willExpireCategoryId, .hasExpiredCategoryId])
            center.removePendingNotificationRequests(withIdentifiers: [.willExpireCategoryId, .hasExpiredCategoryId])
            
            // Check notification settings
            let settings = await center.notificationSettings()
            
            // Create notification content
            let userInfo: [String: Any] = [.organizationIdKey: organizationId, .organizationURLKey: organizationURLString ?? "", .profileIdKey: profileId, .validUntilKey: validUntil]
            
            let willExpireContent = UNMutableNotificationContent()
            willExpireContent.title = NSLocalizedString("Your network access is about to expire", bundle: .module, comment: "Your network access is about to expire")
            willExpireContent.body = String(format: NSLocalizedString("You have access until %@. Renew your connection to extend your access.", bundle: .module, comment: "You have access until <date>. Renew your connection to extend your access."), DateFormatter.localizedString(from: validUntil, dateStyle: .medium, timeStyle: .short))
            willExpireContent.userInfo = userInfo
            willExpireContent.categoryIdentifier = .willExpireCategoryId
            willExpireContent.sound = .default
            willExpireContent.interruptionLevel = .passive
            
            let hasExpiredContent = UNMutableNotificationContent()
            hasExpiredContent.title = NSLocalizedString("Your network access has expired", bundle: .module, comment: "Your network access has expired")
            hasExpiredContent.body = String(format: NSLocalizedString("You had access until %@. Renew your connection to extend your access.", bundle: .module, comment: "You had access until <date>. Renew your connection to extend your access."), DateFormatter.localizedString(from: validUntil, dateStyle: .medium, timeStyle: .short))
            hasExpiredContent.userInfo = userInfo
            hasExpiredContent.categoryIdentifier = .hasExpiredCategoryId
            hasExpiredContent.sound = .default
            hasExpiredContent.interruptionLevel = .active
            
            // Specify delivery
            
            // validUntil date must be in the future
            let secondsUntilExpiration = validUntil.timeIntervalSince(now)
            guard secondsUntilExpiration > 0 else {
                assertionFailure("NotificationClient was asked to send reminder in the past")
                return
            }
            
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
            
            let willExpireTrigger: UNTimeIntervalNotificationTrigger?
            if let timeUntilReminder = triggerDate?.timeIntervalSince(now), timeUntilReminder > 0 {
                willExpireTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilReminder, repeats: false)
            } else {
                willExpireTrigger = nil
            }
            
            let timeUntilExpiration = validUntil.timeIntervalSince(now)
            let hasExpiredTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilExpiration, repeats: false)
          
            // Create and add requests
            if let willExpireTrigger {
                let willExpireRequest = UNNotificationRequest(identifier: .willExpireCategoryId, content: willExpireContent, trigger: willExpireTrigger)
                try await center.add(willExpireRequest)
                Logger.notifications.info("Scheduled renew reminder for organization \(organizationId) profile \(profileId) valid until \(validUntil) on \(triggerDate!)")
            }
            
            let hasExpiredRequest = UNNotificationRequest(identifier: .hasExpiredCategoryId, content: hasExpiredContent, trigger: hasExpiredTrigger)
            try await center.add(hasExpiredRequest)
            Logger.notifications.info("Scheduled expiration notification for organization \(organizationId) profile \(profileId) on \(validUntil)")
        },
        unscheduleRenewReminder: {
            let center = UNUserNotificationCenter.current()
            
            // Cancel any pending or delivered reminders
            center.removeDeliveredNotifications(withIdentifiers: [.willExpireCategoryId, .hasExpiredCategoryId])
            center.removePendingNotificationRequests(withIdentifiers: [.willExpireCategoryId, .hasExpiredCategoryId])
        },
        scheduledRenewReminder: {
            Logger.notifications.info("Try to see if a renew reminder was scheduled")
            
            guard
                let userInfo = await  UNUserNotificationCenter.current()
                    .pendingNotificationRequests()
                    .first(where: { [.willExpireCategoryId, .hasExpiredCategoryId].contains($0.identifier) })?
                    .content.userInfo as? [String: Any],
                let validUntil = userInfo[.validUntilKey] as? Date,
                let organizationId = userInfo[.organizationIdKey] as? String,
                let profileId = userInfo[.profileIdKey] as? String else {
               return nil
            }
            let organizationURLString: String?
            if let organizationURL = userInfo[.organizationURLKey] as? String, !organizationURL.isEmpty {
                organizationURLString = organizationURL
            } else {
                organizationURLString = nil
            }
            return (validUntil, organizationId, organizationURLString, profileId)
        },
        delegate: {
            AsyncStream { continuation in
                let delegate = Delegate(continuation: continuation)
                UNUserNotificationCenter.current().delegate = delegate
                continuation.onTermination = { _ in
                    // We need to use the delegate in some way or the compiler won't keep it alive
                    _ = delegate
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
        
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            // Also show the notification when in foreground
            Logger.notifications.info("Will present \(notification)")
            return [.banner, .list, .sound]
        }
        
        @MainActor
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard [.willExpireCategoryId, .hasExpiredCategoryId].contains(response.notification.request.content.categoryIdentifier) else { return }
           
            center.removeDeliveredNotifications(withIdentifiers: [.willExpireCategoryId, .hasExpiredCategoryId])
            Logger.notifications.info("Removed delivered notifications")
            
            let userInfo = response.notification.request.content.userInfo
            guard let organizationId = userInfo[String.organizationIdKey] as? String, let profileId = userInfo[String.profileIdKey] as? String, let validUntil = userInfo[String.validUntilKey] as? Date else { return }

            let organizationURLString: String?
            if let organizationURL = userInfo[String.organizationURLKey] as? String, !organizationURL.isEmpty {
                organizationURLString = organizationURL
            } else {
                organizationURLString = nil
            }
            
            switch response.actionIdentifier {
            case .renewNowActionId:
                Logger.notifications.info("Renew now for organization \(organizationId) url \(organizationURLString ?? "N/A") profile \(profileId)")
                continuation.yield(.renewActionTriggered(organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId))

            case .remindMeActionId:
                Logger.notifications.info("Remind me later for organization \(organizationId) url \(organizationURLString ?? "N/A") profile \(profileId) valid until \(validUntil)")
                continuation.yield(.remindMeLaterActionTriggered(validUntil: validUntil, organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId))

            default:
                Logger.notifications.info("Renew now for organization \(organizationId) url \(organizationURLString ?? "N/A") profile \(profileId)")
                continuation.yield(.renewActionTriggered(organizationId: organizationId, organizationURLString: organizationURLString, profileId: profileId))
            }
        }
    }
}
