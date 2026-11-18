# Makefile — CVE-2026-114938 (Java4Shell) PoC
# Usage: make <target>

.DEFAULT_GOAL := help

JAVA_HOME ?= $(shell dirname $$(dirname $$(readlink -f $$(which java))))
GRADLE     ?= ./gradlew

##@ Setup

.PHONY: preflight
preflight: ## Run CPU and JDK prerequisite checks
	@bash scripts/preflight.sh

.PHONY: setup
setup: ## Download and unpack the pinned vulnerable JDK
	@bash scripts/setup-runtime.sh

##@ Build

.PHONY: build
build: ## Compile the PoC with Gradle
	$(GRADLE) --no-daemon build -x test

.PHONY: build-bare
build-bare: ## Compile the PoC without Gradle (uses JAVA_HOME directly)
	@mkdir -p build/classes
	$(JAVA_HOME)/bin/javac -d build/classes \
	  src/main/java/com/example/java4shell/Base64Trigger.java \
	  src/main/java/com/example/java4shell/Main.java
	@echo "[*] Compiled to build/classes/"

##@ Run

.PHONY: run
run: ## Run the PoC on the current JVM (should detect VULNERABLE on affected hardware)
	@bash scripts/run-poc.sh

.PHONY: run-mitigated
run-mitigated: ## Run the PoC with AVX-512 Base64 intrinsic disabled (negative control)
	@JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics bash scripts/run-poc.sh

.PHONY: run-avx2
run-avx2: ## Run the PoC with AVX capped at level 2 (alternative mitigation)
	@JAVA_TOOL_OPTIONS="-XX:UseAVX=2" bash scripts/run-poc.sh

##@ Docker

.PHONY: docker-build
docker-build: ## Build both Docker images
	docker compose -f docker/docker-compose.yml build

.PHONY: docker-run
docker-run: ## Run both vulnerable and mitigated containers
	docker compose -f docker/docker-compose.yml up --abort-on-container-exit

.PHONY: docker-vulnerable
docker-vulnerable: ## Run vulnerable container only
	docker compose -f docker/docker-compose.yml run --rm vulnerable

.PHONY: docker-mitigated
docker-mitigated: ## Run mitigated container only
	docker compose -f docker/docker-compose.yml run --rm mitigated

.PHONY: docker-clean
docker-clean: ## Remove Docker images and containers for this project
	docker compose -f docker/docker-compose.yml down --rmi all --volumes

##@ Detection

.PHONY: test-suricata
test-suricata: ## Validate Suricata rules syntax (requires suricata installed)
	@if command -v suricata >/dev/null 2>&1; then \
	  suricata -T -c /etc/suricata/suricata.yaml -S detection/suricata.rules && \
	  echo "[ok] Suricata rules valid"; \
	else \
	  echo "[skip] suricata not found — install to validate rules"; \
	fi

.PHONY: test-sigma
test-sigma: ## Convert Sigma rule to Splunk SPL (requires sigma-cli)
	@if command -v sigma >/dev/null 2>&1; then \
	  sigma convert -t splunk detection/sigma.yml; \
	else \
	  echo "[skip] sigma-cli not found — install with: pip install sigma-cli"; \
	fi

##@ Housekeeping

.PHONY: clean
clean: ## Remove compiled class files and downloaded JDKs
	$(GRADLE) --no-daemon clean 2>/dev/null || true
	rm -rf build/ out/ bin/ runtimes/
	find . -name '*.class' -delete
	find . -name 'hs_err_pid*.log' -delete

.PHONY: check-placeholders
check-placeholders: ## Warn about any unreplaced placeholder values
	@echo "Scanning for placeholder values..."
	@grep -rn "YOURNAME\|<YOUR NAME>\|<YOUR_NAME>\|<n>" \
	  --include="*.md" --include="*.yml" --include="*.yaml" \
	  --include="*.java" --include="*.sh" --include="*.gradle" \
	  . || echo "[ok] No placeholders found."

.PHONY: sha256
sha256: ## Print SHA-256 checksums of all source files
	@find src scripts docker detection gradle -type f | sort | xargs sha256sum

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
