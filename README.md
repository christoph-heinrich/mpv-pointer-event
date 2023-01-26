# pointer-event

### Mouse/Touch input event detection for mpv

Low latency detection of single-click, double-click, long-click and dragging.  
Each event is detected in a mutually exclusive manner, so e.g. a double-click won't also detect single-click events.

Dragging will emit a start and stop event, as well as a drag event that includes a change in coordinates which can be used for detecting gestures.

Beware that window dragging interferes with gesture detection unless you use `--no-window-dragging`.
See `ignore_left_single_long_while_window_dragging` option for more information.

## Installation

1. Save [pointer-event.lua](https://github.com/christoph-heinrich/mpv-pointer-event/raw/master/pointer-event.lua) to your [scripts directory](https://mpv.io/manual/stable/#script-location).
2. Configure the events you want to listen to in your `pointer-event.conf`

## Usage

Upon detecting an event the corresponding [command](https://mpv.io/manual/master/#list-of-input-commands) from the `pointer-event.conf` in your script-opts directory (next to the scripts directory, create if it doesn't exist) gets executed.

The command configuration follows the `<button>_<event_type>=command` pattern.

The available buttons are
```
left
right
mid
```

Touch input is recognized as `left`.
Each of those can listen to the following event types
```
single
double
long
drag_start
drag_end
drag
```

`drag` appends the change in pointer position ` dx dy` to the command.

Additionally there are also
```
long_click_time
double_click_time
drag_distance
margin_left
margin_right
margin_top
margin_bottom
ignore_left_single_long_while_window_dragging
```

They all have sensible default values with `double_click_time` following [input-doubleclick-time](https://mpv.io/manual/master/#options-input-doubleclick-time). Time is interpreted as milliseconds.  
`drag_distance` determines how far the input has to be dragged to count as a drag instead of a click/touch.
The `margin_*` options allow for easier interaction with the osd without triggering any events.

It can be desirable to have window dragging enabled and also want gesture detection.  `ignore_left_single_long_while_window_dragging` exists to avoid triggering single and long click events while dragging the window. Those events will still work while in fullscreen or maximized mode.

Beware of conflicts with mpvs built-in key bindings as well as your key configuration in `input.conf`.

## Example

[touch-gestures](https://github.com/christoph-heinrich/mpv-touch-gestures) is an example of what can be done with this.