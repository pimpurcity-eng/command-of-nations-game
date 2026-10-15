class_name FrameBudget
extends RefCounted
## Spreads start-up work over frames by time instead of by count (owner 2026-10-15: the second
## screen took far too long). Each frame does as much as fits in BUDGET_USEC, so the page stays
## responsive without waiting a whole frame for every single province, city or army.
const BUDGET_USEC: = 14000
static var _frame_start: int = 0

## True when this frame's time is used up; the caller then awaits a frame and calls restart().
static func spent() -> bool:
	if _frame_start == 0: _frame_start = Time.get_ticks_usec()
	return Time.get_ticks_usec() - _frame_start > BUDGET_USEC

static func restart() -> void:
	_frame_start = Time.get_ticks_usec()
