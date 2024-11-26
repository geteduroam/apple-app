# geteduroam for Apple devices

## What is it?

These are the [geteduroam](https://geteduroam.app/) and getgovroam apps for iPhone, iPad and Mac. Their purposes are to help people configure their devices for use with the [eduroam](https://eduroam.org) and [govroam](https://govroam.nl) networks. The eduroam and govroam networks allows them use the network at their organization of education or government or when visiting other participating organizations.

This is the code for version 2.0 and newer.

## Minimum Requirements

| Device          | Requirement         |
| ----------------|---------------------|
| iPhone and iPad | iOS 15.0 or newer   |
| Mac             | macOS 12.0 or newer |

## FAQ

Q: How to update the included discovery fallback files?
A: Run these commands:

    curl --silent --compressed 'https://discovery.eduroam.app/v3/discovery.json' > geteduroam/discovery.json
    curl --silent --compressed 'https://getgovroam.nl/v2/discovery.json' > getgovroam/discovery.json

    care prepare Config/appconfig.yaml geteduroam/appconfig.json
    care prepare Config/appconfig.yaml getgovroam/appconfig.json
    
## License

See [license](LICENSE.md).

## Building

Open geteduroam.xcodeproj in a current version of Xcode (at least 14.3) and select the app target and the run destination.

## Technical Design

The app is designed using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA) with SwiftUI. It uses modules to implement its various features. The app itself only contains a minimal amount of code as well as some theming.

The modules are all defined in the GeteduroamPackage package.

### AuthClient

Minimal wrapper around the [AppAuth](https://github.com/openid/AppAuth-iOS.git) library for authenticating with organizations that require OAuth for authentication.

### Backport

Sometimes features in SwiftUI aren't available on all supported os versions. This module contains fallbacks so we can use them anyway.

### CacheClient

Stores the responses from the discovery client to disk and helps to ensure there is always a list of organizations to show.

### Connect

The detail screen with profile selection, helpdesk info and (re)connect functionality. Also collects credentials and agreements to terms of use as needed.

### DiscoveryClient

Retrieves the list of organizations from the backend.

### EAPConfigurator

Configures the network on iOS and iPadOS.

### Main

The main screen with the search functionality.

### Models

Models used throughout the app.

### NotificationClient

Schedules reminders for when network configurations expire.

## Creating screenshots

To facilitate creating screenshots for the App Store, use these steps:

1. In MainView.swift: comment out sending the `searchQueryChangeDebounced` action
2. In Screenshots.swift: verify `screenshotsFolder` goes to an existing folder
3. Select the `geteduroam/getgovroam Screenshots` target
4. Select the desired destination
5. Use Product > Test (cmd-U)

If the tests hang, try running the app on that particular simulator first. Check that the simulator is in the desired orientation: portrait for this app.

Refer to the [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications) to pick the desired destinations.

Currently we use:

- iPhone 15 Pro Max
- iPhone 8 Plus
- iPad Pro (12.9-inch) (6th generation) 
- iPad Pro (12.9-inch) (2nd generation) 
- Mac with 1280 x 800 pixels

Currently we don't use:
- iPhone 15: generates screenshots with size 1178 x 2556, but App Store wants 1179 x 2556

## Localizations

In Xcode use Product > Export Localizations > geteduroam… and pick a location to store the output. This creates a folder with a package for each currently supported language with the extension xcloc. This package can be opened by Xcode to edit the translations. Alternatively, in the Finder control click on the xcloc package and use Show Package Contents to find amongst others an xliff file, which is an industry standard for localizing apps.

> [!Important]
> In the xliff file you must replace all occurrences of `state="new"` with `state="translated"` or Xcode won't actually import them.

Note, temporarily add the AppStore.xcstrings files to their targets so that they get included in the xcloc package. They shouldn't ship with the app though. These are just to collect the translations for the App Store.

### Adding a new language

In Xcode use these steps:

1. Select the project geteduroam
2. Select the Info tab
3. Find the Localizations section
4. Add the language with the + button
5. Use the menu Product > Export Localizations > geteduroam… and pick a location to store the output
