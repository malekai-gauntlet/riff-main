# AI Tabs Rules

## Layout Rules

1. **Section Spacing**: Sections must be clearly separated with empty lines.

### Technical Details:
- Add two empty lines between sections (e.g., between [Intro] and [Section 1])
- This improves readability and visual organization
- Empty lines should be preserved even when sections are short

### Example:
```
[Intro]
e|---5-7---|
B|---5-----|
G|---------|
D|---------|
A|---------|
E|---------|


[Section 1]
e|---5-7---|
B|---5-----|
G|---------|
D|---------|
A|---------|
E|---------|
```

2. **Tuning Display**: Tuning information should only appear once at the top of the tab.

### Technical Details:
- Display tuning in simple format: `Tuning: E A D G B e`
- Do not repeat tuning information in the header or title
- Only show tuning if it's non-standard

### Example:
```
[Song Title - Artist]

Tuning: E A D G B e

[Intro]
...
```

## Note Position Rules

1. **Minimum Position Value**: All note positions must be greater than zero (0). The first valid position in a measure is 1.

### Technical Details:
- Position values of 0 are invalid and will cause rendering issues
- Position counting starts at 1 for each measure
- This ensures proper alignment with measure bars and string labels in the tab renderer

### Example:
```
Valid positions:   Invalid positions:
e|---1---         e|0------ (❌)
B|-----1-         B|-0----- (❌)
G|-------1        G|--0---- (❌)
```

### Implementation Note:
When generating tab templates, always validate that all note positions are greater than 0 before passing them to the tab renderer.

2. **Note Spacing**: There must be at least one dash (-) between any two consecutive notes.

### Technical Details:
- Notes cannot be placed in adjacent positions
- Each dash represents a time unit between notes
- This ensures proper timing representation and readability
- Minimum spacing of one dash helps distinguish individual notes

### Example:
```
Valid spacing:     Invalid spacing:
e|--1-1--         e|--11--- (❌)
B|---1--1         B|--1-1-- (✅)
G|--1---1         G|--12--- (❌)
```

### Implementation Note:
When generating tab templates, ensure that:
- If note A is at position N, the next note B must be at position N+2 or greater
- This applies to notes on the same string
- The spacing rule helps maintain proper rhythmic representation

## Guitar Techniques

### 1. Bends (b), Releases (r), and Pull-offs (p)

#### Format Rules:
- Bends: `[fret]b[target pitch fret]`
- Releases: `r[original fret]`
- Pull-offs: `p[target fret]`
- These techniques can be combined in sequence without dashes

#### Technical Details:
- Bends indicate raising the pitch of a note to match a higher fret
- Releases return to the original pitch after a bend
- Pull-offs are performed by plucking a higher fret and pulling off to a lower fret
- When techniques are combined, they represent a continuous motion

#### Example:
```
Valid technique combinations:
e|--15b17r15p13--    Means:
                     1. Bend 15th fret to pitch of 17th fret
                     2. Release bend back to 15th fret
                     3. Pull-off to 13th fret

More examples:
e|--12b14----        (Simple bend)
e|--12b14r12--      (Bend and release)
e|--15p12----       (Simple pull-off)
```

#### Sound Recognition Guide:
- Bends (b): Listen for pitch gradually rising to match target note
- Releases (r): Listen for pitch gradually descending back to original note
- Pull-offs (p): Listen for quick, smooth transition from higher to lower note with single pick attack

#### Implementation Note:
When detecting these techniques:
- Bends: Look for continuous upward pitch movement
- Releases: Look for gradual return to original pitch after a bend
- Pull-offs: Look for quick descending pitch change with characteristic decay
- Multiple techniques should be rendered without spacing between them 