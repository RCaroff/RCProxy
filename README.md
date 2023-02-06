# ⬆️ RCProxy ⬇️
A lightweight inapp HTTP requests logger for your iOS and tvOS apps.

+ Simply log requests in your app with 2 lines of code.
+ Magnified JSON view.
+ cURL sharing.
+ JSON file sharing.
+ Copy a single row on long press.

![Simulator Screen Shot - iPhone 14 Pro - 2023-02-06 at 02 11 21](https://user-images.githubusercontent.com/6641303/216860620-cf7852b2-cd1f-4e84-80c0-d4f47fb43755.png)
![Simulator Screen Shot - iPhone 14 Pro - 2023-02-06 at 02 11 31](https://user-images.githubusercontent.com/6641303/216860616-36c8e1f3-ea83-4733-b281-2703664dd8b8.png)
![Simulator Screen Shot - iPhone 14 Pro - 2023-02-06 at 02 20 19](https://user-images.githubusercontent.com/6641303/216860617-8b09d9de-ca0c-4bf1-ab97-9e479646b8a9.png)
![Simulator Screen Shot - Apple TV - 2023-02-06 at 02 51 06](https://user-images.githubusercontent.com/6641303/216863989-b1abbc20-0288-4c93-8b09-d1d85055e126.png)


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
+ Choose the type of storage you want between `.session` and `.userDefaults`.<br>Example: 
```
RCProxy.storageType = .session
```
<br>Default value is `.userDefaults`.<br><br>`session`: Your requests will be stored in a singleton and will be cleared when app is terminated.<br>`userDefaults`: Your requests will be stored in `UserDefaults.standard` instance, and will persist even if your app crashes. This is why it's the default value.

Feel free to contribute and / or open issues!
