# AllAuthClientSwift

AllAuthClientSwift is a SwiftUI package for apps that authenticate against Django AllAuth headless APIs. It provides a JSON client, auth state management, token storage, reusable account views, account creation, login by code, MFA flows, social-provider token flows, and auth diagnostics.

The package is not a general Openbase API client and is not tied to Django REST Framework. It expects a backend that exposes the Django AllAuth headless endpoint contract, such as `/_allauth/app/v1/config`, `/_allauth/app/v1/auth/session`, `/_allauth/app/v1/auth/login`, and `/_allauth/app/v1/tokens/refresh`.

## Installation

Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/openbase-community/allauth-client-swift.git", branch: "main")
```

Then depend on the library product:

```swift
.product(name: "AllAuthClientSwift", package: "allauth-client-swift")
```

## Usage

Configure the client with the AllAuth headless base URL:

```swift
import AllAuthClientSwift

AllAuthClient.shared.setup(baseUrl: "https://example.com/_allauth/app/v1")
```

Wrap authenticated app content with `AllAuthRootView`:

```swift
AllAuthRootView {
    AuthenticatedAppView()
}
.environmentObject(AuthContext.shared)
```

You can also call the client directly for auth operations:

```swift
let response = try await AllAuthClient.shared.login(
    email: email,
    password: password
)
```

The default login UI shows account creation, login by code, and configured social providers when the backend exposes those flows. Sign in with Apple works out of the box through allauth's mobile `provider_token` endpoint. Other native providers can be connected by passing `onSocialProviderSelected` to `AllAuthRootView` or `LoginView` and returning the allauth provider-token response after completing that provider's SDK flow.

## License

AllAuthClientSwift is available under the MIT License. See [LICENSE](LICENSE).
