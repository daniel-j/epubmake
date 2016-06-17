
# EPUB Makefile helper by djazz
# https://github.com/daniel-j/epubmake
# Do not run this makefile's jobs in parallel/multicore (-j)


# you can modify these options
CURRENTEPUB = current.epub
SOURCE      = ./src/
EPUBFILE    = ./build/ebook.epub
KINDLEFILE  = ./build/ebook.mobi


SOURCEFILES = $(shell find $(SOURCE) -print)

EPUBCHECK = ./tools/epubcheck/epubcheck.jar
KINDLEGEN = ./tools/kindlegen/kindlegen

EBOOKPOLISH := $(shell command -v ebook-polish 2>&1)
EBOOKVIEWER := $(shell command -v ebook-viewer 2>&1)
JAVA        := $(shell command -v java 2>&1)
INOTIFYWAIT := $(shell command -v inotifywait 2>&1)

EPUBCHECK_VERSION = 4.0.1
# https://github.com/IDPF/epubcheck/releases
EPUBCHECK_URL = https://github.com/IDPF/epubcheck/releases/download/v$(EPUBCHECK_VERSION)/epubcheck-$(EPUBCHECK_VERSION).zip
# http://www.amazon.com/gp/feature.html?docId=1000765211
KINDLEGEN_URL = http://kindlegen.s3.amazonaws.com/kindlegen_linux_2.6_i386_v2_9.tar.gz


.PHONY: all clean validate build buildkindle extractcurrent watchcurrent release
all: build
release: clean build validate compress buildkindle

build: $(EPUBFILE)
$(EPUBFILE): $(SOURCEFILES)
	@echo "Building EPUB..."
	@mkdir -p `dirname $(EPUBFILE)`
	@rm -f "$(EPUBFILE)"
	@cd "$(SOURCE)" && zip -Xr9D "../$(EPUBFILE)" mimetype .

buildkindle: $(KINDLEFILE)
$(KINDLEFILE): $(EPUBFILE) $(KINDLEGEN)
	@echo Building Kindle file...
	@$(KINDLEGEN) "$(EPUBFILE)" -dont_append_source -c1 || exit 0 # -c1 means standard PalmDOC compression. -c2 takes too long but probably makes it even smaller.


$(EPUBCHECK):
	@echo Downloading epubcheck...
	@wget -O "epubcheck.zip" "$(EPUBCHECK_URL)" --quiet --show-progress
	@mkdir -p `dirname $(EPUBCHECK)`
	@unzip -q epubcheck.zip
	@rm -rf `dirname $(EPUBCHECK)`
	@mv "epubcheck-$(EPUBCHECK_VERSION)" "`dirname $(EPUBCHECK)`"
	@rm epubcheck.zip

$(KINDLEGEN):
	@echo Downloading kindlegen...
	@wget -O "kindlegen.tar.gz" "$(KINDLEGEN_URL)" --quiet --show-progress
	@mkdir -p `dirname $(KINDLEGEN)`
	@tar -zxf kindlegen.tar.gz -C `dirname $(KINDLEGEN)`
	@rm kindlegen.tar.gz


validate: $(EPUBFILE) $(EPUBCHECK)
ifndef JAVA
	@echo "Warning: Java was not found. Unable to validate ebook."
else
	@echo "Validating EPUB..."
	@$(JAVA) -jar "$(EPUBCHECK)" "$(EPUBFILE)"
endif


compress: $(EPUBFILE)
ifndef EBOOKPOLISH
	@echo "Warning: Calibre was not found. Skipping compression."
else
	@echo "Subsetting fonts and compressing images. This may take a while..."
	@ebook-polish --verbose --compress-images --subset-fonts "$(EPUBFILE)" "$(EPUBFILE)"
endif


view: $(EPUBFILE)
ifndef EBOOKVIEWER
	@echo "Warning: Calibre was not found. Unable to open ebook viewer."
else
	@ebook-viewer --detach "$(EPUBFILE)"
endif


clean:
	@echo Removing built EPUB...
	rm -f "$(EPUBFILE)"
	rm -f "$(KINDLEFILE)"
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
