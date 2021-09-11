#!/bin/sh

PROJECT_PATH="`dirname "$0"`"
CONFIG_PATH=".eslintrc.yml"
FILES=(
    "plugins/gnome/extension/*.js"
)

cd $PROJECT_PATH
eslint --config $CONFIG_PATH $FILES
