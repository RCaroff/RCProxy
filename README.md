<div align="center">
  <h1>▶︎ RCProxy</h1>
  <h3>A lightweight inapp HTTP requests logger for your iOS and tvOS apps.</h3>
</div>

+ Simply log requests in your app with 2 lines of code.
+ Magnified JSON view.
+ cURL sharing.
+ JSON file sharing.
+ Copy a single row on long press.
+ Watch the requests live on your Mac with RCProxy Desktop. No proxy, no Wi-Fi setup: perfect for Apple TV.

<div align="center">
  <img src="https://github.com/user-attachments/assets/4f473b6c-cc93-4aaa-a50b-9cca4fb34b9f" alt="iPhone 15 Pro Screenshot" width="187" style="display: inline-block;"/>
  <img src="https://github.com/user-attachments/assets/29b548ec-75bc-454a-9896-c6fa68bdf6c4" alt="Apple TV Screenshot" width="720" style="display: inline-block;"/>
</div>

## ▼ Requirements
+ iOS 17 / tvOS 17
+ Xcode 16 or later

## ▼ Installation
RCProxy is distributed with Swift Package Manager:

1. In Xcode, go to File -> Add packages...
2. In the prompt's search bar, copy and paste this URL: `https://github.com/RCaroff/RCProxy.git`
3. Select RCProxy and click on `Add Package`

Or in a `Package.swift`:

```
.package(url: "https://github.com/RCaroff/RCProxy.git", from: "4.0.0")
```

## ▼ How to use it
+ `import RCProxy`
+ When you want to start logging, just write 
```
RCProxy.start()
```
+ When you want to show the interface, just use 
```
RCProxy.show(in: UIViewController)
```
+ If you want to present the viewController in a different way, you can simply get the instance with `RCProxy.viewController`.
+ From SwiftUI view, use `RCProxy.view`:
```
@State var showRequests: Bool = false

var body: some View {
    Button {
        showRequests = true
    } label: {
        Text("Show requests")
    }
    .sheet(isPresented: $showRequests) {
        RCProxy.view
    }
}
```
+ Choose the type of storage you want between `.session()`, `.userDefaults()` and `.database()`<br><br>Example: 
```
RCProxy.start(storageType: .database(maxRequestsCount: 50))
```
<br>Default value is `.session(maxRequestsCount: 100)`.<br><br>`session(maxRequestsCount: //default: 100)`: Your requests will be stored in a singleton and will be cleared when app is terminated.<br><br>`userDefaults(maxRequestsCount: //default: 100)`: Your requests will be stored in `UserDefaults.standard` instance, and will persist between sessions but it will allow only a limited amount of data.<br><br>`.database(maxRequestsCount: //default: 100)`: Your requests will be stored in a sqlite file on the phone. It uses SwiftData behind the hood.

+ RCProxy is listening on `URLSession.shared` instance by default, but you can also inject your own custom.<br>
To do so, use one of the two RCProxy URLSessionConfiguration object to initialize your session, and pass your URLSession object in start() method:

```
let session = URLSession(configuration: RCProxy.defaultConfiguration) // or RCProxy.ephemeralConfiguration
RCProxy.start(with: session)
```


## ▼ RCProxy Desktop
RCProxy Desktop is the macOS companion of RCProxy. It displays the requests of your app in real time, with a desktop UI: sortable table, filters, collapsible JSON tree, cURL export.<br>
The app and the Mac talk to each other with MultipeerConnectivity (Wi-Fi, Bluetooth or Ethernet): there is nothing to configure on the device, and no code to add to your app.

1. Declare the Bonjour services of RCProxy in the `Info.plist` of your app (once):
```
<key>NSBonjourServices</key>
<array>
    <string>_rcproxy._tcp</string>
    <string>_rcproxy._udp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>Sends the network requests of the app to RCProxy Desktop.</string>
```
2. In your app, open RCProxy and turn on the `RCProxy Desktop` toggle, above the requests.
3. Open RCProxy Desktop on your Mac: the app shows up in the sidebar. Click on `Connect`.
4. The app asks whether this Mac may receive its requests, and shows the same code as RCProxy Desktop. Choose `Always Allow` and the Mac reconnects by itself the next times.

The requests already recorded are sent on connection, then every new request is sent as it happens.

+ RCProxy Desktop can only see and connect to the app while the toggle is on. Turn it off and the app is invisible again.
+ The toggle is remembered: once on, streaming resumes by itself at the next launches, as soon as RCProxy records a request. The requests made at launch show up on the Mac too.
+ Requests may hold tokens and personal data: each Mac has to be allowed once on the device.
+ Under the toggle, RCProxy tells whether a Mac is receiving the requests, or what is missing.

## ▼ Upgrading from 3.x
+ iOS 17 / tvOS 17 are now required.
+ CocoaPods is not supported anymore: use Swift Package Manager.
+ `.database()` now relies on SwiftData. The requests stored by a previous version are not kept.
+ `RCProxy.view`, `RCProxy.viewController` and `RCProxy.show(in:)` must be called from the main actor (it was already the case in practice).

## ▼ Development
The tests run on a simulator:

```
xcodebuild test -scheme RCProxy-Package -destination 'platform=iOS Simulator,name=iPhone 17'
```

The example app (`RCProxy-example`) also has UI tests, including the focus navigation on tvOS:

```
xcodebuild test -project RCProxy-example.xcodeproj -scheme RCProxy-example -destination 'platform=tvOS Simulator,name=Apple TV'
```

Feel free to contribute and / or open issues!
