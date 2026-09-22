# HTTrack Website Copier - Development Repository

> **Private fork.** This is `sparktron/HTTrackClone`, a private fork of [xroche/httrack](https://github.com/xroche/httrack), currently synced to upstream 3.50.3. It adds https certificate verification and an opt-in imageboard catalog (`--enable-imageboard-catalog`), and is not the official HTTrack repository. Report issues and send changes here, not upstream. Upstream fixes are merged in periodically; see [AGENTS.md](AGENTS.md).

## About
_Copy websites to your computer (Offline browser)_

<img src="https://www.httrack.com/htsw/screenshot_w1.jpg" width="34%">

*HTTrack* is an _offline browser_ utility, allowing you to download a World Wide website from the Internet to a local directory, building recursively all directories, getting html, images, and other files from the server to your computer.
 
*HTTrack* arranges the original site's relative link-structure. Simply open a page of the "mirrored" website in your browser, and you can browse the site from link to link, as if you were viewing it online.

HTTrack can also update an existing mirrored site, and resume interrupted downloads. HTTrack is fully configurable, and has an integrated help system.

*WinHTTrack* is the Windows front end and *WebHTTrack* the one for Linux, BSD and macOS, where it also arrives with `brew install httrack` and in the release DMG. There is an [Android app](https://play.google.com/store/apps/details?id=com.httrack.android) too, and underneath all of them the `httrack` command line.

## Website

*Main Website:*
https://www.httrack.com/

## Compile trunk release

A git checkout ships only the autotools sources, so `./bootstrap` (which runs
`autoreconf`) regenerates `configure` first; this needs autoconf, automake and
libtool. Released tarballs already include `configure`, so building from a
tarball skips `./bootstrap`.

```sh
git clone https://github.com/sparktron/HTTrackClone.git --recurse-submodules
cd HTTrackClone
./bootstrap
./configure --prefix=$HOME/usr && make -j8 && make install
```

Or use the one-shot wrapper (bootstrap + configure + make), which forwards its
arguments to `configure`:

```sh
./build.sh --prefix=$HOME/usr
```
