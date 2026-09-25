# PUAE fork maintenance

`retrom-fork.json` fixes the upstream core and RetroArch linker commits, adapter ABI and release assets. Keep `master` as the upstream mirror. Develop Retrom changes on `fix/*`, `feat/*` or `build/*` branches from `retrom/g2245d3443cc1`, then merge by PR into that maintenance branch.

Run the pinned browser candidate build and compare the complete archive bytes across two builds. Verify a real CD32 game in Retrom Review Preview and Product Launch, including controls, save and a new Launch restore. Release only annotated, immutable `retrom-core-g2245d3443cc1-rN` tags from commits merged into the maintenance branch. Do not commit games, BIOS, toolchains or built core assets.
