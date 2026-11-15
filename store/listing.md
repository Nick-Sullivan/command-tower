# Play Store listing content

Everything to paste into Play Console → Store presence → Main store listing.
App icon: `play_icon_512.png` (regenerate with
`flutter test tool/app_icon/generate_icons_test.dart`). Still needed in this
folder: `feature_graphic.png` (Feature graphic, 1024x500), and at least 2 phone
screenshots.

## App name (30 chars max)

    Command Tower

## Short description (80 chars max)

    TODO

## Full description (4000 chars max)

TODO

This app is unofficial Fan Content permitted under the Fan Content Policy. Not
approved/endorsed by Wizards. Portions of the materials used are property of
Wizards of the Coast. ™ & © Wizards of the Coast.

## Console form answers (quick reference)

- Category: Tools (or Entertainment)
- Ads: No ads
- Data safety: No data collected, no data shared
- Content rating questionnaire: reference/utility app → Everyone
- Privacy policy URL: https://<your-github-username>.github.io/command-tower/privacy-policy.html
  (enable GitHub Pages: repo Settings → Pages → Deploy from branch → main,
  folder /docs — then fill in the contact email placeholder in
  docs/privacy-policy.html)

## Screenshots

Play requires at least 2 phone screenshots (PNG/JPEG, shortest side ≥320px):

    flutter run --release
    adb exec-out screencap -p > store/screenshot_1.png
