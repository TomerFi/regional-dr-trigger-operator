# Copyright (c) 2023 Red Hat, Inc.

##########################################
###### Regional DR Trigger Operator ######
##########################################
default: help

OPERATOR_TARGET_NAMESPACE ?= regional-dr-trigger##@ Set the target namespace for deploying the operator, defaults to 'regional-dr-trigger'

##########################################################
###### Create working directories (note .gitignore) ######
##########################################################
LOCALBIN = $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

LOCALBUILD = $(shell pwd)/build
$(LOCALBUILD):
	mkdir -p $(LOCALBUILD)

#####################################
###### Image related variables ######
#####################################
IMAGE_BUILDER ?= podman##@ Set a custom image builder if 'podman' is not available
IMAGE_REGISTRY ?= quay.io##@ Set the image registry, defaults to 'quay.io'
IMAGE_NAMESPACE ?= ecosystem-appeng##@ Set the image namespace, defaults to 'ecosystem-appeng'
IMAGE_NAME ?= regional-dr-trigger-operator##@ Set the operator image name, defaults to 'regional-dr-trigger-operator'
IMAGE_TAG ?= $(strip $(shell cat VERSION))##@ Set the operator image tag, defaults to content of the VERSION file

######################################
###### Bundle related variables ######
######################################
BUNDLE_PACKAGE_NAME ?= $(IMAGE_NAME)##@ Set the bundle package name, defaults to IMAGE_NAME
BUNDLE_CHANNELS ?= alpha##@ Set a comma-seperated list of channels the bundle belongs too, defaults to 'alpha'
BUNDLE_DEFAULT_CHANNEL ?= alpha##@ Set the default channel for the bundle, defaults to 'alpha'
BUNDLE_IMAGE_NAME ?= $(IMAGE_NAME)-bundle##@ Set the image name for the bundle, defaults to IMAGE_NAME-bundle
BUNDLE_TARGET_NAMESPACE ?= $(OPERATOR_TARGET_NAMESPACE)##@ Set the target namespace for running the bundle, defaults to OPERATOR_TARGET_NAMESPACE
BUNDLE_SCORECARD_NAMESPACE ?= $(IMAGE_NAME)-scorecard##@ Set the target namespace for running scorecard tests, defaults to IMAGE_NAME-scorecard

####################################################
###### Required tools customization variables ######
####################################################
REQ_BIN_AWK ?= awk##@ Set a custom 'awk' binary path if not in PATH
REQ_BIN_OC ?= oc##@ Set a custom 'oc' binary path if not in PATH
REQ_BIN_GO ?= go##@ Set a custom 'go' binary path if not in PATH (useful for multi versions environment)
REQ_BIN_CURL ?= curl##@ Set a custom 'curl' binary path if not in PATH
REQ_BIN_YQ ?= yq##@ Set a custom 'yq' binary path if not in PATH

######################################################
###### Downloaded tools customization variables ######
######################################################
BIN_CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen##@ Set custom 'controller-gen', if not supplied will install latest in ./bin
BIN_OPERATOR_SDK ?= $(LOCALBIN)/operator-sdk##@ Set custom 'operator-sdk', if not supplied will install latest in ./bin
BIN_KUSTOMIZE ?= $(LOCALBIN)/kustomize##@ Set custom 'kustomize', if not supplied will install latest in ./bin
BIN_GREMLINS ?= $(LOCALBIN)/gremlins##@ Set custom 'gremlins', if not supplied will install latest in ./bin
BIN_GO_TEST_COVERAGE ?= $(LOCALBIN)/go-test-coverage##@ Set custom 'go-test-coverage', if not supplied will install latest in ./bin
BIN_GOLINTCI ?= $(LOCALBIN)/golangci-lint##@ Set custom 'golangci-lint', if not supplied will install latest in ./bin
BIN_ACTIONLINT ?= $(LOCALBIN)/actionlint##@ Set custom 'actionlint', if not supplied will install latest in ./bin
BIN_GO_LICENSES ?= $(LOCALBIN)/go-licenses##@ Set custom 'go-licenses', if not supplied will install latest in ./bin

################################################
###### Downloaded tools version variables ######
################################################
VERSION_CONTROLLER_GEN = v0.14.0
VERSION_OPERATOR_SDK = v1.33.0
VERSION_KUSTOMIZE = v5.3.0
VERSION_GREMLINS = v0.5.0
VERSION_GO_TEST_COVERAGE = v2.8.2
VERSION_GOLANG_CI_LINT = v1.55.2
VERSION_ACTIONLINT = v1.6.26
VERSION_GO_LICENSES = v1.6.0

#####################################
###### Build related variables ######
#####################################
BUILD_DATE = $(strip $(shell date +%FT%T))
BUILD_TIMESTAMP = $(strip $(shell date -d "$(BUILD_DATE)" +%s))
COMMIT_HASH = $(strip $(shell git rev-parse --short HEAD))
LDFLAGS=-ldflags="\
-X 'regional-dr-trigger-operator/pkg/version.tag=${IMAGE_TAG}' \
-X 'regional-dr-trigger-operator/pkg/version.commit=${COMMIT_HASH}' \
-X 'regional-dr-trigger-operator/pkg/version.date=${BUILD_DATE}' \
"

####################################
###### Test related variables ######
####################################
COVERAGE_THRESHOLD ?= 60##@ Set the unit test code coverage threshold, defaults to '60'

#########################
###### Image names ######
#########################
FULL_OPERATOR_IMAGE_NAME = $(strip $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_NAME):$(IMAGE_TAG))
FULL_OPERATOR_IMAGE_NAME_UNIQUE = $(FULL_OPERATOR_IMAGE_NAME)_$(COMMIT_HASH)_$(BUILD_TIMESTAMP)
FULL_BUNDLE_IMAGE_NAME = $(strip $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(BUNDLE_IMAGE_NAME):$(IMAGE_TAG))
FULL_BUNDLE_IMAGE_NAME_UNIQUE = $(FULL_BUNDLE_IMAGE_NAME)_$(COMMIT_HASH)_$(BUILD_TIMESTAMP)

####################################
###### Build and push project ######
####################################
build/all/image: build/operator/image build/bundle/image ## Build both the operator and bundle images

build/all/image/push: build/operator/image/push build/bundle/image/push ## Build and push both the operator and bundle images

.PHONY: build build/operator
build build/operator: $(LOCALBUILD) ## Build the project as a binary in ./build
	$(REQ_BIN_GO) mod tidy
	$(REQ_BIN_GO) build $(LDFLAGS) -o $(LOCALBUILD)/rdrtrigger ./main.go

.PHONY: build/operator/image
build/operator/image: ## Build the operator image, customized with IMAGE_REGISTRY, IMAGE_NAMESPACE, IMAGE_NAME, and IMAGE_TAG
	$(IMAGE_BUILDER) build --ignorefile ./.gitignore --tag $(FULL_OPERATOR_IMAGE_NAME) -f ./Containerfile

build/operator/image/push: build/operator/image ## Build and push the operator image, customized with IMAGE_REGISTRY, IMAGE_NAMESPACE, IMAGE_NAME, and IMAGE_TAG
	$(IMAGE_BUILDER) tag $(FULL_OPERATOR_IMAGE_NAME) $(FULL_OPERATOR_IMAGE_NAME_UNIQUE)
	$(IMAGE_BUILDER) push $(FULL_OPERATOR_IMAGE_NAME_UNIQUE)
	$(IMAGE_BUILDER) push $(FULL_OPERATOR_IMAGE_NAME)

.PHONY: build/bundle/image
build/bundle/image: ## Build the bundle image, customized with IMAGE_REGISTRY, IMAGE_NAMESPACE, BUNDLE_IMAGE_NAME, and IMAGE_TAG
	$(IMAGE_BUILDER) build --ignorefile ./.gitignore --tag $(FULL_BUNDLE_IMAGE_NAME) -f ./bundle/bundle.Containerfile

build/bundle/image/push: build/bundle/image ## Build and push the bundle image, customized with IMAGE_REGISTRY, IMAGE_NAMESPACE, BUNDLE_IMAGE_NAME, and IMAGE_TAG
	$(IMAGE_BUILDER) tag $(FULL_BUNDLE_IMAGE_NAME) $(FULL_BUNDLE_IMAGE_NAME_UNIQUE)
	$(IMAGE_BUILDER) push $(FULL_BUNDLE_IMAGE_NAME_UNIQUE)
	$(IMAGE_BUILDER) push $(FULL_BUNDLE_IMAGE_NAME)

###########################################
###### Code and Manifests generation ######
###########################################
generate/all: generate/manifests generate/bundle ## Generate both rbac and olm bundle files

.PHONY: generate/manifests
generate/manifests: $(BIN_CONTROLLER_GEN) $(BIN_KUSTOMIZE) ## Generate rbac manifest files
	$(BIN_CONTROLLER_GEN) rbac:roleName=role paths="./pkg/controller/..."

.PHONY: generate/bundle
generate/bundle: $(BIN_OPERATOR_SDK) $(BIN_KUSTOMIZE) ## Generate olm bundle
	$(call kustomize-setup)
	$(BIN_KUSTOMIZE) build config/manifests | $(BIN_OPERATOR_SDK) generate bundle --quiet --version $(IMAGE_TAG) \
	--package $(BUNDLE_PACKAGE_NAME) --channels $(BUNDLE_CHANNELS) --default-channel $(BUNDLE_DEFAULT_CHANNEL)
	mv -f ./bundle.Dockerfile ./bundle/bundle.Containerfile
	$(call kustomize-cleanup)

################################################
###### Install and Uninstall the operator ######
################################################
.PHONY: operator/deploy
operator/deploy: $(BIN_KUSTOMIZE) ## Deploy the Regional DR Trigger Operator
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	$(call kustomize-setup)
	$(BIN_KUSTOMIZE) build config/default | $(REQ_BIN_OC) apply -f -
	$(call kustomize-cleanup)

.PHONY: operator/undeploy
operator/undeploy: $(BIN_KUSTOMIZE) ## Undeploy the Regional DR Trigger Operator
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	$(call kustomize-setup)
	$(BIN_KUSTOMIZE) build config/default | $(REQ_BIN_OC) delete --ignore-not-found -f -
	$(call kustomize-cleanup)

.PHONY: bundle/run
bundle/run: $(BIN_OPERATOR_SDK) ## Run the Regional DR Trigger Operator OLM Bundle from image
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	-$(REQ_BIN_OC) create ns $(BUNDLE_TARGET_NAMESPACE)
	$(BIN_OPERATOR_SDK) run bundle $(FULL_BUNDLE_IMAGE_NAME) -n $(BUNDLE_TARGET_NAMESPACE)

.PHONY: bundle/cleanup
bundle/cleanup: $(BIN_OPERATOR_SDK) ## Cleanup the Regional DR Trigger Operator OLM Bundle package installed
	$(BIN_OPERATOR_SDK) cleanup $(BUNDLE_PACKAGE_NAME) -n $(BUNDLE_TARGET_NAMESPACE)

.PHONY: bundle/cleanup/namespace
bundle/cleanup/namespace: ## DELETE the Regional DR Trigger Operator OLM Bundle namespace (BE CAREFUL)
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	$(REQ_BIN_OC) delete ns $(BUNDLE_TARGET_NAMESPACE)

###########################
###### Test codebase ######
###########################
.PHONY: test
test: ## Run all unit tests
	$(REQ_BIN_GO) test -v ./...

.PHONY: test/cov
test/cov: $(BIN_GO_TEST_COVERAGE) ## Run all unit tests and print coverage report, use the COVERAGE_THRESHOLD var for setting threshold
	$(REQ_BIN_GO) test -failfast -coverprofile=cov.out -v ./...
	$(REQ_BIN_GO) tool cover -func=cov.out
	$(REQ_BIN_GO) tool cover -html=cov.out -o cov.html
	$(BIN_GO_TEST_COVERAGE) -p cov.out -k 0 -t $(COVERAGE_THRESHOLD)

.PHONY: test/mut
test/mut: $(BIN_GREMLINS) ## Run mutation tests
	$(BIN_GREMLINS) unleash

.PHONY: test/bundle
test/bundle: $(BIN_OPERATOR_SDK) ## Run Scorecard Bundle Tests (requires connected cluster)
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	@ { \
	if $(REQ_BIN_OC) create ns $(BUNDLE_SCORECARD_NAMESPACE); then \
		$(BIN_OPERATOR_SDK) scorecard ./bundle -n $(BUNDLE_SCORECARD_NAMESPACE) --pod-security=restricted; \
		$(REQ_BIN_OC) delete ns $(BUNDLE_SCORECARD_NAMESPACE); \
	else \
		$(BIN_OPERATOR_SDK) scorecard ./bundle -n $(BUNDLE_SCORECARD_NAMESPACE) --pod-security=restricted; \
	fi \
	}

.PHONY: test/bundle/delete/ns
test/bundle/delete/ns: ## DELETE the Scorecard namespace (BE CAREFUL)
	$(call verify-essential-tool,$(REQ_BIN_OC),REQ_BIN_OC)
	-$(REQ_BIN_OC) delete ns $(BUNDLE_SCORECARD_NAMESPACE)

###########################
###### Lint codebase ######
###########################
lint/all: lint/code lint/licenses lint/ci lint/containerfile lint/bundle ## Lint the entire project (code, ci, containerfile)

.PHONY: lint lint/code
lint lint/code: $(BIN_GOLINTCI) ## Lint the code
	$(REQ_BIN_GO) fmt ./...
	$(BIN_GOLINTCI) run

.PHONY: lint/licenses
lint/licenses: $(BIN_GO_LICENSES) ## Verify we're not using any dependencies with forbidden licences
	$(BIN_GO_LICENSES) check .

.PHONY: lint/ci
lint/ci: $(BIN_ACTIONLINT) ## Lint the ci
	$(BIN_ACTIONLINT) --verbose

.PHONY: lint/containerfile
lint/containerfile: ## Lint the Containerfile (using Hadolint image, do not use inside a container)
	$(IMAGE_BUILDER) run --rm -i docker.io/hadolint/hadolint:latest < ./Containerfile

.PHONY: lint/bundle
lint/bundle: $(BIN_OPERATOR_SDK) ## Validate OLM bundle
	$(BIN_OPERATOR_SDK) bundle validate ./bundle --select-optional suite=operatorframework

################################
###### Display build help ######
################################
help: ## Show this help message
	$(call verify-essential-tool,$(REQ_BIN_AWK),REQ_BIN_AWK)
	@$(REQ_BIN_AWK) 'BEGIN {\
			FS = ".*##@";\
			print "\033[1;31mRegional DR Trigger Operator\033[0m";\
			print "\033[1;32mUsage\033[0m";\
			printf "\t\033[1;37mmake <target> |";\
			printf "\tmake <target> [Variables Set] |";\
            printf "\tmake [Variables Set] <target> |";\
            print "\t[Variables Set] make <target>\033[0m";\
			print "\033[1;32mAvailable Variables\033[0m" }\
		/^(\s|[a-zA-Z_0-9-]|\/)+ \?=.*?##@/ {\
			split($$0,t,"?=");\
			printf "\t\033[1;36m%-35s \033[0;37m%s\033[0m\n",t[1], $$2 | "sort" }'\
		$(MAKEFILE_LIST)
	@$(REQ_BIN_AWK) 'BEGIN {\
			FS = ":.*##";\
			SORTED = "sort";\
            print "\033[1;32mAvailable Targets\033[0m"}\
		/^(\s|[a-zA-Z_0-9-]|\/)+:.*?##/ {\
			if($$0 ~ /deploy/)\
				printf "\t\033[1;36m%-35s \033[0;33m%s\033[0m\n", $$1, $$2 | SORTED;\
			else if($$0 ~ /push/)\
				printf "\t\033[1;36m%-35s \033[0;35m%s\033[0m\n", $$1, $$2 | SORTED;\
			else if($$0 ~ /DELETE/)\
				printf "\t\033[1;36m%-35s \033[0;31m%s\033[0m\n", $$1, $$2 | SORTED;\
			else\
				printf "\t\033[1;36m%-35s \033[0;37m%s\033[0m\n", $$1, $$2 | SORTED; }\
		END { \
			close(SORTED);\
			print "\033[1;32mFurther Information\033[0m";\
			print "\t\033[0;37m* Source code: \033[38;5;26mhttps://github.com/RHEcosystemAppEng/regional-dr-trigger-operator\33[0m"}'\
		$(MAKEFILE_LIST)

####################################
###### Install required tools ######
####################################
$(BIN_KUSTOMIZE): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install sigs.k8s.io/kustomize/kustomize/v5@$(VERSION_KUSTOMIZE)

$(BIN_CONTROLLER_GEN): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install sigs.k8s.io/controller-tools/cmd/controller-gen@$(VERSION_CONTROLLER_GEN)

$(BIN_GREMLINS): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install github.com/go-gremlins/gremlins/cmd/gremlins@$(VERSION_GREMLINS)

$(BIN_GO_TEST_COVERAGE): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install github.com/vladopajic/go-test-coverage/v2@$(VERSION_GO_TEST_COVERAGE)

$(BIN_GOLINTCI): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@$(VERSION_GOLANG_CI_LINT)

$(BIN_ACTIONLINT): $(LOCALBIN) # recommendation: manually install shellcheck and verify it's on your PATH, it will be picked up by actionlint
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install github.com/rhysd/actionlint/cmd/actionlint@$(VERSION_ACTIONLINT)

$(BIN_GO_LICENSES): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(REQ_BIN_GO) install github.com/google/go-licenses@$(VERSION_GO_LICENSES)

$(BIN_OPERATOR_SDK): $(LOCALBIN)
	$(call verify-essential-tool,$(REQ_BIN_CURL),REQ_BIN_CURL)
	OS=$(shell go env GOOS) && \
	ARCH=$(shell go env GOARCH) && \
	$(REQ_BIN_CURL) -sSLo $(BIN_OPERATOR_SDK) https://github.com/operator-framework/operator-sdk/releases/download/$(VERSION_OPERATOR_SDK)/operator-sdk_$${OS}_$${ARCH}
	chmod +x $(BIN_OPERATOR_SDK)

###############################
###### Utility functions ######
###############################
define kustomize-setup
$(call verify-essential-tool,$(REQ_BIN_YQ),REQ_BIN_YQ)
cp config/default/kustomization.yaml config/default/kustomization.yaml.tmp
cd config/default && \
$(BIN_KUSTOMIZE) edit set image rdrtrigger-image=$(FULL_OPERATOR_IMAGE_NAME) && \
$(BIN_KUSTOMIZE) edit set namespace $(OPERATOR_TARGET_NAMESPACE)
$(REQ_BIN_YQ) -i '.labels[1].pairs."app.kubernetes.io/instance" = "rdrtrigger-$(IMAGE_TAG)"' config/default/kustomization.yaml
$(REQ_BIN_YQ) -i '.labels[1].pairs."app.kubernetes.io/version" = "$(IMAGE_TAG)"' config/default/kustomization.yaml
cp config/manager/namespace.yaml config/manager/namespace.yaml.tmp
$(REQ_BIN_YQ) -i '.metadata.name = "$(OPERATOR_TARGET_NAMESPACE)"' config/manager/namespace.yaml
endef

define kustomize-cleanup
-mv config/default/kustomization.yaml.tmp config/default/kustomization.yaml
-mv config/manager/namespace.yaml.tmp config/manager/namespace.yaml
endef

# arg1 = name of the tool to look for | arg2 = name of the variable for a custom replacement
TOOL_MISSING_ERR_MSG = Please install '$(1)' or specify a custom path using the '$(2)' variable
define verify-essential-tool
@if !(which $(1) &> /dev/null); then \
	echo $(call TOOL_MISSING_ERR_MSG,$(1),$(2)); \
	exit 1; \
fi
endef
