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
	@tar -cHzf dest/rpz-misc-$(VSN_DATE).tar.gz --exclude '*.gz' ./rpz-misc
	@rm -f ./rpz-misc
