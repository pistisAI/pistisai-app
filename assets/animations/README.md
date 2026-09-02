# Rive Avatar Animation Asset

## File: `avatar.riv`

This directory should contain a Rive (`.riv`) animation file for the PistisAI agent avatar.

## Required Artboards & State Machines

The `.riv` file must contain a single **Artboard** named `Avatar` with a **State Machine** named `AvatarStateMachine`.

### Animation States

The state machine must expose the following **input states** (mapped to `AgentState` enum values):

| State      | Description                                      | Visual Cues                          |
|------------|--------------------------------------------------|--------------------------------------|
| `idle`     | Default resting state, gentle idle animation     | Slow breathing, subtle blink         |
| `thinking` | Active cognitive processing                       | Pulsing glow, shifting eyes          |
| `working`  | Performing a task                                 | Spinning/processing indicators       |
| `error`    | Error or failure state                           | Red tint, shake animation            |
| `happy`    | Success or positive feedback                     | Bright colors, bounce/celebration    |

### State Machine Inputs

The state machine should use a **number input** named `state` with the following values:

| Value | State      |
|-------|------------|
| 0     | `idle`     |
| 1     | `thinking` |
| 2     | `working`  |
| 3     | `error`    |
| 4     | `happy`    |

### Design Guidelines

- **Resolution**: 512×512 px artboard
- **Format**: Vector shapes only (no raster images)
- **Colors**: Use palette-agnostic shapes; tinting is applied at runtime
- **Personality Integration**: Design neutral base animations — personality-driven color and speed modulation is handled by the Dart layer

## Creating the Asset

1. Open the [Rive Editor](https://editor.rive.app/)
2. Create a new file with a 512×512 artboard named `Avatar`
3. Design the avatar character (lobster mascot or abstract agent face)
4. Create animations for each state
5. Add a State Machine named `AvatarStateMachine`
6. Add a number input `state` (0–4) to the state machine
7. Wire each state value to its corresponding animation
8. Export as `avatar.riv` and place in this directory

## Runtime Behavior

When the `.riv` file is loaded at runtime:

1. The `RiveAvatar` widget loads `assets/animations/avatar.riv`
2. It looks for the `Avatar` artboard and `AvatarStateMachine` state machine
3. On each state change, it sets the `state` input to the corresponding numeric value
4. If the `.riv` file is missing or fails to load, the widget gracefully falls back to `EmojiBlendingAvatar`

## Dependencies

The `rive` Flutter package must be added to `pubspec.yaml`:

```yaml
dependencies:
  rive: ^0.13.20
```
