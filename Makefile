DIST_FILE=rpz-misc.tar.gz
#
# Currently assuming OSX, fix this.
#
SHA256=sha256sum
VSN_DATE=20150910
VSN_HASH=$(shell git rev-parse HEAD)

all: dest/bin/nightly-setup

clean:
	@rm -rf dest/

dest/bin:
	@mkdir -p dest/bin

dest/bin/nightly-setup: src/illumos/nightly-setup.sh dest/bin
	@sed -e "s/@VSN_HASH@/$(VSN_HASH)/" \
		-e "s/@VSN_DATE@/$(VSN_DATE)/" $< > $@
	@chmod a+x $@

dist: all
	@ln -s ./dest ./rpz-misc
	@tar -cHzf dest/$(DIST_FILE) --exclude '*.gz' ./rpz-misc
	@rm -f ./rpz-misc
	@cd dest && $(SHA256) $(DIST_FILE) > $(DIST_FILE).sha256
