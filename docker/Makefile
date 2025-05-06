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
	ln -sf $(ENV_FILE) $(PREFIX)/$*/.env
# example special target for Caddy
# .PHONY: caddy.reload
# caddy.reload:
# 	docker exec -w /etc/caddy caddy-main-1 caddy reload

# define projects
PROJECTS = caddy

# show project list
.PHONY: list-projects
list-projects:
	@echo -e '\033[1;31mProjects:\033[0m \033[1;34m'$(PROJECTS)'\033[0m'

# update projects
pull: list-projects $(patsubst %, %.pull, $(PROJECTS))

# bring projects up
up: list-projects $(patsubst %, %.up, $(PROJECTS))

# take projects down
down: list-projects $(patsubst %, %.down, $(PROJECTS))

# add env symlink
down: env-projects $(patsubst %, %.env, $(PROJECTS))

.DEFAULT_GOAL := up
