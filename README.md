# EPUB Makefile helper

I created this tool as a companion to when I edit the epub in Sigil, but you can use any editor/toolchain. You can use this Makefile and create a local git repo and keep your ebook in version control.


## How to use

Make sure you have the `make` command and python3 with lxml installed available. You also need `java` to be able to validate the ebook with [EpubCheck](https://github.com/idpf/epubcheck), `inotifywait` from inotify-tools and [Calibre](http://calibre-ebook.com/) for the tools `ebook-polish` and `ebook-view`.
 - Copy your epub ebook and put it next to the Makefile and rename it to `current.epub`. This is a hardcoded name that the tool uses to read the book from.
 - Open a terminal and run `make extractcurrent`. This will populate `src/` with the contents of the ebook using `unzip`.
 - You can now validate the ebook. Run `make validate`. It first builds the epub into `build/` based on the contents of `src/` (same as `make build`). Then it downloads EpubCheck (only first time) and runs it on the ebook.
 - You can open the built ebook in Calibre's viewer with `make view`.
 - You can export a Kindle ebook by running `make buildkindle`. This will on first run download [KindleGen](http://www.amazon.com/gp/feature.html?docId=1000765211) (Linux version only). KindleGen might output some helpful warnings on how you can improve the epub file. By default the Makefile uses KindleGen's `-c1` compression, but you can change that if you want.
 - Open up `current.epub` in your epub editor. Run `make watchcurrent`. The tool will now wait until you save the file. When you do it will run the validator on it. It's quite useful to spot errors or warnings as you edit the epub. When you're done, run `make extractcurrent` and the `src/` is updated. This will overwrite everything in `src/`.
 - You can compress the built epub file with `make compress`. This uses `calibre-polish` and its tools lossless image compression and font subsetting (removing unused glyphs). You can run `make release` to validate, compress the epub and build the kindle ebook.

You're welcome to look at the Makefile to understand what it does and how it works.


## Version control

You can clone this repository and add your own ebook as `current.epub`. Then run `make extractcurrent` and `make build`. Make it a habit to run `make validate` before you publish or use the built ebook.

Create a new git repository and commit your book. With every new release of the book you can also tag it with either version numbers or current date. This is so you later can go back and look at the difference between revisions.

