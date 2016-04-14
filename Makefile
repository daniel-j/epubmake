
# Makefile by djazz

SOURCE=./src/
EPUBFILE=./build/ebook.epub
EPUBCHECK=../epubcheck-4.0.1/epubcheck.jar

SOURCEFILES=$(shell find $(SOURCE) -print)

.PHONY: clean validate build all extractcurrent watchcurrent
all: build

$(EPUBFILE): $(SOURCEFILES)
	@echo Building EPUB...
	@mkdir -p `dirname $(EPUBFILE)`
	@cd "$(SOURCE)" && zip -Xr9D "../$(EPUBFILE)" mimetype .

build: $(EPUBFILE)

validate: build
	@echo Validating EPUB...
	@java -jar "$(EPUBCHECK)" "$(EPUBFILE)"

clean:
	@echo Removing built EPUB...
	rm "$(EPUBFILE)"
	# only remove dir if it's empty:
	rmdir `dirname $(EPUBFILE)`

extractcurrent:
	@echo Extracting current.epub into "$(SOURCE)"
	@rm -rf "$(SOURCE)"
	@mkdir -p "$(SOURCE)"
	@cd "$(SOURCE)" && unzip ../current.epub

watchcurrent:
	@echo Watching current.epub
	@while true; do \
		inotifywait -qe close_write current.epub; \
		echo Validating current.epub...; \
		java -jar "$(EPUBCHECK)" current.epub; \
	done
