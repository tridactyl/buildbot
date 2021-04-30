#!/bin/bash

# Initial setup:

# Don't run me unless you actually want to

###cd ~/projects/
###git clone https://github.com/cmcaine/tridactyl
#### Set up AMOKEYS
###npm install
#### cp systemd units
###cp autobuild-tridactyl.{unit,service} .config/systemd/user
###systemctl --user start autobuild-tridactyl.timer
###systemctl --user enable autobuild-tridactyl.timer

# Don't run me unless you actually want to ends

set -e

cd ~/projects/tridactyl

PATH=$(yarn bin):"$PATH"
export PATH
lock=AUTOBUILD.lock

# This script can fail if, for example, internet access is interrupted.
# Not sure what would need a git reset, but it won't hurt.
OLDHEAD=$(git rev-parse HEAD)
cleanup() {
    echo "Build failed, resetting."
    git reset --hard "$OLDHEAD"
    rm $lock
}
trap cleanup ERR INT

if [ -e $lock ]; then
    echo "Another autobuild is running or has left a lock!"
    return 2
else
    touch $lock
fi

git fetch --tags

if [ "$1" = "--force" ] || ! git diff --exit-code --quiet master origin/master; then
    git reset --hard origin/master
    yarn install

    # Delete old artifacts so we don't keep two copies.
    rm -rf ~/projects/tridactyl/web-ext-artifacts/
    mkdir -p ~/projects/tridactyl/web-ext-artifacts/

    scripts/sign
    cp "$(ls --sort=t web-ext-artifacts/*.xpi | head -n1)" web-ext-artifacts/tridactyl-latest.xpi
    rsync -rt ~/projects/tridactyl/web-ext-artifacts/ ~/public_html/betas

    scripts/sign nonewtab
    cp "$(ls --sort=t web-ext-artifacts/nonewtab/*.xpi | head -n1)" web-ext-artifacts/nonewtab/tridactyl_no_new_tab_beta-latest.xpi
    rsync -rt ~/projects/tridactyl/web-ext-artifacts/ ~/public_html/betas

    # We suspect this fails sometimes. We want to still publish the latest xpi if it does fail.
    # Wine currently not installed on the build bot
    # scripts/wine-pyinstaller.sh || true
    # rsync -rt ~/tridactyl/web-ext-artifacts/ ~/public_html/betas
else
    echo "Nothing to do."
fi

rm $lock
