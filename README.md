# Approov Quickstart: Ionic Capacitor (Angular, Vue, React)

This quickstart is written specifically for Android and iOS apps that are implemented in [Ionic Capacitor](https://capacitorjs.com/) using the [`Cordova Advanced HTTP networking plugin`](https://www.npmjs.com/package/cordova-plugin-advanced-http), accessed via the [`HTTP plugin`](https://ionicframework.com/docs/native/http). If this is not your situation then check if there is a more relevant Quickstart guide available.

This quickstart provides the basic steps for integrating Approov into your app. A more detailed step-by-step guide using a [Shapes App Example](https://github.com/approov/quickstart-ionic-advancedhttp/blob/main/SHAPES-EXAMPLE.md) is also available.

Note that for Android the minimum supported version is 5.1 (SDK level 22). For iOS, only 64-bit devices are supported on iOS 10 or above.

To follow this guide you should have received an onboarding email for a trial or paid Approov account.

## ADDING THE APPROOV PLUGIN

It is assumed that your starting point is an app that already uses the [`Cordova Advanced HTTP networking plugin`](https://www.npmjs.com/package/cordova-plugin-advanced-http) plugin and the [`@awesome-cordova-plugins`](https://github.com/danielsogl/awesome-cordova-plugins) wrapper (previously called `@ionic-native`) so that it can be used in an Ionic app. You must first remove these from your project as follows:

```
npm uninstall @awesome-cordova-plugins/http 
npm uninstall cordova-plugin-advanced-http
```

It is not possible to have this plugin in your project at the same time as the Approov enabled one. However, you can control which domains are protected using Approov via its configuration.

Next add the Approov capable version of the advanced HTTP plugin and its `@awesome-cordova-plugins` wrapper:

```
npm install @approov/cordova-plugin-advanced-http
npm install @awesome-cordova-plugins/approov-advanced-http
```

This installs the Approov capable plugin from [npm](https://www.npmjs.com/). The plugin provides exactly the same interface but with some additional methods to control the Approov integration. Thus there is no need to change the API requests in your app. If Approov is not initialized then these are performed as normal without attempting to add any Approov capabilities.

Note that for Android the minimum SDK version you can use is 21 (Android 5.0). Please [read this](https://approov.io/docs/latest/approov-usage-documentation/#targeting-android-11-and-above) section of the reference documentation if targeting Android 11 (API level 30) or above.

## INITIALIZING THE APPROOV PLUGIN

Approov must be initialized in order to add Approov protection automatically to network requests and to also apply pinning. This initialization must be done prior to any network requests that you wish to protect.  The `<enter-your-config-string-here>` in the examples below is a custom string that configures your Approov account access. This will have been provided in your Approov onboarding email.

## Angular

In order to use Approov you should include the wrapped plugin as follows:

```Typescript
import { HTTP } from '@awesome-cordova-plugins/approov-advanced-http/ngx';
```

You must initialize the plugin in the main app component as follows:

```Typescript
export class AppComponent implements OnInit {
  ngOnInit(): void {
    HTTP.approovInitialize("<enter-your-config-string-here>");
  }
}
```

### React

In order to use Approov you should include the wrapped plugin as follows:

```Typescript
import { HTTP } from '@awesome-cordova-plugins/approov-advanced-http';
```

You must initialize the plugin in the main app component as follows:

```Typescript
export class App extends Component<any, AppState> {
  constructor(props: any) {
    super(props);
    HTTP.approovInitialize("<enter-your-config-string-here>");
  }
}
```

### Vue

In order to use Approov you should include the wrapped plugin as follows:

```Typescript
import { HTTP } from '@awesome-cordova-plugins/approov-advanced-http';
```

You must initialize the plugin in the main app component as follows:

```Typescript
export default defineComponent({
  created() {
      HTTP.approovInitialize("<enter-your-config-string-here>");
  }
})
```

## CHECKING IT WORKS
Once the initialization is called, it is possible for any network requests to have Approov tokens or secret substitutions made. Initially you won't have set which API domains to protect, so the requests will be unchanged. It will have called Approov though and made contact with the Approov cloud service. You will see `ApproovService` logging indicating `UNKNOWN_URL` (Android) or `unknown URL` (iOS).

On Android, you can see logging using [`logcat`](https://developer.android.com/studio/command-line/logcat) output from the device. You can see the specific Approov output using `adb logcat | grep ApproovService`. On iOS, look at the console output from the device using the [Console](https://support.apple.com/en-gb/guide/console/welcome/mac) app from MacOS. This provides console output for a connected simulator or physical device. Select the device and search for `ApproovService` to obtain specific logging related to Approov.

Your Approov onboarding email should contain a link allowing you to access [Live Metrics Graphs](https://approov.io/docs/latest/approov-usage-documentation/#metrics-graphs). After you've run your app with Approov integration you should be able to see the results in the live metrics within a minute or so. At this stage you could even release your app to get details of your app population and the attributes of the devices they are running upon.

## NEXT STEPS
To actually protect your APIs there are some further steps. Approov provides two different options for protection:

* [API PROTECTION](https://github.com/approov/quickstart-ionic-advancedhttp/blob/main/API-PROTECTION.md): You should use this if you control the backend API(s) being protected and are able to modify them to ensure that a valid Approov token is being passed by the app. An [Approov Token](https://approov.io/docs/latest/approov-usage-documentation/#approov-tokens) is short lived crytographically signed JWT proving the authenticity of the call.

* [SECRETS PROTECTION](https://github.com/approov/quickstart-ionic-advancedhttp/blob/main/SECRETS-PROTECTION.md): If you do not control the backend API(s) being protected, and are therefore unable to modify it to check Approov tokens, you can use this approach instead. It allows app secrets, and API keys, to be protected so that they no longer need to be included in the built code and are only made available to passing apps at runtime.

Note that it is possible to use both approaches side-by-side in the same app, in case your app uses a mixture of 1st and 3rd party APIs.

See [REFERENCE](https://github.com/approov/quickstart-ionic-advancedhttp/blob/main/REFERENCE.md) for a complete list of all of the Approov related methods.
