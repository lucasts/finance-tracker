#!/bin/bash
# Configurações globais do git

git config --global user.name "Lucas TS"
git config --global user.email "lucas@lucas-ts.com"
git config --global color.ui auto

git config --global alias.st status
git config --global alias.ci commit
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.last "log -1 HEAD"
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.df diff
git config --global alias.dc "diff --cached"
git config --global alias.unstage "reset HEAD --"
git config --global alias.amend "commit --amend"
git config --global alias.rb rebase
git config --global alias.pl pull
git config --global alias.ps push
git config --global alias.fa "fetch --all --prune"

# Alias de terminal para git
if ! grep -q "alias g='git'" ~/.bashrc; then
  echo "alias g='git'" >> ~/.bashrc
fi
