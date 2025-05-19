# inspo from https://gist.github.com/jyio/22bfc530fda828652b4be6daa176f829

#PREFIX := ~/homelab/docker
PREFIX := $(shell pwd)

# Path to the .env file (modify if needed)
ENV_FILE = $(shell pwd)/.env

# use only the default docker compose file
dockercompose = docker compose -f compose.yml

# define project-specific targets
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
%.restart: 
	cd $(PREFIX)/$* && $(dockercompose) restart
%.env:
	cd ./$* && ln -sf ../.env .env
# example special target for Caddy
# .PHONY: caddy.reload
# caddy.reload:
# 	docker exec -w /etc/caddy caddy-main-1 caddy reload

# define projects
PROJECTS = caddy crowdsec authentik immich cloudflare-ddns

# show project list
.PHONY: list-projects
list-projects:
	@echo -e '\033[1;31mProjects:\033[0m \033[1;34m'$(PROJECTS)'\033[0m'

# update projects
.PHONY: pull
pull: list-projects $(patsubst %, %.pull, $(PROJECTS))

# bring projects up
.PHONY: up
up: list-projects $(patsubst %, %.up, $(PROJECTS))

# take projects down
.PHONY: down
down: list-projects $(patsubst %, %.down, $(PROJECTS))

# add env symlink
.PHONY: env
env: list-projects $(patsubst %, %.env, $(PROJECTS))

# Copy docker folder to docker host
.PHONY: copy
copy:
	scp -r ./ 10.0.0.30:homelab/docker

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
	@echo "  copy          SCP everything to 10.0.0.30:homelab/docker"
	@echo ""
	@echo "Per-project commands:"
	@echo "  <project>.pull       Pull images"
	@echo "  <project>.build      Build containers"
	@echo "  <project>.up         Start containers"
	@echo "  <project>.recreate   Recreate containers"
	@echo "  <project>.down       Stop and remove containers"
	@echo "  <project>.destroy    Down with --remove-orphans"
	@echo "  <project>.start      Start services"
	@echo "  <project>.stop       Stop services"
	@echo "  <project>.kill       Kill services"
	@echo "  <project>.restart    Restart services"
	@echo "  <project>.env        Create symlink to shared .env"

.DEFAULT_GOAL := help
