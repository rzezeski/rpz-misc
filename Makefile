VSN_HASH=$(shell git rev-parse HEAD)

all: bin/nightly-setup

clean:
	@rm -rf bin/

bin:
	@mkdir bin

bin/nightly-setup: src/illumos/nightly-setup.sh bin
	@sed "s/@VSN_HASH@/$(VSN_HASH)/" $< > $@
	@chmod a+x $@
