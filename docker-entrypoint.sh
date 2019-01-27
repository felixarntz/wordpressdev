#!/bin/bash
set -euo pipefail

# Allow loopback requests to work.
echo "127.0.0.1  $WP_DOMAIN" >> /etc/hosts

current_dir=$PWD

cd $WP_ROOT_DIR

# Download WordPress into the same directory via both Git and SVN.
if [ ! -e core-dev ]; then
	git clone https://github.com/WordPress/wordpress-develop.git core-dev;
fi
if [ ! -e core-dev/.svn ]; then
	svn co --ignore-externals https://develop.svn.wordpress.org/trunk/ tmp-svn; mv tmp-svn/.svn core-dev/.svn; rm -rf tmp-svn;
fi

# Setup configuration files and install WordPress.
cd $WP_ROOT_DIR/core-dev
if [ ! -e wp-config.php ]; then
	cp /etc/wordpress/wp-config.php wp-config.php;
fi
if [ ! -e wp-tests-config.php ]; then
	cp /etc/wordpress/wp-tests-config.php wp-tests-config.php;
fi
if [ ! -e vendor ]; then
	composer install;
fi
if [ ! -e node_modules ]; then
	npm install;
fi
if [ ! -e build ]; then
	npx grunt;
fi
if ! git config -l --local | grep -q 'alias.svn-up'; then
	git config alias.svn-up '! /etc/wordpress/svn-git-up $1'
fi
if [ ! -e ../content/debug.log ]; then
	touch ../content/debug.log;
fi
if ! wp core is-installed; then
	wp core install --url="https://$WP_DOMAIN/" --title="WordPress Develop" --admin_name="admin" --admin_email="admin@local.test" --admin_password="password"
	wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/'
fi
cd $current_dir

# Create database if it does not exist yet
TERM=dumb php -- <<'EOPHP'
<?php
$stderr = fopen('php://stderr', 'w');
$host = 'mysql';
$user = 'root';
$pass = 'wordpress';
$dbName = 'wordpress';
$maxTries = 10;
do {
	$mysql = new mysqli($host, $user, $pass, '');
	if ($mysql->connect_error) {
		fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
		--$maxTries;
		if ($maxTries <= 0) {
			exit(1);
		}
		sleep(3);
	}
} while ($mysql->connect_error);
if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($dbName) . '`')) {
	fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}
$mysql->close();
EOPHP

exec "$@"
