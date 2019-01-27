#!/bin/bash
# Copies default files over to the correct locations to setup the environment.

# Setup environment variables and WP-CLI configuration.
if [ ! -e .env ]; then
  cp config/.env .env
fi
if [ ! -e wp-cli.yml ]; then
  cp config/wp-cli.yml public/wp-cli.yml;
fi
