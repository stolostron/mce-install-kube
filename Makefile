export ACM_VERSION?=2.12

HELM?=_output/bin/helm
HELM_VERSION?=v3.14.0
helm_gen_dir:=$(dir $(HELM))


HELM_ARCHOS:=linux-amd64
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
	$(HELM) install mce ./e2e/mce-chart

install-policy: ensure-helm
	$(HELM) install policy ./policy

test-e2e: 
	hack/e2e.sh

ensure-helm:
ifeq "" "$(wildcard $(HELM))"
	$(info Installing helm into '$(HELM)')
	mkdir -p '$(helm_gen_dir)'
	curl -s -f -L https://get.helm.sh/helm-$(HELM_VERSION)-$(HELM_ARCHOS).tar.gz -o '$(helm_gen_dir)$(HELM_VERSION)-$(HELM_ARCHOS).tar.gz'
	tar -zvxf '$(helm_gen_dir)/$(HELM_VERSION)-$(HELM_ARCHOS).tar.gz' -C $(helm_gen_dir)
	mv $(helm_gen_dir)/$(HELM_ARCHOS)/helm $(HELM)
	rm -rf $(helm_gen_dir)/$(HELM_ARCHOS)
	chmod +x '$(HELM)';
else
	$(info Using existing helm from "$(HELM)")
endif
