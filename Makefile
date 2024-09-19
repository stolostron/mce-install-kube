export ACM_VERSION?=2.12


.PHONY: update

update:	
	hack/update.sh


install:
	hack/install.sh
