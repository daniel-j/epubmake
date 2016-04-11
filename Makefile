# Makefile by djazz

SOURCE=./src/
EPUBFILE=./build/ebook.epub
EPUBCHECK=../epubcheck-4.0.1/epubcheck.jar

SOURCEFILES=$(shell find $(SOURCE) -print)

.PHONY: clean validate build all
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

