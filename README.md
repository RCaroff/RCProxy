# ⬆️ RCProxy ⬇️
A lightweight inapp HTTP requests logger for your iOS and tvOS apps.

+ Simply log requests in your app with 2 lines of code.
+ Magnified JSON view.
+ cURL sharing.
+ JSON file sharing.
+ Copy a single row on long press.

## ▶︎ Installation
Use SPM.

## ▼ How to use it
+ `import RCProxy`
+ In AppDelegate, just write `RCProxy.start()`.
+ When you want to show the interface, just use `RCProxy.show(in: UIViewController)`
+ If you want to present the viewController in a different way, you can simply get the instance with `RCProxy.viewController`.
+ Choose the type of storage you want between `.session` and `.userDefaults`.<br>Example: `RCProxy.storageType = .session`.<br>Default value is `.userDefaults`.<br><br>`session`: Your requests will be stored in a singleton and will be cleared when app is terminated.<br>`userDefaults`: Your requests will be stored in `UserDefaults.standard` instance, and will persist even if your app crashes. This is why it's the default value.

Feel free to contribute and / or open issues!
