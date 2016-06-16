
# EPUB Makefile helper by djazz
# https://gist.github.com/daniel-j/bc8a654673a7744607813b629c342792

SOURCE=./src/
EPUBFILE=./build/ebook.epub
KINDLEFILE=./build/ebook.mobi

EPUBCHECK=./tools/epubcheck/epubcheck.jar
KINDLEGEN=./tools/kindlegen/kindlegen

EPUBCHECK_VERSION=4.0.1
# https://github.com/IDPF/epubcheck/releases
EPUBCHECK_URL=https://github.com/IDPF/epubcheck/releases/download/v$(EPUBCHECK_VERSION)/epubcheck-$(EPUBCHECK_VERSION).zip
# http://www.amazon.com/gp/feature.html?docId=1000765211
KINDLEGEN_URL=http://kindlegen.s3.amazonaws.com/kindlegen_linux_2.6_i386_v2_9.tar.gz

SOURCEFILES=$(shell find $(SOURCE) -print)

.PHONY: all clean validate build buildkindle extractcurrent watchcurrent
all: build

build: $(EPUBFILE)
$(EPUBFILE): $(SOURCEFILES)
	@echo Building EPUB...
	@mkdir -p `dirname $(EPUBFILE)`
	@cd "$(SOURCE)" && zip -Xr9D "../$(EPUBFILE)" mimetype .

buildkindle: $(KINDLEFILE)
$(KINDLEFILE): $(EPUBFILE) $(KINDLEGEN)
	@echo Building Kindle file...
	@"$(KINDLEGEN)" "$(EPUBFILE)" -dont_append_source -c1 || exit 0 # -c1 means DOC compression. -c2 takes too long

# tools
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
	@type java >/dev/null 2>&1 || (echo "Java is not installed" && exit 1)
	@echo Validating EPUB...
	@java -jar "$(EPUBCHECK)" "$(EPUBFILE)"

clean:
	@echo Removing built EPUB...
	rm -f "$(EPUBFILE)"
	rm -f "$(KINDLEFILE)"
	# only remove dir if it's empty:
	rmdir `dirname $(EPUBFILE)`

extractcurrent: current.epub
	@echo Extracting current.epub into "$(SOURCE)"
	@rm -rf "$(SOURCE)"
	@mkdir -p "$(SOURCE)"
	@unzip current.epub -d "$(SOURCE)"

watchcurrent: current.epub $(EPUBCHECK)
	@type java >/dev/null 2>&1 || (echo "Java is not installed" && exit 1)
	@type inotifywait >/dev/null 2>&1 || (echo "inotifywait is not installed, try install inotify-tools" && exit 1)
	@echo Watching current.epub
	@while true; do \
		inotifywait -qe close_write current.epub; \
		echo Validating current.epub...; \
		java -jar "$(EPUBCHECK)" current.epub; \
	done
