.PHONY: test usuarios monedas transacciones init docker-up docker-down psql-dev psql-test verify reload-dev reload-test

# Detectar sistema operativo
ifeq ($(OS),Windows_NT)
	SHELL := powershell.exe
	.SHELLFLAGS := -NoProfile -Command
	SET_ENV = $$env:MIX_ENV='$(1)';
	SLEEP = Start-Sleep -Seconds $(1)
else
	SET_ENV = MIX_ENV=$(1)
	SLEEP = sleep $(1)
endif

test:
ifeq ($(OS),Windows_NT)
	powershell -Command "$$env:MIX_ENV='test'; mix test --cover"
else
	MIX_ENV=test mix test --cover
endif

reload_all:
	MIX_ENV=dev mix deps.get
	MIX_ENV=dev mix ecto.rollback --all
	MIX_ENV=dev mix ecto.migrate
	MIX_ENV=test mix deps.get
	MIX_ENV=test mix ecto.rollback --all
	MIX_ENV=test mix ecto.migrate
ifeq ($(OS),Windows_NT)
	powershell -Command "$$env:MIX_ENV='dev'; mix escript.build"
else
	MIX_ENV=dev mix escript.build
endif

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

psql-dev:
	docker-compose exec db psql -U gabosawn -d ledger_repo

psql-test:
	docker-compose exec db psql -U gabosawn -d ledger_repo_test

init:
	make docker-up
	mix deps.get
	mix compile.app
ifeq ($(OS),Windows_NT)
	powershell -Command "$$env:MIX_ENV='dev'; mix escript.build"
else
	MIX_ENV=dev mix escript.build
endif
	MIX_ENV=test mix ecto.create
	MIX_ENV=test mix ecto.migrate
	MIX_ENV=dev mix ecto.create
	MIX_ENV=dev mix ecto.migrate