# geteduroam for Apple devices

## What is it?

This is the [geteduroam](https://geteduroam.app/) app for iPhone, iPad and Mac. Its purpose is to help people configure their devices for use with the [eduroam](https://eduroam.org) network. The eduroam network allows them use the network at their organization of education or when visiting other participating organizations.

This is the code for version 2.0 and newer.

## Minimum Requirements

| Device          | Requirement         |
| ----------------|---------------------|
| iPhone and iPad | iOS 15.0 or newer   |
| Mac             | macOS 12.0 or newer |

## FAQ

Q: ?
A: !

## License

See [license](LICENSE.md).

## Building

Open geteduroam.xcodeproj in a current version of Xcode (at least 14.3) and select the app target and the run destination.

## Technical Design

The app is designed using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA) with SwiftUI. It uses modules its various features. The app itself only contains a minimal amount of code as well as some theming.

The modules are all defined in the GeteduroamPackage package.

### AuthClient

Minimal wrapper around the [AppAuth](https://github.com/openid/AppAuth-iOS.git) library for authenticating with organizations that require OAuth for authentication.

### Backport

Sometimes features in SwiftUI aren't available on all supported os versions. This module contains fallbacks so we can use them anyway.

### CacheClient

Stores the responses from the discovery client to disk and helps to ensure there is always a list of organizations to show.

### Connect

The detail screen with profile selection, helpdesk info and connect functionality. Also collects credentials and agreements to terms of use as needed.

### DiscoveryClient

Retreives the list of organizations from the backend.

### EAPConfigurator

Configures the network on iOS and iPadOS.

### Main

The main screen with the search functionality.

### Models

Models used troughout the app.

### NotificationClient

Schedules reminders for when network configurations expire.
