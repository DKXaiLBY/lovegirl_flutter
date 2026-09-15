# LoveGirl UI Release Preflight

Last updated: 2026-07-18

## Scope

This checklist covers the current UI rebuild target:

- `lib/screens/home/home_screen.dart`
- `lib/screens/travel/travel_main_screen.dart`
- `lib/screens/travel/travel_amap_mode_screen.dart`
- `lib/widgets/travel_map_widget.dart`
- `lib/screens/feeding/feeding_screen.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/widgets/weather_widget.dart`

## What is already verified

### Static verification

- Core UI files above pass `flutter analyze`.
- Core UI widget tests now pass:
  - `home screen keeps the confirmed ticket layout`
  - `travel map button opens add form first when there are no spots`
  - `travel amap mode shows ticket fallback when there are no spots`
- Full-project `flutter analyze` has no `error` or `warning` level issues from the current UI rebuild; current remaining findings are `info` only.
- Android native compile checks also pass after the latest AMap hardening:
  - `gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac`
  - `gradlew.bat :app:compileDebugKotlin`
- Latest targeted recheck on 2026-07-12 also passes:
  - `flutter analyze lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart`
  - `gradlew.bat :amap_flutter_map:compileDebugJavaWithJavac :app:compileDebugKotlin --offline`
- Latest verification on 2026-07-13 also passes:
  - `flutter analyze lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart test/widget_test.dart`
  - `flutter test`
- Latest cleanup verification on 2026-07-13 also passes:
  - `flutter analyze lib/widgets/travel_map_widget.dart lib/providers/travel_provider.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart`
  - `flutter analyze lib/screens/home/home_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/services/log_service.dart`
  - `flutter test`
- Latest stability verification on 2026-07-13 also passes:
  - `flutter analyze lib/providers/auth_provider.dart lib/screens/anniversary/anniversary_screen.dart test/widget_test.dart`
  - `flutter analyze lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/widgets/travel_map_widget.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/providers/auth_provider.dart lib/screens/anniversary/anniversary_screen.dart test/widget_test.dart`
  - `flutter test test/widget_test.dart`
  - `flutter build apk --debug`
- Latest release-surface verification on 2026-07-13 also passes:
  - `flutter analyze lib/screens/version/update_dialog.dart`
  - `flutter analyze lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/widgets/travel_map_widget.dart lib/screens/feeding/feeding_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/providers/auth_provider.dart lib/screens/anniversary/anniversary_screen.dart lib/screens/version/update_dialog.dart test/widget_test.dart`
  - `flutter test test/widget_test.dart`
  - `flutter build apk --debug`
- Remaining project-wide findings are old `info` level items:
  - `avoid_print`
  - one string interpolation style hint
  - API doc comment angle-bracket hints

### UI/content cleanup already done

- Home page rebuilt to the confirmed ticket-style structure.
- Home provider now adapts real backend data into the ticket-style cards, so feeding/todo/travel/finance/course panels no longer rely only on placeholder fallback fields.
- Home provider was rebuilt again on 2026-07-13 to remove a corrupted code path and to keep the homepage rendering even when part of the `/api/home/*` or bean endpoints fail.
- Home provider requests now use a short timeout guard so the homepage degrades to fallback content instead of hanging on an indefinite refresh.
- Weather compact card layout adjusted so `feels like` no longer fights with city text.
- Weather now falls back to default-city data even if location permission is permanently denied.
- Weather compact card width/height were widened again on 2026-07-12 so `体感温度` stays inside the header badge on small screens.
- Home error banner now sanitizes raw network exceptions at the UI layer, so `DioException` / `HttpException` text is no longer surfaced directly to the user.
- Home love-day display now prefers a clean anniversary-derived calculation, so the cold-start homepage no longer falls back to `1 天` when relationship data exists.
- Travel preview page Chinese text restored.
- Native AMap mode page mount/retry logic stabilized in code.
- Native AMap mode now filters invalid coordinates before building markers and polylines, reducing native map crashes caused by bad backend data.
- Native AMap mode now mounts the base map first and injects markers/routes only after the native controller is ready, reducing platform-view startup pressure.
- Native AMap mode now prewarms the location layer when permission already exists, and `定位到我` waits briefly for the first location fix instead of failing immediately with no blue dot.
- Native AMap marker info text no longer uses the stray `路` separator in spot subtitles.
- Native AMap mode now shows an explicit empty-map helper card when there are no points yet, so a black or empty map no longer feels like a dead end.
- Core feeding/map files were rewritten to UTF-8 without BOM on 2026-07-12 to reduce encoding noise across tools.
- Travel page AMap entry button now prevents repeat taps while the native map route is opening.
- Travel page AMap entry now diverts empty-state users into `新增地点` flow instead of dropping them into a blank native map.
- Core home/travel/feeding backend routes now have cleaner Chinese-facing fallback text, so the rebuilt UI is less likely to surface English placeholders or mojibake from API responses.
- Profile page rebuilt into a clean ticket-style Chinese version.
- Profile page love-day display now follows the same anniversary-derived source as the homepage.
- Profile page header / hero / archive card were pulled closer to the confirmed “关系资料夹” direction on 2026-07-14.
- Feeding page major visible status/category/header/order text restored to Chinese.
- Feeding page shop cards, product cards, and order sheet were further refined toward the approved menu-like ticket direction, and `lib/screens/feeding/feeding_screen.dart` passes standalone `flutter analyze`.
- Core travel UI files were rechecked after the latest cleanup, and `travel_main_screen.dart`, `travel_amap_mode_screen.dart`, and `travel_map_widget.dart` still pass standalone `flutter analyze`.
- The native AMap fallback error view no longer shows garbled Chinese if the platform map cannot initialize.
- Travel / Weather / Profile now write clearer failure logs for map-open failure, weather fallback failure, and profile data load failure, which should make the next real-device debug cycle easier to inspect.
- Widget tests now cover the confirmed home ticket layout anchors and the travel-page AMap entry transition into the placeholder state.
- Widget tests now also cover the feeding order-detail bottom sheet, including the ticket-style summary, real-platform info block, and core action labels.
- Widget tests now also cover the startup ticket boot screen while auth/session restoration is still in progress.
- Widget tests now also cover the login page Chinese copy, so auth entry text cleanup is protected against regressions.
- Home travel ticket side label is now Chinese (`旅行票根`) to stay aligned with the confirmed ticket-style visual direction.
- Home cold-start session handling is now hardened in `AuthProvider`: if `/api/user/profile` fails with a transient network error, the cached session stays alive instead of bouncing back to the login screen.
- Home narrow-layout rendering regression is now covered by a widget test, so the confirmed ticket homepage no longer collapses on small-width devices.
- Anniversary page was rebuilt into a clean Chinese version after the old file’s encoding broke the page-level text.
- Version update dialog was rebuilt into a clean Chinese version so the app no longer shows garbled update CTA text on startup.
- Home ticket layout was refined again on 2026-07-15:
  - the two-column threshold now stays closer to the confirmed reference on normal phone widths
  - the memory ticket now supports a proper preview panel / fallback panel instead of a flat placeholder block
  - the home travel ticket now uses a barcode rail and stronger ticket segmentation
  - the finance ticket now includes a compact chart preview instead of plain numbers only
- Profile hero was refined again on 2026-07-15 toward the confirmed “关系资料夹” direction:
  - archive pill on the left
  - bean pill on the right
  - stronger title hierarchy
  - status strip under the avatar/title block
- Travel preview page was refined again on 2026-07-15:
  - route preview now reads like a ticket block instead of a single summary line
  - route action buttons now wrap safely on narrow widths
  - travel progress stats now use a ticket-style progress card
  - spot cards now show better creator / date / note context
  - spot detail sheet now surfaces transportation / nearby / tips fields
  - the obvious AMap-entry mojibake strings in `travel_main_screen.dart` were fixed
- Feeding page was refined again on 2026-07-15:
  - order cards now use clean Chinese summary text instead of the broken total-price mojibake
  - order-role text is now relationship-specific (`我替她下的` / `她点给我的`) instead of the colder mixed wording
  - order detail bottom sheet is now wrapped in `SafeArea + SingleChildScrollView`, reducing overflow risk on smaller phones
  - order detail header now surfaces status and order-role pills, so the sheet feels closer to the confirmed ticket direction
  - order note presentation in the detail sheet is now cleaner and less form-like
- Home / Weather data layer was cleaned again on 2026-07-16:
  - `home_provider.dart` was rewritten into a clean UTF-8-safe source so fallback Chinese copy no longer risks surfacing mojibake on homepage cards
  - home fallback feed / todo / travel / course-related strings are now restored to clean Chinese
  - weather widget now has a local placeholder fallback path, so homepage weather is less likely to collapse into an error card when the default-city API stalls
  - weather widget now avoids emitting stale error logs after the widget has already been disposed, which keeps local verification output cleaner
- Startup chain was hardened again on 2026-07-16:
  - notification plugin initialization is now deferred until after the first frame instead of firing directly before `runApp()`
  - the auth bootstrap profile request now has a 6-second timeout guard, so cached sessions are less likely to get stuck behind a slow `/api/user/profile` call
  - the temporary cold-start loading state is now a ticket-style Chinese boot screen instead of a plain spinner
  - version update checks are now queued only after the user session is fully restored, so startup no longer schedules update UI over the boot/login transition
  - Android Impeller is now explicitly disabled in `AndroidManifest.xml` to prioritize compatibility on the current Android map / emulator stack
- Auth entry cleanup on 2026-07-16:
  - `login_screen.dart` was rebuilt into a clean Chinese version and the temporary debug `print` spam was removed

### Latest emulator evidence on 2026-07-13

- Homepage visual recheck after the latest provider cleanup:
  - `D:\lovegirl_flutter\tmp_home_after_button_fix.png`
  - Verified:
    - Chinese content is readable
    - weather card keeps `体感` inside the card
    - raw network exception text is replaced by a friendly banner
    - feeding CTA is back to `去看看`
- Homepage visual recheck after the love-day/date-source fix:
  - `D:\lovegirl_flutter\tmp_ui_home_postfix2.png`
  - Verified:
    - homepage now shows `1593 天` again instead of `1 天`
    - compact weather remains readable with `体感 34°`
- Travel preview visual recheck:
  - `D:\lovegirl_flutter\tmp_travel_preview_now.png`
  - Verified:
    - ticket-style layout is intact
    - CTA text and filter chips are readable
- Feeding page visual recheck:
  - `D:\lovegirl_flutter\tmp_feeding_page_check2.png`
  - Verified:
    - page-level Chinese text is readable
    - search field placeholder is clean
    - shop cards and action buttons match the ticket/menu direction
- Native AMap mode recheck:
  - `D:\lovegirl_flutter\tmp_amap_mode_opened.png`
  - Verified:
    - tapping `打开高德真地图` now opens the native map route on the emulator instead of bouncing back or crashing the Flutter page
  - Still blocked:
    - the map surface is black on the emulator because the current AMap native environment is not valid there
    - latest emulator logs still show repeated `GLMapEngine.nativeMainThreadTrigger` native errors
- Native AMap empty-state helper recheck:
  - `D:\lovegirl_flutter\tmp_amap_help_final.png`
  - Verified:
    - when there are no spots yet, the screen now explains what to do next
    - the helper gives a clear `回到预览` escape hatch when the native surface stays black
- Profile page visual recheck:
  - `D:\lovegirl_flutter\tmp_profile_ui_check.png`
  - Verified:
    - Chinese text is readable
    - ticket-style header and stats card render correctly

## Latest local verification on 2026-07-14

- `flutter analyze lib/providers/home_provider.dart lib/screens/home/home_screen.dart lib/widgets/weather_widget.dart lib/screens/travel/travel_main_screen.dart lib/screens/profile/profile_screen.dart lib/utils/lovegirl_dates.dart test/widget_test.dart`
- `flutter test test/widget_test.dart`
- `flutter build apk --debug`

Confirmed by current code + latest emulator pass:

- homepage love-day source and compact weather layout are improved
- travel empty-state entry no longer assumes native map should open immediately
- profile page is still in progress visually, but its love-day source is now aligned with homepage logic

## Latest local verification on 2026-07-15

- `flutter analyze test/widget_test.dart`
- `flutter analyze lib/screens/home/home_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/providers/home_provider.dart lib/utils/lovegirl_dates.dart lib/widgets/travel_map_widget.dart`
- `flutter analyze lib/screens/travel/travel_amap_mode_screen.dart test/widget_test.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- travel native-map mode now has an in-screen empty-state ticket fallback, even if the route is opened directly with zero spots
- the empty-state AMap fallback is now covered by a dedicated widget test
- home/profile Chinese fallback strings rechecked clean in source

## Latest local verification on 2026-07-15 (travel UI refinement pass)

- `flutter analyze lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/home/home_screen.dart lib/screens/profile/profile_screen.dart lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart test/widget_test.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- travel preview page still passes static checks after the latest ticket-style route / stats / spot-card refinements
- route action controls now avoid narrow-width compression by wrapping
- travel entry fallback copy is clean Chinese in source again
- widget tests still pass after the travel-page refinement pass

## Latest local verification on 2026-07-15 (feeding depth pass)

- `flutter analyze lib/screens/feeding/feeding_screen.dart`
- `flutter analyze lib/screens/feeding/feeding_screen.dart lib/screens/travel/travel_main_screen.dart lib/screens/home/home_screen.dart lib/screens/profile/profile_screen.dart test/widget_test.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- feeding page still passes static checks after the latest order-card and order-detail refinements
- the most obvious user-facing feeding mojibake in the order summary line has been removed
- widget tests still pass after the latest feeding-page work

## Latest local verification on 2026-07-16 (home/weather cleanup pass)

- `flutter analyze lib\widgets\weather_widget.dart lib\providers\home_provider.dart lib\screens\home\home_screen.dart lib\screens\travel\travel_main_screen.dart lib\screens\travel\travel_amap_mode_screen.dart lib\screens\feeding\feeding_screen.dart lib\screens\profile\profile_screen.dart test\widget_test.dart`
- `flutter test test\widget_test.dart`

Confirmed by current code:

- homepage provider fallback strings were cleaned without introducing new analyze errors
- weather widget still passes static analysis after adding the local placeholder fallback
- widget tests now pass without the previous weather-timeout error logs leaking after widget disposal

## Latest local verification on 2026-07-16 (full static pass)

- `flutter analyze`
- `flutter test test\widget_test.dart`

Confirmed by current code:

- project-wide analyze no longer reports any `error` or `warning` level issues
- remaining project-wide findings are `info` only
- one travel-ticket interpolation hint was cleaned up during this pass
- current remaining `info` items are still outside the main rebuilt UI acceptance path:
  - old `print` diagnostics in `login_screen.dart`
  - old `print` diagnostics in `api_service.dart`
  - one API doc-comment angle-bracket hint in `api_service.dart`

## Latest local verification on 2026-07-16 (feeding detail smoke coverage)

- `flutter analyze test/widget_test.dart lib/screens/feeding/feeding_screen.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- the feeding order-detail bottom sheet now has explicit widget coverage
- the ticket-style order summary still renders the expected Chinese relationship copy, platform info, and action labels
- the core rebuilt UI smoke suite is currently green at 6 passing widget tests
- the core rebuilt UI smoke suite is currently green at 8 passing widget tests

## Latest local verification on 2026-07-18 (UI consistency and map-surface pass)

- `flutter analyze lib/widgets/weather_widget.dart lib/widgets/travel_map_widget.dart lib/screens/travel/travel_main_screen.dart lib/screens/travel/travel_ticket_screen.dart`
- `flutter analyze lib/screens/home/home_screen.dart lib/screens/feeding/feeding_screen.dart lib/screens/anniversary/anniversary_screen.dart lib/screens/profile/profile_screen.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- travel ticket subtitle no longer shows the English `TRAVEL MEMOIR` copy
- travel route preview side label is now Chinese (`路线`)
- native AMap marker info subtitle separator was cleaned to a normal Chinese-facing dot separator
- compact weather card now gives `体感温度` its own line/chip area, reducing overflow risk in the homepage header
- homepage / feeding / anniversary / profile screens still pass targeted analysis after the latest cleanup
- widget smoke coverage remains green at 8 passing tests

Still not fully closed:

- the `打开高德真地图` flow is hardened in source, but final confidence still requires Android real-device verification

## Latest local verification on 2026-07-16 (startup hardening pass)

- `flutter analyze lib/main.dart lib/providers/auth_provider.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- deferring local-notification initialization did not introduce new analyze or widget-test regressions
- auth bootstrap now times out the profile request instead of waiting indefinitely
- the app now has a branded ticket-style boot screen during session restoration
- version update checks now wait until the authenticated shell is actually ready

## Latest local verification on 2026-07-16 (login Chinese cleanup pass)

- `flutter analyze lib/screens/auth/login_screen.dart test/widget_test.dart`
- `flutter test test/widget_test.dart`

Confirmed by current code:

- login page user-facing Chinese copy is now clean in source
- the temporary login debug prints were removed from `login_screen.dart`
- widget tests now cover the cleaned login entry copy

## Latest local verification on 2026-07-16 (runtime fallback + anniversary repair pass)

- `flutter analyze lib/screens/home/home_screen.dart lib/screens/travel/travel_amap_mode_screen.dart lib/screens/anniversary/anniversary_screen.dart lib/widgets/travel_map_widget.dart android/app/src/main/kotlin/com/lovegirl/lovegirl_flutter/MainActivity.kt`
- `flutter test test/widget_test.dart`
- `flutter build apk --debug --dart-define=LOVEGIRL_E2E_AUTO_LOGIN=true`
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`

Confirmed by current code + emulator screenshots:

- travel preview page still renders the confirmed ticket-style Chinese UI:
  - `D:\lovegirl_flutter\tmp_runtime_travel.png`
- tapping `打开高德真地图` on the x86_64 emulator no longer falls into a black native-map dead end; it now lands on an explicit unsupported-environment fallback with clear Chinese guidance:
  - `D:\lovegirl_flutter\tmp_runtime_amap_after.png`
- anniversary page was rebuilt into a stable Chinese ticket-style screen, and the runtime screenshot confirms the page opens without the previous mojibake crash state:
  - `D:\lovegirl_flutter\tmp_runtime_anniversary.png`
- anniversary runtime copy cleanup was re-verified after the final rebuild/install:
  - `D:\lovegirl_flutter\tmp_runtime_anniversary_clean.png`
  - verified:
    - hero card no longer shows the old English countdown copy
    - list card now shows `还剩 N 天`
    - page-level Chinese copy stays clean in runtime screenshots

## Latest emulator probe on 2026-07-16

- Earlier startup probe:
  - before launching the app, `adb shell echo ok` responded normally
  - after launching the app with the previous Android renderer path, the emulator shell became unresponsive and `qemu-system-x86_64` stopped responding
- Startup log capture was saved to:
  - `D:\lovegirl_flutter\tmp_emulator_startup_log.txt`
- Follow-up rendering probe:
  - `flutter run -d emulator-5554 --enable-software-rendering --verbose` originally failed with:
    - `Impeller does not support software rendering`
  - after disabling Android Impeller in `AndroidManifest.xml`, software-rendered startup reached:
    - VM Service connection
    - DevFS sync
    - Flutter app attachment
  - after the same Android-side change, a normal launch on `emulator-5554` also kept `adb shell` and `uiautomator dump` responsive
- Supporting artifacts:
  - `D:\lovegirl_flutter\tmp_flutter_run_soft_stdout.txt`
  - `D:\lovegirl_flutter\tmp_flutter_run_soft_stderr.txt`
  - `D:\lovegirl_flutter\tmp_emulator_live_ui.xml`
  - `D:\lovegirl_flutter\tmp_emulator_live.png`
- Current conclusion:
  - the previous emulator startup hang was strongly correlated with the Android renderer path rather than homepage Dart code alone
  - Android startup on the emulator is now materially healthier than before, but this is still not a substitute for real-device acceptance of the native AMap flow

## Release blockers before APK build

These items are still required before considering the UI work "ready to publish".

### P0: Real-device AMap verification

Must verify on an Android device:

Current status on 2026-07-13:

- Android emulator `emulator-5554` is available again and the current debug build opens the native AMap mode route without a Flutter crash.
- Emulator screenshots confirm:
  - cold launch lands on the rebuilt homepage instead of flashing back to the login screen
  - travel preview page renders correctly
  - tapping `打开高德真地图` enters the AMap mode screen
- Emulator still cannot be used as final AMap acceptance because the map surface stays black with native AMap errors:
  - `Key验证失败：[USERKEY_PLAT_NOMATCH]`
  - `UnsatisfiedLinkError ... GLMapEngine.nativeMainThreadTrigger`

Interpretation: the current blocker is now AMap environment compatibility on the emulator (Key / native ABI), not the previous Flutter-side route crash.

Useful local debug signature reference from this workspace:

- package name: `com.lovegirl.lovegirl_flutter`
- debug SHA1: `07:68:51:95:5C:55:C4:C7:19:17:26:9A:14:11:AE:9F:CE:99:F6:72`

1. Open app
2. Enter travel page
3. Tap `打开高德真地图`
4. Confirm:
   - no crash
   - map loads
   - current location button works
   - retry banner does not appear incorrectly after successful load
   - map can open/close repeatedly

If it still crashes, capture:

```powershell
adb logcat -c
adb logcat > lovegirl_amap_crash.txt
```

Then reproduce once and stop the log capture.

### P0: Core-page manual visual pass

Must inspect on device:

- Home page
  - Chinese text renders correctly
  - weather card does not overflow
  - icons and spacing match the ticket direction
- Feeding page
  - shop list text is readable
  - order list/status text is readable
  - order detail sheet text is readable
- Profile page
  - no mojibake
  - header, stats, menu rows align correctly
- Travel preview page
  - ticket layout reads correctly
  - buttons and chips do not overflow

## Recommended manual acceptance flow

### Home

- Pull to refresh
- Verify `恋爱天数`
- Verify weather renders
- Enter feeding page from home
- Enter timeline from home

### Feeding

- Open a shop
- Open a product
- Open order bottom sheet
- Confirm submit button text and totals are readable
- Open order list
- Open one order detail sheet
- Verify status actions read correctly

### Travel

- Open travel preview page
- Verify chips, labels, CTA
- Open AMap mode
- Tap location
- Tap fit-bounds if multiple points exist
- Long-press map and confirm snackbar text is readable

### Profile

- Pull to refresh
- Open settings
- Open timeline
- Open couple binding
- If admin account: open feeding admin

## Known non-blocking items

- Project still contains old `print` diagnostics outside the rebuilt UI scope, but the login screen copy/debug cleanup pass removed that category from `login_screen.dart`.
- Some non-core pages may still need later text cleanup.
- Cold launch may still show a location-permission dialog and an update dialog before the homepage becomes usable; the homepage itself now renders correctly behind those overlays.
- Server-provided changelog lines can still be English if the backend release note itself is written in English; the dialog shell and actions are now Chinese.
- Android Gradle Plugin is older than the current compileSdk target and emits warnings, but current debug compile checks still pass.

## Exit criteria before build

Do not build release APK until all are true:

- [ ] Core UI pages pass real-device visual check
- [ ] AMap mode does not crash on device
- [ ] Core flows are readable in Chinese
- [ ] No new `flutter analyze` errors
- [ ] Version number and update path are rechecked before packaging
