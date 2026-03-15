# inspo from https://gist.github.com/jyio/22bfc530fda828652b4be6daa176f829

PREFIX := $(shell pwd)
dockercompose = docker compose -f docker-compose.yml

%.pull:
	cd $(PREFIX)/$* && $(dockercompose) pull
%.build:
	cd $(PREFIX)/$* && $(dockercompose) build
%.up:
	cd $(PREFIX)/$* && $(dockercompose) up -d
%.recreate:
	cd $(PREFIX)/$* && $(dockercompose) up -d --force-recreate
%.down:
	cd $(PREFIX)/$* && $(dockercompose) down
%.destroy:
	cd $(PREFIX)/$* && $(dockercompose) down --remove-orphans
%.start:
	cd $(PREFIX)/$* && $(dockercompose) start
%.stop:
	cd $(PREFIX)/$* && $(dockercompose) stop
%.kill:
	cd $(PREFIX)/$* && $(dockercompose) kill
%.restart:
	cd $(PREFIX)/$* && $(dockercompose) restart
%.env:
	cd ./$* && ln -sf ../.env .env

PROJECTS = caddy homepage media deluge-vpn immich monitoring dockge authentik czkawka

.PHONY: list-projects
list-projects:
	@echo -e '\033[1;31mProjects:\033[0m \033[1;34m'$(PROJECTS)'\033[0m'

.PHONY: pull
pull: list-projects $(patsubst %, %.pull, $(PROJECTS))

.PHONY: up
up: list-projects $(patsubst %, %.up, $(PROJECTS))

.PHONY: down
down: list-projects $(patsubst %, %.down, $(PROJECTS))

.PHONY: env
env: list-projects $(patsubst %, %.env, $(PROJECTS))

.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help          Show this help message"
	@echo "  list-projects List all defined projects"
	@echo "  pull          Run 'docker compose pull' for all projects"
	@echo "  up            Run 'docker compose up -d' for all projects"
	@echo "  down          Run 'docker compose down' for all projects"
	@echo "  env           Symlink shared .env file into all project dirs"
	@echo ""
	@echo "Per-project commands:"
	@echo "  <project>.pull       Pull images"
	@echo "  <project>.build      Build containers"
	@echo "  <project>.up         Start services"
	@echo "  <project>.recreate   Recreate containers"
	@echo "  <project>.down       Stop and remove containers"
	@echo "  <project>.destroy    Down with --remove-orphans"
	@echo "  <project>.start      Start services"
	@echo "  <project>.stop       Stop services"
	@echo "  <project>.kill       Kill services"
	@echo "  <project>.restart    Restart services"
	@echo "  <project>.env        Create symlink to shared .env"

.DEFAULT_GOAL := help
