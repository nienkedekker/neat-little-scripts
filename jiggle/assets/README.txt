Jiggle — macOS menu bar template images (concept 2a, "tapering trail")

FILES
  JiggleTemplate.svg / .png / @2x.png / @3x.png        idle — app running, not jiggling
  JiggleActiveTemplate.svg / .png / @2x.png / @3x.png  active — currently jiggling

XCODE
  Add each PNG set to an Image Set in Assets.xcassets (1x/2x/3x slots).
  Set "Render As: Template Image" on both image sets.
  In code: NSImage(named:"JiggleTemplate")!.isTemplate = true
  statusItem.button?.image = <idle or active image>

SPECS
  18x18pt canvas, 22pt menu bar slot. Pure #000 on transparent; alpha channel only.
  Idle: 2 shapes (cursor + one crumb). Active: 4 shapes (cursor + 3 crumbs).
  Smallest element 1.6pt diameter at 1x; cursor tail 2.2pt.

METAPHOR
  The cursor leaves crumbs. Idle there is a single dot parked behind it — proof of
  one nudge, at rest. Active, the trail extends to three, tapering off like footsteps
  walking away: something small has been moving here on your behalf while you read.
  At 18px the read is mass and count in the otherwise empty lower-left quadrant —
  circles are the last shape to blur, and no stroke gets thinner than 1.6pt.
