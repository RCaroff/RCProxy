# ⬆️ RCProxy ⬇️
A lightweight inapp HTTP requests logger for your iOS and tvOS apps.

+ Simply log requests in your app with 2 lines of code.
+ Magnified JSON view.
+ cURL sharing.
+ JSON file sharing.
+ Copy a single row on long press.

![Simulator Screen Recording - iPhone 14 Pro - 2023-02-14 at 02 54 19](https://user-images.githubusercontent.com/6641303/218618660-74f58036-d0f5-4000-b630-2e08e7a131bd.gif)

Works on tvOS too!<br>
![Simulator Screen Recording - Apple TV - 2023-02-14 at 03 00 43](https://user-images.githubusercontent.com/6641303/218619269-8f2c4c67-6de8-45f2-a225-7ea708f8116c.gif)



## ▶︎ Installation
Use SPM:

1. In Xcode, go to File -> Add packages...
2. In the prompt's search bar, copy and paste this URL: `https://github.com/RCaroff/RCProxy.git`
3. Select RCProxy an click on `Add Package`

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
+ Choose the type of storage you want between `.session`, `.userDefaults` and `.database`<br>Be sure to setup this **BEFORE** calling `RCProxy.start()`.<br>Example: 
```
RCProxy.storageType = .database
RCProxy.start()
```
<br>Default value is `.session`.<br><br>`session`: Your requests will be stored in a singleton and will be cleared when app is terminated.<br>`userDefaults`: Your requests will be stored in `UserDefaults.standard` instance, and will persist between sessions but it will allow only a limited amount of data.<br>`.database`: Your requests will be stored in a sqlite file on the phone. It uses CoreData behind the hood.

Feel free to contribute and / or open issues!
