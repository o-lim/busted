
INSTALL = install --mode=644
REMOVE = rm -f

BASH_COMPLETION_DIR = /etc/bash_completion.d/

ZSH_SITE_FUNCTIONS_DIR = /usr/share/zsh/site-functions/
ifeq ($(wildcard $(ZSH_SITE_FUNCTIONS_DIR)),)
ZSH_SITE_FUNCTIONS_DIR = /usr/local/share/zsh/site-functions/
endif

ifneq ($(wildcard $(BASH_COMPLETION_DIR)),)
INSTALL_DEPS += install_bash_completion
endif
ifneq ($(wildcard $(ZSH_SITE_FUNCTIONS_DIR)),)
INSTALL_DEPS += install_zsh_completion
endif

default:

install: $(INSTALL_DEPS)

install_bash_completion:
	@$(INSTALL) completions/bash/busted.bash $(BASH_COMPLETION_DIR)

install_zsh_completion:
	@$(INSTALL) completions/zsh/_busted $(ZSH_SITE_FUNCTIONS_DIR)

uninstall: uninstall_bash_completion uninstall_zsh_completion

uninstall_bash_completion:
	@$(REMOVE) $(BASH_COMPLETION_DIR)/busted.bash

uninstall_zsh_completion:
	@$(REMOVE) $(ZSH_SITE_FUNCTIONS_DIR)/_busted

