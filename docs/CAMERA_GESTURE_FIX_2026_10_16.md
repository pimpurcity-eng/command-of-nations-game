# Camera gesture fix — 16 October 2026

This is one isolated fix on top of `claude/wip-oct16` at `61d980e237137a657e0c5ce834111e706bab2fbd`. It does not make the unfinished Oct 16 work ready for a release.

## Problem and change

Android sends each finger's movement as a separate event. The WIP camera recalculated the pinch after each event. During a two-finger pan, the first event temporarily changed the span relative to the other finger's previous position. This crossed the pinch threshold and caused an unintended zoom, depending on which finger's event arrived first.

The camera now collects finger positions and updates a pinch once per process frame. It flushes queued movement before a finger is released or the gesture's finger set changes, including releases consumed by the UI. Clearing gestures also clears queued movement.

## Verification

Godot `4.6.3.stable.official.7d41c59c4`, headless, fixed 60 fps, 540 × 960 viewport. The tests used the real camera script in an isolated project; they require no private models or running match.

- `test_camera_gestures.gd`: **16 checks, 4 failures before the fix; 16 checks, 0 failures after**.
- Covers both finger delivery orders, two-finger panning without zoom, deliberate pinches, small span noise, release before the next frame, UI-consumed releases, gesture reset, normal taps, and no pinch-release tap or fling.
- Existing `test_camera_pinch_anchor.gd`: **PASS before and after**. Reported drift during queued zoom inputs: 0; after settling: approximately 0.03013 world units, below its 0.05 threshold.

No Android build, physical-phone test, full-game regression run, or production deployment was performed for this change. Verify the gesture on the Samsung phone before marking the overall camera item complete.

## Integration and one-writer handoff

Target this change at `claude/wip-oct16`. Only one worker should edit the same game files at a time. The remaining Oct 16 checklist is still unfinished and must be completed and tested separately.

The build branch `claude/v0.26-fixes` at `20c71710ee98ed75d11134d06dc59baaf8949cf6` has the same file contents as `bc8af3b01732f778fb0e1bb8b7801b3193166572` (GitHub comparison returned zero changed files). Its newer commit undoes the WIP; the WIP commits remain in its ancestry.

When the whole WIP is ready to integrate, explicitly undo that restoration commit on a review branch before merging the finished WIP. A normal merge alone will not restore changes Git already considers merged and subsequently reverted. Review the resulting diff and run the release checks before updating the auto-deploying build branch. No history rewrite is required.
