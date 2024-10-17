export ACM_VERSION?=2.12
export MCE_VERSION?=2.7

SED_CMD:=sed
ifeq ($(GOHOSTOS),darwin)
	SED_CMD:=gsed
endif

export SED=$(SED_CMD)

HELM?=_output/bin/helm
HELM_VERSION?=v3.14.0
helm_gen_dir:=$(dir $(HELM))


HELM_ARCHOS:=$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m)
ifeq ($(GOHOSTOS),darwin)
	ifeq ($(GOHOSTARCH),amd64)
		OPERATOR_SDK_ARCHOS:=darwin_amd64
		HELM_ARCHOS:=darwin-amd64
	endif
	ifeq ($(GOHOSTARCH),arm64)
		OPERATOR_SDK_ARCHOS:=darwin_arm64
		HELM_ARCHOS:=darwin-arm64
	endif
endif


update:
	hack/update.sh

install-mce: ensure-helm
	$(HELM) upgrade --install mce ./e2e/mce-chart

install-policy: ensure-helm
	$(HELM) upgrade --install policy ./policy

e2e-install:
	hack/e2e-install.sh

e2e-import-cluster:
	hack/e2e-import-cluster.sh

ensure-helm:
ifeq "" "$(wildcard $(HELM))"
	$(info Installing helm into '$(HELM)')
	mkdir -p '$(helm_gen_dir)'
	HELM_INSTALL_DIR=${helm_gen_dir} hack/get-helm.sh --version $(HELM_VERSION) --no-sudo
	chmod +x '$(HELM)';
else
	$(info Using existing helm from "$(HELM)")
endif
