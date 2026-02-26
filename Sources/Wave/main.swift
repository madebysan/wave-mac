import Cocoa

// Wave — menu bar voice-to-text app.
// No sandbox (needs accessibility API for paste simulation),
// runs as LSUIElement (no dock icon).

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
