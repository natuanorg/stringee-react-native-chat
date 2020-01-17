
# stringee-react-native-chat

## Getting started

`$ npm install stringee-react-native-chat --save`

## Version 0.1.9
- Bug fixes: call two functions in the same block code(iOS)

## Version 0.1.8
- Bug fixes: conversation's localId missing, duplicate events.

## Version 0.1.7
- Add more last message informations to conversation.
- Fix bug events are repeated, getConversationInfo, markMessage on iOS.

## Version 0.1.6
- Fix bug can not receive chat's events after click back button on android.

## Version 0.1.5
- Catch null exception for call(iOS).

## Version 0.1.4
- Fix bug xcode build.

## Version 0.1.3
- Send messages automatically.
- Fix bug ObjectChange event is repeated.
- Fix bug markConversationAsRead function.

### Installation

#### iOS

**Note** Please make sure to have [CocoaPods](https://cocoapods.org/) on your computer.
1. In you terminal, change into your `ios` directory.

2. Create a pod file by running: `pod init`.

3. Add the following to your pod file:

```
    platform :ios, '8.0'

    target '<YourProjectName>' do
  		node_modules_path = '../node_modules'

  		pod 'yoga', path: "#{node_modules_path}/react-native/ReactCommon/yoga/yoga.podspec"
  		pod 'React', path: "#{node_modules_path}/react-native", :subspecs => ['DevSupport', 'RCTNetwork']

  		pod 'RNStringee', path: "#{node_modules_path}/stringee-react-native-chat/ios"
    end

    post_install do |installer|
      installer.pods_project.targets.each do |target|
        if target.name == "React"
          target.remove_from_project
        end
      end
    end

```

4. Now run, `pod install`

5. Open XCode

6. Open `<YourProjectName>.xcworkspace` file in XCode. This file can be found in the `ios` folder of your React Native project. 

7. In the "Build Settings" tab -> "Other linker flags" add "$(inherited)" flag.

8. In the "Build Settings" tab -> "Enable bitcode" select "NO".

9. Right-click the information property list file (Info.plist) and select Open As -> Source Code.

10. Insert the following XML snippet into the body of your file just before the final element:

```
  <key>NSCameraUsageDescription</key>
  <string>$(PRODUCT_NAME) uses Camera</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>$(PRODUCT_NAME) uses Microphone</string>
```

#### Android

##### Manual installation

1. Open up `android/app/src/main/java/[...]/MainApplication.java`
  - Add `import com.stringeereactnative.RNStringeeReactPackage;` to the imports at the top of the file
  - Add `new RNStringeePackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':stringee-react-native-chat'
	project(':stringee-react-native-chat').projectDir = new File(rootProject.projectDir, '../node_modules/stringee-react-native-chat/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':stringee-react-native-chat')
  	```

  