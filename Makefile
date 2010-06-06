DEPENDS=autoload/xolox.vim \
		autoload/xolox/escape.vim \
		autoload/xolox/timer.vim
VIMDOC=doc/easytags.txt
HTMLDOC=doc/readme.html
ZIPDIR := $(shell mktemp -d)
ZIPFILE := $(shell mktemp -u)

# NOTE: Make does NOT expand the following back ticks!
VERSION=`grep '^" Version:' easytags.vim | awk '{print $$3}'`

# The main rule builds a ZIP that can be published to http://www.vim.org.
archive: Makefile easytags.vim autoload.vim $(VIMDOC) $(HTMLDOC)
	@echo "Creating \`easytags-$(VERSION).zip' .."
	@mkdir -p $(ZIPDIR)/plugin $(ZIPDIR)/autoload/xolox $(ZIPDIR)/doc
	@cp easytags.vim $(ZIPDIR)/plugin
	@cp autoload.vim $(ZIPDIR)/autoload/easytags.vim
	@for SCRIPT in $(DEPENDS); do cp $$HOME/.vim/$$SCRIPT $(ZIPDIR)/$$SCRIPT; done
	@cp $(VIMDOC) $(ZIPDIR)/doc/easytags.txt
	@cp $(HTMLDOC) $(ZIPDIR)/doc/easytags.html
	@cd $(ZIPDIR) && zip -r $(ZIPFILE) . >/dev/null
	@rm -R $(ZIPDIR)
	@mv $(ZIPFILE) easytags-$(VERSION).zip

# This rule converts the Markdown README to Vim documentation.
$(VIMDOC): Makefile README.md
	@echo "Creating \`$(VIMDOC)' .."
	@mkd2vimdoc.py `basename $(VIMDOC)` < README.md > $(VIMDOC)

# This rule converts the Markdown README to HTML, which reads easier.
$(HTMLDOC): Makefile README.md doc/README.header doc/README.footer
	@echo "Creating \`$(HTMLDOC)' .."
	@cat doc/README.header > $(HTMLDOC)
	@cat README.md | markdown | SmartyPants >> $(HTMLDOC)
	@cat doc/README.footer >> $(HTMLDOC)

# This is only useful for myself, it uploads the latest README to my website.
web: $(HTMLDOC)
	@echo "Uploading homepage .."
	@scp -q $(HTMLDOC) vps:/home/peterodding.com/public/files/code/vim/easytags/index.html

all: archive web
