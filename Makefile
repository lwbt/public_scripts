# cspell:ignore precommit
.PHONY: all update-precommit

all: update-precommit

update-precommit:
	pre-commit autoupdate
