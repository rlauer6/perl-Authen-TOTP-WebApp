all: docker.log

install.pl: ../install.pl
	cp $< $@

requirements.txt: ../requirements.txt
	cp $< $@

APPFILES := $(shell ../install.pl -m ../manifest.json list | perl -ne 'print "../$$_"')

authen-totp-webapp.tar.gz: $(APPFILES)
	builddir=$$(pwd); \
	cd ..; \
	./install.pl -t $$builddir/$@ package; \
	cd $$builddir


DEPS = \
    Dockerfile \
    requirements.txt \
    install.pl \
    authen-totp-webapp.tar.gz

docker.log: $(DEPS)
	docker build . -t authen-totp-webapp 2>&1 | tee docker.log
