# command_tower

## UI design
Design a control before writing it. Words, placement and appearance are the
feature, not polish.
- **Name it with the app's existing words.** Grep the UI strings before
  introducing a term.
- **Name the setting after what's being chosen,** never after one of its
  values.
- **Pick the control by meaning.** A switch turns one thing on or off. A
  choice between named alternatives is a `SegmentedButton`. Several of one
  kind are chips.
- **Place it deliberately.** A distinct setting gets its own section, next to
  related ones and in an order that reads naturally.
- **Look at it before calling it done.** Screenshot it on the emulator, check
  the wording, alignment and visual weight against neighbouring elements, and
  show the user the screenshot.

### Copy
Show, don't tell. No subtitles, helper lines or descriptions that restate what
the UI already makes evident. Default to a bare title/control; add text only
when the user can't otherwise know something they need. When asked to trim
copy, delete it — don't reword it into another explanation.

## Editing
- The codebase is `dart format`-clean; run `dart format` on every Dart file you
  touch.
- Use the Edit tool for Dart changes. Shell/JS patch scripts mangle Dart's `$`
  and `${}` interpolation and quote characters.
- Never `git stash` (or `checkout`) a file to try an alternate version — it
  swaps out *all* uncommitted work in that file. Copy the file aside and back.

## Releases
- Every push to `main` deploys to the Play internal track
  (`.github/workflows/release.yml`), and CI runs `flutter test` first — keep
  tests green on `main`.
