# Plus/Minus Tracking Feature

## Summary
Added comprehensive plus/minus tracking for player shifts during games. When a shift ends, the user is prompted to enter the current score, and the system calculates the point differential for that player's time on the court.

## How It Works

### Starting a Shift
1. User taps "Start Shift" button
2. Sheet appears asking for current score (Our Team vs Opponent)
3. User enters scores using +/- buttons
4. Shift begins with scores recorded as `startingTeamScore` and `startingOpponentScore`

### Ending a Shift
1. User taps "End Shift" button
2. Sheet appears with:
   - Reference to starting score
   - Current score input (defaults to starting scores)
   - Live plus/minus preview
3. User enters current scores
4. Shift ends with `endingTeamScore` and `endingOpponentScore` recorded
5. Plus/minus automatically calculated

### Plus/Minus Calculation
```
Plus/Minus = (endingTeamScore - startingTeamScore) - (endingOpponentScore - startingOpponentScore)
```

Example:
- Start: 20-18 (team leading by 2)
- End: 28-22 (team leading by 6)
- Team scored: 8 points
- Opponent scored: 4 points
- Plus/Minus: +4

## Files Changed

### Models
- **Shift.swift**
  - Added `startingTeamScore`, `startingOpponentScore`
  - Added `endingTeamScore`, `endingOpponentScore`
  - Added `plusMinus` computed property
  - Added `formattedPlusMinus` for display
  - Updated `init()` to accept scores
  - Updated `endShift()` to accept scores

- **PersonGameStats.swift**
  - Added `totalPlusMinus` aggregation
  - Added `formattedTotalPlusMinus`
  - Updated `startNewShift()` to accept scores
  - Updated `endCurrentShift()` to accept scores

- **Person.swift**
  - Added `careerPlusMinus` (total across all games)
  - Added `formattedCareerPlusMinus`
  - Added `averagePlusMinus` (per game average)

### Views
- **ShiftTrackingView.swift**
  - Added `StartShiftScoreSheet` for entering scores when starting
  - Added `EndShiftScoreSheet` for entering scores when ending
  - Added `ScoreInputColumn` reusable component
  - Updated `ShiftSummaryRow` to show plus/minus and score changes
  - Added plus/minus to Game Totals section

- **GameDetailView.swift**
  - Updated `PersonStatsRow` to show plus/minus
  - Shows shift count and total time when shifts tracked

- **PlayerDetailView.swift**
  - Added Plus/Minus section with career stats
  - Added `PlusMinusCard` component

- **GameSummaryView.swift** (Iteration 3)
  - Added Plus/Minus section showing all players' +/- data
  - Added `PlusMinusRow` component for tabular display
  - Updated share text to include plus/minus data when available

## UI Components

### ScoreInputColumn
- Title label
- Large score display
- Plus/minus buttons for adjustment
- Configurable color

### StartShiftScoreSheet
- "Enter Current Score" header
- Two ScoreInputColumns (Team / Opponent)
- "Start Shift" button

### EndShiftScoreSheet
- Shows starting score reference
- Two ScoreInputColumns for ending score
- Live plus/minus preview with color coding
- "End Shift" button

### ShiftSummaryRow (updated)
- Shift number and duration
- Score transition (e.g., "20-18 → 28-22")
- Points scored during shift
- Plus/minus with color (green/red)

## Color Coding
- **Green**: Positive plus/minus (team outscored opponent)
- **Red**: Negative plus/minus (opponent outscored team)
- **Gray/Secondary**: Zero or no data

## Data Display Locations

1. **During Game (ShiftTrackingView)**
   - Each shift row shows +/-
   - Game totals section shows cumulative +/-

2. **Game Detail (GameDetailView)**
   - Each player row shows their game +/-
   - Also shows shift count and total time

3. **Player Profile (PlayerDetailView)**
   - Career plus/minus total
   - Per-game plus/minus average

4. **Game Summary (GameSummaryView)** - Added Iteration 3
   - Plus/Minus section with all players in a table
   - Shows player name, shift count, time, and +/-
   - Sorted by plus/minus (best performers first)
   - Included in share text when sharing game stats

5. **Stats Over Time (PlayerStatsOverTimeView)** - Added Iteration 5
   - Plus/Minus added as a trackable stat type
   - Chart displays with zero line reference
   - Points colored green (positive) or red (negative)
   - Recent games list shows formatted +/- values
   - Can track plus/minus trends over time

6. **Shareable Game Cards (ShareableStatsCard.swift)** - Added Iteration 7
   - `GameHighlightCard` now supports optional plusMinus parameter
   - When plus/minus data exists, shows 4-column layout (PTS, REB, AST, +/-)
   - Added `PlusMinusColumn` component for consistent +/- display
   - Color-coded green/red based on value

## Technical Notes

- Plus/minus is only calculated when both ending scores are provided
- Returns `nil` if shift hasn't ended or scores weren't recorded
- Backwards compatible - old shifts without scores show "--"
- Aggregation methods handle nil values gracefully

## UX Enhancements (Iteration 2)

### Score Persistence Between Shifts
- When starting a new shift, scores auto-populate from the previous shift's ending scores
- This saves time since the game score continues from where it left off
- When ending a shift, scores default to the current shift's starting scores (user adjusts to current)

### Quick Score Buttons
- Added +2 and +3 quick increment buttons for basketball scoring scenarios
- Allows rapid score entry without multiple taps

### Haptic Feedback
- Added haptic feedback (light impact) on all score changes
- Provides tactile confirmation of input

### Components Added
- `QuickScoreButton`: Compact button for quick score increments (+2, +3)

## User Benefits

1. **Performance Insight**: See which players help the team most when on court
2. **Lineup Decisions**: Data to support who should play together
3. **Player Development**: Track improvement over time
4. **Game Analysis**: Identify scoring runs and momentum shifts
5. **Fast Score Entry**: Quick buttons and auto-population reduce friction during live tracking
