# Quick Setup Guide for Vibey

Follow these steps to open and run Vibey in Xcode.

## Step 1: Open Xcode

1. Launch **Xcode** on your Mac
2. If you don't have Xcode, install it from the Mac App Store (it's free)

## Step 2: Create New Xcode Project

1. Click **"Create a new Xcode project"**

2. Select **macOS** tab at the top

3. Choose **App** template

4. Click **Next**

5. Fill in the project details:
   - **Product Name:** `Vibey`
   - **Team:** Select your Apple Developer account (or "None" for now)
   - **Organization Identifier:** `com.yourname` (replace with your reverse domain)
   - **Interface:** SwiftUI ✅
   - **Language:** Swift ✅
   - **Include Tests:** ❌ (uncheck for now)

6. Click **Next**

7. **IMPORTANT:** When choosing where to save:
   - Navigate to `/Users/williamfuller/Documents/vibey.code/`
   - **Uncheck** "Create Git repository" (if shown)
   - Click **Create**

⚠️ **Xcode will create a default project with some files we don't need.**

## Step 3: Remove Default Files

Xcode created some default files we need to replace:

1. In the left sidebar (Project Navigator), you'll see:
   ```
   Vibey/
     ├── VibeyApp.swift     ← Delete this
     └── ContentView.swift  ← Delete this
   ```

2. **Right-click** on `VibeyApp.swift` → **Delete** → **Move to Trash**

3. **Right-click** on `ContentView.swift` → **Delete** → **Move to Trash**

## Step 4: Add Our Project Files

Now we'll add all the files I created for you:

1. **Right-click** on the **"Vibey"** folder in the left sidebar

2. Select **"Add Files to Vibey..."**

3. Navigate to:
   ```
   /Users/williamfuller/Documents/vibey.code/Vibey/Vibey/
   ```

4. Hold **Command (⌘)** and click to select these folders:
   - `Models`
   - `Views`
   - `ViewModels`
   - `Services`
   - `Utilities`
   - `Fonts`
   - `Assets.xcassets`

5. Also select these individual files:
   - `VibeyApp.swift`
   - `Info.plist`
   - `Vibey.entitlements`

6. **IMPORTANT:** At the bottom of the dialog:
   - **Uncheck** "Copy items if needed"
   - **Check** "Create folder references"
   - Make sure "Vibey" target is checked

7. Click **Add**

## Step 5: Configure Signing & Capabilities

1. Click on the **"Vibey"** project in the left sidebar (the blue icon at the top)

2. Select the **"Vibey"** target (under TARGETS)

3. Go to **"Signing & Capabilities"** tab

4. **Automatically manage signing:** ✅ (check this)

5. **Team:** Select your Apple Developer account
   - If you don't have one, you can use a Personal Team (free)
   - Click "Add Account..." if needed

6. **Add Capabilities** (click the "+ Capability" button):
   - Add **"Sign in with Apple"**
   - Add **"iCloud"** → check **"CloudKit"**

## Step 6: Set Deployment Target

1. Still in project settings, go to **"General"** tab

2. Under **"Minimum Deployments":**
   - Set macOS to **13.0** or later

## Step 7: Verify Font Files

Make sure the custom fonts are included:

1. In left sidebar, expand **Fonts** folder

2. Click on any font file (e.g., `StoryScript-Regular.ttf`)

3. In right sidebar, check **"Target Membership"** → "Vibey" should be checked

4. If not checked, check it

5. Repeat for all font files if needed

## Step 8: Build and Run

1. Press **⌘ + B** (Command + B) to build the project

2. If you get any errors, read them carefully - most common issues:
   - Missing fonts: Make sure fonts are added to target
   - Signing issues: Make sure you selected a Team
   - Code errors: Let me know and I'll fix them!

3. Press **⌘ + R** (Command + R) to run the app

4. The Vibey app should launch in a new window!

## What You'll See

When you run the app:

1. **Sign Up screen** with your exact Figma design ✅
   - Dark background with grid pattern
   - Centered card with logo
   - "Sign up with Apple" button

2. You can toggle to **Login screen** with the link at bottom

3. After "signing in" (mock for now), you'll see:
   - **Paywall screen** with pricing
   - **First project creation**
   - **Claude Code check**

4. Finally, the **main app** with navigation tabs:
   - Terminal (placeholder)
   - Pages (placeholder)
   - Prompt Planner (placeholder)

## Troubleshooting

### "No such module 'AuthenticationServices'"
- Make sure macOS deployment target is 13.0+

### Fonts not showing correctly
- Check Info.plist has the fonts listed
- Check font files have Target Membership checked

### Build errors
- Take a screenshot of the error
- Let me know which file and line number

### "Failed to register bundle identifier"
- Go to Signing & Capabilities
- Change the Bundle Identifier to something unique (e.g., add `.yourname`)

## Next Steps

Once the app is running:

1. Share more Figma designs for Terminal, Pages, and Prompt Planner views
2. I'll implement those features to match your designs
3. We'll integrate RevenueCat for real subscriptions
4. We'll add iCloud sync
5. We'll build the Claude Code terminal integration

---

**Need help?** Just let me know which step you're stuck on! 🚀
