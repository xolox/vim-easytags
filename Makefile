PROJECT=easytags
VIMDOC := $(shell mktemp -u)
ZIPFILE := $(shell mktemp -u)
ZIPDIR := $(shell mktemp -d)
DEPENDS=autoload/xolox.vim \
		autoload/xolox/escape.vim \
		autoload/xolox/timer.vim \
		autoload/xolox/option.vim

# NOTE: Make does NOT expand the following back ticks!
VERSION=`grep '^" Version:' $(PROJECT).vim | awk '{print $$3}'`

# The main rule builds a ZIP that can be published to http://www.vim.org.
archive: Makefile $(PROJECT).vim autoload.vim README.md
	@echo "Creating \`$(PROJECT).txt' .."
	@mkd2vimdoc.py $(PROJECT).txt < README.md > $(VIMDOC)
	@echo "Creating \`$(PROJECT)-$(VERSION).zip' .."
	@mkdir -p $(ZIPDIR)/plugin $(ZIPDIR)/autoload/xolox $(ZIPDIR)/doc
	@cp $(PROJECT).vim $(ZIPDIR)/plugin
	@cp autoload.vim $(ZIPDIR)/autoload/$(PROJECT).vim
	@for SCRIPT in $(DEPENDS); do cp $$HOME/.vim/$$SCRIPT $(ZIPDIR)/$$SCRIPT; done
	@cp $(VIMDOC) $(ZIPDIR)/doc/$(PROJECT).txt
	@cd $(ZIPDIR) && zip -r $(ZIPFILE) . >/dev/null
	@rm -R $(ZIPDIR)
	@mv $(ZIPFILE) $(PROJECT)-$(VERSION).zip
