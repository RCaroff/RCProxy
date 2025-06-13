<div align="center">
  <h1>▶︎{ RCProxy</h1>
  <h3>A lightweight inapp HTTP requests logger for your iOS and tvOS apps.</h3>
</div>

+ Simply log requests in your app with 2 lines of code.
+ Magnified JSON view.
+ cURL sharing.
+ JSON file sharing.
+ Copy a single row on long press.

<div align="center">
  <img src="https://github.com/user-attachments/assets/4f473b6c-cc93-4aaa-a50b-9cca4fb34b9f" alt="iPhone 15 Pro Screenshot" width="187" style="display: inline-block;"/>
  <img src="https://github.com/user-attachments/assets/29b548ec-75bc-454a-9896-c6fa68bdf6c4" alt="Apple TV Screenshot" width="720" style="display: inline-block;"/>
</div>

## ▼ Installation
Use Cocoapods:

```
pod 'RCProxy'
```

Use SPM:

1. In Xcode, go to File -> Add packages...
2. In the prompt's search bar, copy and paste this URL: `https://github.com/RCaroff/RCProxy.git`
3. Select RCProxy and click on `Add Package`

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
<br>Default value is `.session(maxRequestsCount: 100)`.<br><br>`session(maxRequestsCount: //default: 100)`: Your requests will be stored in a singleton and will be cleared when app is terminated.<br><br>`userDefaults(maxRequestsCount: //default: 100)`: Your requests will be stored in `UserDefaults.standard` instance, and will persist between sessions but it will allow only a limited amount of data.<br><br>`.database(maxRequestsCount: //default: 100)`: Your requests will be stored in a sqlite file on the phone. It uses CoreData behind the hood.

+ RCProxy is listening on `URLSession.shared` instance by default, but you can also inject your own custom.<br>
To do so, use one of the two RCProxy URLSessionConfiguration object to initialize your session, and pass your URLSession object in start() method:

```
let session = URLSession(configuration: RCProxy.defaultConfiguration) // or RCProxy.ephemeralConfiguration
RCProxy.start(with: session)
```


Feel free to contribute and / or open issues!
