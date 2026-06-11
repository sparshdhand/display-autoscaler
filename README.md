# Imagine if all of these monitor projecting could become easier

Seriously, plug-and-play is a total lie. 

## The Struggles of Modern Displays (Why everything is currently broken)

We’ve all been there. You walk into a classroom, a meeting room, or some random co-working space, and you just want to show your screen. Sounds simple, right? Wrong. 

Here is what actually happens:

1. **The "No Signal" Ghost Town:** You plug the HDMI cable into your Mac. *Nothing happens.* The TV is black. Your laptop is acting like nothing happened. You unplug it, blow on it like an old Nintendo cartridge, plug it back in... still nothing. You have to awkwardly go into settings, hold Option, and click some hidden "Detect Displays" button. Meanwhile, everyone is staring at you waiting for the presentation to start.
2. **The Blurry-Text Headache:** You finally get a picture, but it looks like you forgot to put your glasses on. The text is so blurry and fuzzy because macOS decides your beautiful 4K TV or nice 1440p monitor only deserves standard low-res scaling (LoDPI). Trying to read code or slides on it makes your eyes bleed.
3. **The Squished-Screen Nightmare:** You plug into a projector, and suddenly your circular diagrams look like squashed eggs. The aspect ratio is completely messed up, stretching your screen horizontally because macOS just guessed the wrong dimensions.
4. **The Mirroring Drag:** You just want to mirror your screen so you can look at your laptop while presenting. Instead, macOS extends the desktop, and you have to awkwardly drag your slides off the side of your screen while looking backward at the TV.
5. **The Black Screen Crash:** You try to set a high resolution, and the old school projector just gives up and displays "Out of Range" or goes completely black. 

---

## What This Utility Actually Does (The Fix)

I built a tiny, silent background app (`display-autoscaler`) that runs on your Mac and fixes all this junk automatically. 

Here is what it does for you:

* **Auto-Probing (The Zero-Effort Connection):** It runs a background scanner every 10 seconds. If you plug in an HDMI cable and the TV does not wake up, the app forces the graphics card to send a hardware pulse down the cable. No more unplugging and replugging. It just wakes the TV up for you.
* **Aspect-Ratio Matching:** It checks the exact shape of the connected screen (widescreen, square, whatever) and automatically selects the highest resolution matching that *exact* ratio. No more stretched, squished, or warped presentations.
* **Force HiDPI (Retina Scaling):** It bypasses Apple's default filters to unlock hidden Retina scaling profiles. You get ultra-sharp, crisp 5K-rendered text on normal 4K or 1440p external screens.
* **Graceful Fallbacks:** If a high-res setting fails or the projector can't handle it, the app detects the error and instantly falls back to a safe baseline (like standard 1080p) so you *always* get a picture.
* **Automatic Mirroring:** It automatically turns on mirroring when you connect to a TV or projector so your presentation is instantly visible on both screens.
* **Desktop Diagnostics:** Every time you connect a display, it dumps a super simple text file on your desktop (`display-diagnostic-report.txt`) showing exactly what displays are active, what resolution is applied, and troubleshooting tips.

Now, you just plug in the cable, wait a few seconds, and it just works. No settings, no menus, no panic.
