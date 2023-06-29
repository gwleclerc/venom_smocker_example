suite = **/*.venom.yml

.PHONY: default
default: build

# Dependencies
REFLEX := $(GOPATH)/bin/reflex
$(REFLEX):
	go install github.com/cespare/reflex@master

MOCKERY := $(GOPATH)/bin/mockery
$(MOCKERY):
	go install github.com/vektra/mockery/v2@latest

venom_version = v1.0.1
VENOM := $(GOPATH)/bin/venom-$(venom_version)
$(VENOM):
	curl -sSfLo $(VENOM) https://github.com/ovh/venom/releases/download/$(venom_version)/venom.darwin-amd64
	chmod +x $(VENOM)

.PHONY: build
build:
	go test -tags=integration -race -coverpkg="./..." -c . -o ./dist/example.test

.PHONY: run
run: $(REFLEX)
	. .env; \
	$(REFLEX) --start-service \
		--decoration='none' \
		--regex='.*\.go$$' \
		-- go run .

.PHONY: test
test:
	go test ./... -coverpkg=./... -coverprofile ./dist/example.cover.out
	go tool cover -html=./dist/example.cover.out -o ./dist/example.cover.html

.PHONY: test-integration
test-integration: $(VENOM)
	. .env; \
	$(VENOM) run venom/**/*.venom.yml --var="myapp=$${MY_APP}" --var="mock_server=$${MOCK_SERVER_ADMIN}" --var="pgsql_dsn=$${POSTGRES_DSN}"  --format=xml --output-dir=./dist

.PHONY: manual-integration
manual-integration: $(VENOM)
	. .env; \
	$(VENOM) run venom/**/manual.yml --var="myapp=$${MY_APP}" --var="mock_server=$${MOCK_SERVER_ADMIN}" --var="pgsql_dsn=$${POSTGRES_DSN}"  --format=xml --output-dir=./dist

.PHONY: integration
PID_FILE:=/tmp/example.test.pid
RES_FILE:=/tmp/example.test.status
integration: build $(VENOM)
	. .env; ./dist/example.test -test.coverprofile=./dist/example.venom.cover.out > ./dist/example.app.log 2>&1 & echo $$! > $(PID_FILE);
	sleep 5;
	. .env; ($(VENOM) run venom/**/*.venom.yml --var="myapp=$${MY_APP}" --var="mock_server=$${MOCK_SERVER_ADMIN}" --var="pgsql_dsn=$${POSTGRES_DSN}" --format=xml --output-dir=./dist; echo $$? > $(RES_FILE)) | tee ./dist/example.venom.log
	kill `cat $(PID_FILE)` 2> /dev/null || true
	go tool cover -html=./dist/example.venom.cover.out -o ./dist/example.venom.cover.html;
	exit `cat $(RES_FILE)`

.PHONY: generate
generate: $(MOCKERY)
	rm -rfv ./sdks/mocks/*.go; $(MOCKERY) --note '+build !codeanalysis' --all --dir "./sdks" --output "./sdks/mocks"
	rm -rfv ./server/database/mocks/*.go; $(MOCKERY) --note '+build !codeanalysis' --all --dir "./server/database" --output "./server/database/mocks"

.PHONY: dependencies
dependencies:
	docker compose up -d

.PHONY: stop-dependencies
stop-dependencies:
	docker compose down --remove-orphans

.PHONY: open-tests
open-tests:
	open ./dist/example.cover.html

.PHONY: open-integration
open-integration:
	open ./dist/example.venom.cover.html

.PHONY: open-smocker
open-smocker:
	open http://localhost:8001