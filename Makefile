
# EPUB Makefile helper by djazz
# https://github.com/daniel-j/epubmake
# Do NOT run this makefile's jobs in parallel (-j)

RELEASENAME := "Ebook %y%m%d"

# you can modify these options
CURRENTEPUB := current.epub
SOURCE      := ./src/
EPUBFILE    := ./build/ebook.epub
IBOOKSFILE  := ./build/ebook-ibooks.epub
KEPUBFILE   := ./build/ebook.kepub.epub
KINDLEFILE  := ./build/ebook.mobi
AZW3FILE    := ./build/ebook.azw3


SHELL := /bin/bash
SOURCEFILES := $(shell find $(SOURCE) 2> /dev/null | sort)
XHTMLFILES  := $(shell find $(SOURCE) -name '*.xhtml' 2> /dev/null | sort)
PNGFILES    := $(shell find $(SOURCE) -name '*.png' 2> /dev/null | sort)

EPUBCHECK := ./tools/epubcheck/epubcheck.jar
KINDLEGEN := ./tools/kindlegen/kindlegen

EBOOKPOLISH  := $(shell command -v ebook-polish 2>&1)
EBOOKVIEWER  := $(shell command -v ebook-viewer 2>&1)
EBOOKCONVERT := $(shell command -v ebook-convert 2>&1)
JAVA         := $(shell command -v java 2>&1)
INOTIFYWAIT  := $(shell command -v inotifywait 2>&1)

EPUBCHECK_VERSION = 4.0.2
# https://github.com/IDPF/epubcheck/releases
EPUBCHECK_URL = https://github.com/IDPF/epubcheck/releases/download/v$(EPUBCHECK_VERSION)/epubcheck-$(EPUBCHECK_VERSION).zip
# http://www.amazon.com/gp/feature.html?docId=1000765211
KINDLEGEN_URL = http://kindlegen.s3.amazonaws.com/kindlegen_linux_2.6_i386_v2_9.tar.gz


.PHONY: all clean init validate build buildkepub buildkindle buildibooks buildazw3 extractcurrent watchcurrent release
all: build

# initializes the src directory
init: src/
src/:
	@mkdir -pv src/{META-INF,OEBPS}
	@echo -n "application/epub+zip" > src/mimetype
	@echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n  <rootfiles>\n    <rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/>\n  </rootfiles>\n</container>" > src/META-INF/container.xml
	@touch src/OEBPS/content.opf

build: $(EPUBFILE)
$(EPUBFILE): $(SOURCEFILES)
	@echo "Building EPUB ebook..."
	@mkdir -p `dirname $(EPUBFILE)`
	@rm -f "$(EPUBFILE)"
	@cd "$(SOURCE)" && zip -Xr9D "../$(EPUBFILE)" mimetype .

# For Kobo devices
buildkepub: $(KEPUBFILE)
$(KEPUBFILE): $(EPUBFILE) $(SOURCEFILES)
	@echo "Building Kobo EPUB ebook..."
	@cp -f "$(EPUBFILE)" "$(KEPUBFILE)"
	@for current in $(XHTMLFILES); do \
		mkdir -p "$$(dirname "tmp/$$current")"; \
		echo "Kepubifying $$current..."; \
		./tools/kepubify.py "$$current" > "tmp/$$current"; \
	done
	@cd "tmp/$(SOURCE)" && zip -Xr9D "../../$(KEPUBFILE)" .
	@rm -rf "tmp/"

# this uses Amazon's KindleGen utility. If you want smaller
# Kindle ebook files, try buildazw3, which uses Calibre's
# ebook-convert tool.
buildkindle: $(KINDLEFILE)
$(KINDLEFILE): $(EPUBFILE) $(KINDLEGEN)
	@echo "Building Kindle ebook with KindleGen..."
	@cp -f "$(EPUBFILE)" "$(KINDLEFILE).epub"
ifdef PNGFILES
	@for current in $(PNGFILES); do \
		channels=$$(identify -format '%[channels]' "$$current"); \
		if [[ "$$channels" == "graya" ]]; then \
			mkdir -p "$$(dirname "tmp/$$current")"; \
			echo "Converting $$current to RGB..."; \
			convert "$$current" -colorspace rgb "tmp/$$current"; \
		fi; \
	done
	@cd "tmp/$(SOURCE)" && zip -Xr9D "../../$(KINDLEFILE).epub" .
	@rm -rf "tmp/"
endif
	@$(KINDLEGEN) "$(KINDLEFILE).epub" -dont_append_source -c1 || exit 0 # -c1 means standard PalmDOC compression. -c2 takes too long but probably makes it even smaller.
	@rm -f "$(KINDLEFILE).epub"
	@mv "$(KINDLEFILE).mobi" "$(KINDLEFILE)"

# Use Calibre to generate a Kindle ebook.
buildazw3: $(AZW3FILE)
$(AZW3FILE): $(EPUBFILE)
ifndef EBOOKCONVERT
	@echo "Error: Calibre was not found. Unable to convert to Kindle AZW3."
	@exit 1
else
	@echo "Building Kindle AZW3 ebook with Calibre..."
	ebook-convert "$(EPUBFILE)" "$(AZW3FILE)" --pretty-print --no-inline-toc --max-toc-links=0 --disable-font-rescaling
endif

# Fix for iBooks ToC on some devices. Requires Sigil.
buildibooks: $(IBOOKSFILE)
$(IBOOKSFILE): $(SOURCEFILES)
	@echo "Building iBooks EPUB ebook..."
	@tools/run-sigil-plugin.sh tools/iBooksFix-sigil-plugin.py ./src "$(IBOOKSFILE)"


$(EPUBCHECK):
	@echo Downloading epubcheck...
	@curl -o "epubcheck.zip" -L "$(EPUBCHECK_URL)" --connect-timeout 30
	@mkdir -p `dirname $(EPUBCHECK)`
	@unzip -q "epubcheck.zip"
	@rm -rf `dirname $(EPUBCHECK)`
	@mv "epubcheck-$(EPUBCHECK_VERSION)" "`dirname $(EPUBCHECK)`"
	@rm epubcheck.zip

$(KINDLEGEN):
	@echo Downloading kindlegen...
	@curl -o "kindlegen.tar.gz" -L "$(KINDLEGEN_URL)" --connect-timeout 30
	@mkdir -p `dirname $(KINDLEGEN)`
	@tar -zxf "kindlegen.tar.gz" -C `dirname $(KINDLEGEN)`
	@rm "kindlegen.tar.gz"


validate: $(EPUBFILE) $(EPUBCHECK)
ifndef JAVA
	@echo "Warning: Java was not found. Unable to validate ebook."
else
	@echo "Validating EPUB..."
	@$(JAVA) -jar "$(EPUBCHECK)" "$(EPUBFILE)"
endif


optimize: $(EPUBFILE)
ifndef EBOOKPOLISH
	@echo "Error: Calibre was not found. Unable to optimize."
	@exit 1
else
	@echo "Compressing images. This may take a while..."
	@ebook-polish --verbose --compress-images "$(EPUBFILE)" "$(EPUBFILE)"
endif


view: $(EPUBFILE)
ifndef EBOOKVIEWER
	@echo "Error: Calibre was not found. Unable to open ebook viewer."
	@exit 1
else
	@ebook-viewer --detach "$(EPUBFILE)"
endif


clean:
	@echo Removing built EPUB/KEPUB/Kindle files...
	rm -f "$(EPUBFILE)"
	rm -f "$(KEPUBFILE)"
	rm -f "$(KINDLEFILE)"
	rm -f "$(AZW3FILE)"
	rm -f "$(IBOOKSFILE)"
	@# only remove dir if it's empty:
	@(rmdir `dirname $(EPUBFILE)`; exit 0)


extractcurrent: $(CURRENTEPUB)
	@echo "Extracting $(CURRENTEPUB) into $(SOURCE)"
	@rm -rf "$(SOURCE)"
	@mkdir -p "$(SOURCE)"
	@unzip "$(CURRENTEPUB)" -d "$(SOURCE)"

watchcurrent: $(CURRENTEPUB) $(EPUBCHECK)
ifndef JAVA
	$(error Java was not found. Unable to validate ebook)
endif
ifndef INOTIFYWAIT
	$(error inotifywait was not found. Unable to watch ebook for changes)
endif
	@echo "Watching $(CURRENTEPUB)"
	@while true; do \
		$(INOTIFYWAIT) -qe close_write "$(CURRENTEPUB)"; \
		echo "Validating $(CURRENTEPUB)..."; \
		$(JAVA) -jar "$(EPUBCHECK)" "$(CURRENTEPUB)"; \
	done

release: $(EPUBFILE) $(KINDLEFILE) $(KEPUBFILE) $(AZW3FILE)
	@mkdir -pv release
	cp "$(EPUBFILE)" "release/$$(date +$(RELEASENAME)).epub"
	cp "$(KEPUBFILE)" "release/$$(date +$(RELEASENAME)).kepub.epub"
	cp "$(KINDLEFILE)" "release/$$(date +$(RELEASENAME)).mobi"
	cp "$(AZW3FILE)" "release/$$(date +$(RELEASENAME)).azw3"
