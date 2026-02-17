# Stattie iOS App Store Submission Guide

> Complete guide to publishing Stattie on the Apple App Store

---

## Table of Contents

1. [Pre-Submission Checklist](#pre-submission-checklist)
2. [App Store Connect Setup](#app-store-connect-setup)
3. [App Information](#app-information)
4. [Screenshots](#screenshots)
5. [App Description & Metadata](#app-description--metadata)
6. [Privacy Policy](#privacy-policy)
7. [App Review Guidelines](#app-review-guidelines)
8. [Submission Steps](#submission-steps)
9. [Post-Submission](#post-submission)

---

## Pre-Submission Checklist

### Technical Requirements

- [ ] **Xcode Version**: Use latest stable Xcode (15.x or newer)
- [ ] **iOS Deployment Target**: Set minimum iOS version (recommend iOS 17.0+)
- [ ] **App Icon**: 1024x1024 PNG (no alpha channel, no rounded corners)
- [ ] **Bundle Identifier**: `com.yourcompany.stattie` (unique, cannot change)
- [ ] **Version Number**: Set in Xcode (e.g., `1.0.0`)
- [ ] **Build Number**: Auto-increment for each upload (e.g., `1`)
- [ ] **Signing Certificate**: Valid Apple Distribution certificate
- [ ] **Provisioning Profile**: App Store distribution profile

### CloudKit Setup

- [ ] Enable CloudKit in Apple Developer Portal
- [ ] Configure CloudKit container: `iCloud.com.yourcompany.stattie`
- [ ] Deploy CloudKit schema to production
- [ ] Test iCloud sync on TestFlight

### Testing

- [ ] All features tested on physical devices
- [ ] Tested on multiple iPhone sizes (SE, Pro, Pro Max)
- [ ] Tested on iPad if Universal app
- [ ] TestFlight beta testing completed
- [ ] No crashes in crash reporting
- [ ] Memory usage acceptable

---

## App Store Connect Setup

### 1. Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: Stattie
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select your bundle identifier
   - **SKU**: `stattie-ios-001` (internal reference)
   - **User Access**: Full Access

### 2. App Pricing

1. Go to **App Pricing and Availability**
2. Set **Price**: **$4.99 (Tier 5)**
3. Select **Availability**: All territories (or select specific)
4. No subscriptions or in-app purchases needed

---

## App Information

### App Name
```
Stattie
```

### Subtitle (30 characters max)
```
Basketball Stat Tracker
```

### Category
- **Primary**: Sports
- **Secondary**: Utilities

### Content Rating
- Complete the Age Rating questionnaire
- Expected rating: **4+** (no objectionable content)

### Keywords (100 characters max, comma-separated)
```
basketball,stats,tracking,sports,coach,youth,game,score,statistics,player,team,hoops,points,rebounds
```

---

## Screenshots

### Required Sizes

| Device | Size | Required |
|--------|------|----------|
| iPhone 6.9" (15 Pro Max) | 1320 x 2868 | Yes |
| iPhone 6.7" (14 Pro Max) | 1290 x 2796 | Yes |
| iPhone 6.5" | 1284 x 2778 | Optional |
| iPhone 5.5" | 1242 x 2208 | Optional |
| iPad Pro 12.9" 6th Gen | 2048 x 2732 | If Universal |
| iPad Pro 12.9" 2nd Gen | 2048 x 2732 | If Universal |

### Screenshot Strategy (5-10 screenshots per device)

#### Screenshot 1: Hero - Live Tracking
- **Scene**: GameTrackingView with active game
- **Text Overlay**: "Track Every Shot"
- **Subtext**: "Real-time stat tracking during live games"
- **Show**: Points display, stat buttons (2PT, 3PT, FT), timer
- **Background**: Gradient orange to dark

#### Screenshot 2: Quick Stat Entry
- **Scene**: GameTrackingView focused on buttons
- **Text Overlay**: "Tap to Track"
- **Subtext**: "Big buttons designed for sideline use"
- **Show**: Grid of stat buttons (D-REB, O-REB, STEAL, ASSIST)
- **Background**: Clean white/gray

#### Screenshot 3: Game Summary
- **Scene**: GameSummaryView after completed game
- **Text Overlay**: "Complete Game Summaries"
- **Subtext**: "Shooting splits, rebounds, assists & more"
- **Show**: Stats table with percentages, team totals
- **Background**: Light gray

#### Screenshot 4: Team Sharing
- **Scene**: Sharing/Team invite screen
- **Text Overlay**: "Share with Your Team"
- **Subtext**: "Invite coaches & parents via iCloud"
- **Show**: Share invite UI, participant list
- **Background**: Blue tint

#### Screenshot 5: Player Profiles
- **Scene**: Player list or player detail view
- **Text Overlay**: "Track Every Player"
- **Subtext**: "Season stats follow players across games"
- **Show**: Player cards with jersey numbers, positions
- **Background**: Orange accent

#### Screenshot 6: Offline Mode (Optional)
- **Scene**: GameTrackingView with offline indicator
- **Text Overlay**: "Works Offline"
- **Subtext**: "Track games in gyms with no WiFi"
- **Show**: Normal UI with sync indicator
- **Background**: Dark mode if available

#### Screenshot 7: Achievements (Optional)
- **Scene**: Double-double or triple-double celebration
- **Text Overlay**: "Celebrate Milestones"
- **Subtext**: "Track career highs & achievements"
- **Show**: Achievement overlay animation
- **Background**: Purple/gold celebration colors

### Screenshot Design Guidelines

```
Frame: iPhone 15 Pro mockup (optional but recommended)
Text: SF Pro Display, Bold
Text Color: White with subtle shadow
Overlay Position: Top 20% of screenshot
App Screenshot: Bottom 80%
Background: Gradient matching brand (orange #EA580C)
```

### How to Capture Screenshots

**Option A: Xcode Simulator**
1. Run app in Simulator (iPhone 15 Pro Max)
2. Navigate to desired screen
3. Press `Cmd + S` to save screenshot
4. Add to Figma/Sketch for text overlays

**Option B: Physical Device**
1. Connect iPhone to Mac
2. Open QuickTime → File → New Movie Recording
3. Select iPhone as camera source
4. Take screenshots at higher quality

**Option C: Fastlane Snapshot** (Automated)
```bash
# Install fastlane
gem install fastlane

# Initialize
cd /path/to/stattie
fastlane snapshot init

# Configure Snapfile for desired devices
# Run automated screenshots
fastlane snapshot
```

---

## App Description & Metadata

### Short Description (Promotional Text - 170 chars max)
```
Track basketball games in real-time. Simple stat tracking for coaches, parents & players. iCloud sync, offline mode, no subscription. One-time purchase.
```

### Full Description

```
TRACK EVERY SHOT. OWN EVERY STAT.

Stattie is the simple, powerful way to track basketball statistics during live games. Built for youth basketball families, coaches, and players who want accurate stats without complicated apps.

REAL-TIME STAT TRACKING
Tap to record points (2PT, 3PT, Free Throws), rebounds, assists, steals, blocks, and fouls as the action happens. Big, easy-to-tap buttons keep you focused on the game, not the app.

SHARE WITH YOUR TEAM
Invite coaches, parents, and teammates to view and track stats together via iCloud. Everyone sees updates in real-time across all their devices.

DETAILED GAME SUMMARIES
After each game, get comprehensive breakdowns including:
• Shooting percentages (FG%, 3P%, FT%)
• Plus/minus tracking
• Rebounds (offensive & defensive)
• All other stats in one clean view

WORKS EVERYWHERE
• Works offline in gyms with no WiFi
• Stats sync automatically when back online
• No account required - uses your iCloud

BUILT FOR BASKETBALL FAMILIES
• Perfect for youth leagues, travel ball, and high school
• Simple enough for any parent to use
• Detailed enough for serious coaches
• Great for players tracking their own development

ONE-TIME PURCHASE
Pay once, own it forever. No subscriptions, no ads, no in-app purchases. All future updates included.

FEATURES
• Unlimited players and games
• Real-time stat tracking
• iCloud sharing with team
• Detailed game summaries
• Offline mode
• Player profiles with jersey numbers
• Season organization
• Career stat tracking
• Share summaries as images
• Double-double & triple-double detection

Download Stattie and start tracking your next game!
```

### What's New (Version 1.0.0)
```
Initial release of Stattie!

• Real-time basketball stat tracking
• iCloud sharing with coaches, parents & teammates
• Comprehensive game summaries
• Works offline
• Player profiles and season tracking
• No subscription required
```

### Support URL
```
https://stattie.app/support
```
*(Create a support page on the website or use email)*

### Marketing URL
```
https://stattie.app
```

---

## Privacy Policy

### Privacy Policy URL
```
https://stattie.app/privacy
```

### Privacy Practices Questionnaire

**Data Collection**:
| Data Type | Collected | Linked to User | Used for Tracking |
|-----------|-----------|----------------|-------------------|
| Contact Info | No | - | - |
| Health & Fitness | No | - | - |
| Financial Info | No | - | - |
| Location | No | - | - |
| Sensitive Info | No | - | - |
| Contacts | No | - | - |
| User Content | Yes (iCloud) | No | No |
| Browsing History | No | - | - |
| Search History | No | - | - |
| Identifiers | No | - | - |
| Usage Data | No | - | - |
| Diagnostics | No | - | - |

**Data Linked to You**: None
**Data Used to Track You**: None

### Privacy Nutrition Label Summary
```
Data Not Collected
This app does not collect any data.
```

*(If you use analytics, update accordingly)*

---

## App Review Guidelines

### Common Rejection Reasons & How to Avoid

#### 1. Incomplete Metadata
- Ensure all screenshots are present
- Fill out all required fields
- Valid privacy policy URL

#### 2. Bugs or Crashes
- Test thoroughly before submission
- Check crash logs in Xcode Organizer
- Test all user flows

#### 3. Placeholder Content
- Remove all "Lorem ipsum" or sample data
- Ensure app works with empty state (no players/games)

#### 4. iCloud Requirements
- Test CloudKit in production environment
- Handle offline gracefully
- Show clear error messages for sync issues

#### 5. Login Requirements
- Stattie doesn't require login (good!)
- iCloud uses system authentication

### Review Notes (for Apple Reviewer)

```
DEMO INSTRUCTIONS:

Stattie is a basketball stat tracking app that uses iCloud for data sync and sharing.

To test the app:

1. TRACKING A GAME
   - Tap "New Game" from the main screen
   - Enter an opponent name (e.g., "Eagles")
   - Tap "Start Tracking"
   - Tap stat buttons to record (2PT, 3PT, rebounds, etc.)
   - Tap "End Game" when done

2. VIEWING SUMMARIES
   - After ending a game, the summary appears automatically
   - Shows all shooting percentages and stats

3. SHARING (requires 2nd iCloud account)
   - To test iCloud sharing, you'll need two devices
   - Tap the share icon on a player profile
   - Invite via iCloud

4. OFFLINE MODE
   - Turn off WiFi and cellular
   - App continues to work and saves locally
   - Data syncs when reconnected

No login required. App uses iCloud automatically.

Contact for questions: support@stattie.app
```

---

## Submission Steps

### 1. Archive Your App

```bash
# In Xcode:
# 1. Select "Any iOS Device (arm64)" as destination
# 2. Product → Archive
# 3. Wait for archive to complete
```

### 2. Validate Archive

1. In Xcode Organizer, select archive
2. Click **Validate App**
3. Select distribution options:
   - **Automatically manage signing**
   - **Include bitcode**: Yes
   - **Include symbols**: Yes
4. Fix any validation errors

### 3. Upload to App Store Connect

1. Click **Distribute App**
2. Select **App Store Connect**
3. Select **Upload**
4. Wait for upload to complete
5. Build will appear in App Store Connect within ~30 minutes

### 4. Submit for Review

1. Go to App Store Connect → Your App
2. Click **+ Version or Platform** if first submission
3. Fill in all required fields:
   - Version information
   - Screenshots
   - Description
   - Keywords
   - Support URL
   - Privacy Policy URL
4. Select build from uploaded archives
5. Answer export compliance:
   - "Does your app use encryption?" → **No** (iCloud uses system encryption)
6. Answer content rights:
   - "Does your app contain third-party content?" → **No**
7. Answer advertising identifier:
   - "Does this app use the Advertising Identifier (IDFA)?" → **No**
8. Click **Submit for Review**

### 5. Wait for Review

- Average review time: 24-48 hours
- You'll receive email notifications
- App status changes in App Store Connect

---

## Post-Submission

### If Approved
1. App goes live on App Store (automatic or manual release)
2. Update the website with App Store link:
   ```
   https://apps.apple.com/app/stattie/id[YOUR_APP_ID]
   ```
3. Update `AppStoreLink.tsx` with real URL
4. Announce launch on social media
5. Monitor ratings and reviews
6. Respond to user feedback

### If Rejected

1. Read rejection reason carefully
2. Check Resolution Center in App Store Connect
3. Reply to reviewer with questions if unclear
4. Fix issues and resubmit
5. Most rejections are resolved in 1-2 iterations

### Common Post-Launch Tasks

- [ ] Update website App Store link
- [ ] Add "Download on the App Store" badge to marketing
- [ ] Set up App Store Connect notifications
- [ ] Monitor crash reports in Xcode Organizer
- [ ] Track user reviews and ratings
- [ ] Plan first update based on feedback

---

## Quick Reference

### App Store Product Page Summary

| Field | Value |
|-------|-------|
| **App Name** | Stattie |
| **Subtitle** | Basketball Stat Tracker |
| **Price** | $4.99 |
| **Category** | Sports |
| **Age Rating** | 4+ |
| **Privacy** | Data Not Collected |

### Important URLs

| Purpose | URL |
|---------|-----|
| Marketing | https://stattie.app |
| Privacy Policy | https://stattie.app/privacy |
| Terms | https://stattie.app/terms |
| Support | https://stattie.app/support or support@stattie.app |

### Contact Info

| Role | Email |
|------|-------|
| Developer | developer@stattie.app |
| Support | support@stattie.app |
| Marketing | hello@stattie.app |

---

## Screenshot Text Templates

For quick copy/paste when designing screenshots:

### Headlines
1. "Track Every Shot"
2. "Tap to Track"
3. "Complete Game Summaries"
4. "Share with Your Team"
5. "Track Every Player"
6. "Works Offline"
7. "Celebrate Milestones"

### Subheadlines
1. "Real-time stat tracking during live games"
2. "Big buttons designed for sideline use"
3. "Shooting splits, rebounds, assists & more"
4. "Invite coaches & parents via iCloud"
5. "Season stats follow players across games"
6. "Track games in gyms with no WiFi"
7. "Track career highs & achievements"

---

## Appendix: Fastlane Setup (Optional)

For automated screenshot generation and deployment:

```ruby
# fastlane/Fastfile

default_platform(:ios)

platform :ios do
  desc "Generate screenshots"
  lane :screenshots do
    capture_screenshots
    frame_screenshots(white: true)
  end

  desc "Upload to App Store"
  lane :release do
    build_app(scheme: "Stattie")
    upload_to_app_store(
      skip_metadata: false,
      skip_screenshots: false
    )
  end
end
```

```ruby
# fastlane/Snapfile

devices([
  "iPhone 15 Pro Max",
  "iPhone 15 Pro",
  "iPad Pro (12.9-inch) (6th generation)"
])

languages(["en-US"])

scheme("Stattie")
output_directory("./screenshots")
clear_previous_screenshots(true)
```

---

*Last updated: February 2025*
*Stattie Version: 1.0.0*
