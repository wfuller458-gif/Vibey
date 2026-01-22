# Vibey - macOS App for Claude Code

A calm, focused macOS app for writing, organizing, and sending prompts to Claude Code with improved terminal UX.

## Project Structure

```
Vibey/
├── Vibey/
│   ├── VibeyApp.swift              # Main app entry point
│   ├── Info.plist                  # App configuration
│   ├── Vibey.entitlements          # App capabilities (Sign in with Apple, iCloud)
│   │
│   ├── Models/                     # Data models
│   │   ├── Project.swift           # Project model
│   │   ├── Page.swift              # Page model with status tracking
│   │   └── Prompt.swift            # Prompt model
│   │
│   ├── ViewModels/                 # State management
│   │   └── AppState.swift          # Global app state
│   │
│   ├── Views/                      # UI components
│   │   ├── MainContentView.swift  # Main app interface with tabs
│   │   │
│   │   ├── Auth/                   # Authentication screens
│   │   │   ├── SignUpView.swift
│   │   │   └── LoginView.swift
│   │   │
│   │   ├── Onboarding/             # Onboarding flow
│   │   │   ├── OnboardingView.swift
│   │   │   ├── PaywallView.swift
│   │   │   ├── FirstProjectView.swift
│   │   │   └── ClaudeCodeCheckView.swift
│   │   │
│   │   └── Components/             # Reusable components
│   │       ├── VibeyLogo.swift
│   │       └── AppleSignInButton.swift
│   │
│   ├── Services/                   # Business logic & integrations
│   │   └── (TODO: CloudKit, RevenueCat, Terminal services)
│   │
│   ├── Utilities/                  # Helper code
│   │   └── DesignSystem.swift      # Colors, fonts, spacing
│   │
│   ├── Fonts/                      # Custom fonts
│   │   ├── Story_Script/
│   │   ├── Lexend/
│   │   └── Atkinson_Hyperlegible/
│   │
│   └── Assets.xcassets/            # Images and assets
│       └── Background.png
│
└── README.md                       # This file
```

## How to Open in Xcode

### Method 1: Create Xcode Project (Recommended)

1. **Open Xcode**
2. **Create a new project:**
   - Click "Create a new Xcode project"
   - Choose **macOS** → **App**
   - Click "Next"

3. **Configure project:**
   - Product Name: `Vibey`
   - Team: Select your Apple Developer account
   - Organization Identifier: Your reverse domain (e.g., `com.yourname`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click "Next"

4. **Save location:**
   - Navigate to `/Users/williamfuller/Documents/vibey.code/`
   - **IMPORTANT:** Uncheck "Create Git repository" if prompted
   - Click "Create"

5. **Replace default files:**
   - Delete the default `VibeyApp.swift` and `ContentView.swift` that Xcode created
   - In Xcode's Project Navigator (left sidebar), right-click on the "Vibey" folder
   - Select "Add Files to Vibey..."
   - Navigate to `/Users/williamfuller/Documents/vibey.code/Vibey/Vibey/`
   - Select **all folders and files** (Models, Views, ViewModels, etc.)
   - Check "Copy items if needed" is **unchecked** (we want to reference, not copy)
   - Click "Add"

### Method 2: Manual Xcode Project File

If you're comfortable with Xcode project files, you can create a `Vibey.xcodeproj` file manually, but Method 1 is recommended for beginners.

## Required Configuration

After opening the project in Xcode, you need to configure:

### 1. Signing & Capabilities

1. Select the project in Project Navigator
2. Select the "Vibey" target
3. Go to "Signing & Capabilities" tab
4. **Signing:**
   - Select your Apple Developer Team
   - Xcode will automatically manage signing

5. **Add Capabilities:**
   - Click "+ Capability"
   - Add **Sign in with Apple**
   - Add **iCloud** → Enable **CloudKit**
   - Add **In-App Purchase** (for RevenueCat)

### 2. Deployment Target

- Set minimum macOS version to **13.0** (macOS Ventura) or later
- Found in: Project Settings → General → Minimum Deployments

### 3. Custom Fonts

The fonts are already in the `Fonts/` folder. Make sure they're included in the target:
1. Select each font file in Project Navigator
2. In File Inspector (right sidebar), check "Target Membership" for "Vibey"

## TODO: Integrations

The following features have placeholder implementations and need API keys/setup:

### RevenueCat (Subscription Management)

1. Create account at [revenuecat.com](https://www.revenuecat.com)
2. Get your API key
3. Add to project (see `PaywallView.swift` TODO comments)

### iCloud CloudKit

- CloudKit container is configured in entitlements
- Need to implement sync logic in a `CloudKitService.swift` file

### Claude Code Integration

- Terminal integration is partially implemented
- See `TerminalView.swift` for shell command execution

## Running the App

1. **Build the project:**
   - Press `Cmd + B` or Product → Build

2. **Run the app:**
   - Press `Cmd + R` or Product → Run
   - The app will open in a new window

3. **Debug mode:**
   - In `AppState.swift`, there's a `#if DEBUG` block that skips subscription checks during development
   - You can modify this for testing

## Design System

All colors, fonts, and spacing are defined in `Utilities/DesignSystem.swift`:

- **Colors:** `Color.vibeyBackground`, `Color.vibeyBlue`, etc.
- **Fonts:** `.storyScript()`, `.lexendThin()`, `.atkinsonRegular()`, etc.
- **Spacing:** `Spacing.small`, `Spacing.medium`, etc.

## Next Steps

1. ✅ Basic project structure
2. ✅ Authentication UI (Sign in with Apple)
3. ✅ Onboarding flow
4. ✅ Navigation structure
5. ⏳ Implement Terminal view with Claude Code integration
6. ⏳ Implement Pages feature with markdown editing
7. ⏳ Implement Prompt Planner
8. ⏳ Add iCloud CloudKit sync
9. ⏳ Integrate RevenueCat subscriptions
10. ⏳ Error states and empty states

## Questions?

This is the MVP based on your PRD. As you continue development:
- Add more screens as you share Figma designs
- Implement the CloudKit and RevenueCat integrations
- Build out the Terminal, Pages, and Prompt Planner features

Happy building! 🚀
