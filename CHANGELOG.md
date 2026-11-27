# Changelog

## 4.1.0

### Added
+ **Requests run by RCProxy Desktop**: when the Mac asks for it, the app hands every intercepted request over to RCProxy Desktop, which performs it and sends the response back. This is what lets RCProxy Desktop mock requests and responses, with nothing to configure in the app. The status under the toggle tells when the Mac runs the requests.
+ The app takes its requests back by itself: when no Mac asked for them, when the Mac disconnects (pending requests included), or when it stops answering.
+ The first requests of the app are run by the Mac too: when a Mac ran the requests the last time, the requests made at launch (or when the app comes back to the foreground) wait for it to reconnect, which usually takes a second or two. If the Mac does not show up within 5 seconds, the app performs them itself, and stops waiting at the next launches until a Mac runs its requests again.
+ Cookies, `User-Agent` and `Accept-Language` are sent as the app would have sent them, and the cookies set by the responses are stored in the app.

### Notes
+ Viewers that only watch (RCProxy Desktop 1.0, the RCProxy tab of other tools) keep working as before: the app performs its requests itself.
+ A request performed by the Mac leaves from the Mac: its network (VPN, proxy, IP address) applies, not the one of the device.

## 4.0.0

### Added
+ **RCProxy Desktop**: a toggle in the requests list streams the requests in real time to the macOS app, over MultipeerConnectivity. No code to add: `RCProxy.start()` is unchanged. The user accepts each Mac (with a pairing code), and can trust it for the next times. The toggle is remembered across launches.
+ New `RCProxyCore` product: the request model and the link shared with RCProxy Desktop.
+ Failed requests keep their error, and requests keep their duration.
+ `RCProxy.version`.

### Changed
+ `.database()` storage now uses **SwiftData** instead of Core Data. The previous database is removed.
+ iOS 17 / tvOS 17 are required. The package is built with the Swift 6 language mode.
+ Only `http` and `https` requests are intercepted.
+ `RCProxy.view`, `RCProxy.viewController` and `RCProxy.show(in:)` are isolated to the main actor.

### Fixed
+ tvOS: the query parameters of the request details can take the focus. With many parameters, the focus used to jump to the request headers while they were off screen, and the parameters could not be scrolled.
+ Crashes:
  + the storages were accessed from several threads at once (session and UserDefaults storages were not synchronized, the Core Data context was used outside of its queue);
  + the Core Data storage called `fatalError` when its model could not be loaded. The SwiftData storage falls back to memory when the database is unusable;
  + truncated or malformed JSON bodies crashed the parser (index out of range), as did numbers that do not fit in an `Int`;
  + reading a request body stream that failed crashed (negative length);
  + the URL loading system was called after a request was cancelled, and was told that failed requests finished successfully;
  + on tvOS, `.userDefaults()` could exceed the 1 MB limit of `UserDefaults`, which terminates the app. The persisted requests now stay under a size budget.
+ The request body was read twice from its stream (once for cURL, once for display): it is now read once and handed to the request actually sent.
+ cURL: values holding single quotes are escaped, non-JSON bodies are included, headers are sorted.
+ URLs keep their port in the requests list.
+ JSON with Windows line endings is parsed.

### Removed
+ CocoaPods support (`RCProxy.podspec`).
