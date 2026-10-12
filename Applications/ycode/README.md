# apps-ycode

Xcode like application which combines the capabilities of gorm and projectecenter.  It's primary purpose
is to provide an interface analogous to Xcode so that we can have a more modern development IDE where 
all of the development happens in one place.  This will also help to unify our approach to dealing with
certain types of interfaces which Gorm can't easily deal with.

Build the local libs-xcode framework and Ycode from the repository root:

```sh
make -C XCode
make -C Applications/ycode
```

Use **File > Open Project...** to select an `.xcodeproj` package. Ycode loads
its `project.pbxproj` through libs-xcode and displays its groups, files, and
targets in the project navigator. Missing or invalid project contents produce
an error instead of opening an empty project. ProjectCenter `.pcproj` packages
remain supported.

Ycode starts without creating an untitled project. On GNUstep, the main menu
uses Info for About, Preferences, and Help, with Services, Hide, and Quit at
the top level. Build and run commands are in Project; window commands are in
Windows. The editor rulers show character columns across the top and source
line numbers down the side, following the font size and scroll position.

Run the application regression checks with a working GUI display (or under
`xvfb-run -a` on a headless GNUstep system):

```sh
make -C Applications/ycode/Tests check
```
