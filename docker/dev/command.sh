#!/bin/bash
VERSION=$(cat .lexicon-version)
LIGHT="${VERSION%-*}-light"
INITIALIZED=docker/db/.initialized
if [ ! -e "$INITIALIZED" ]; then
    pushd /lexicon-client
    bundle install
    bin/lexicon remote download $LIGHT
    bin/lexicon production load $LIGHT
    bin/lexicon production enable
    popd
    bundle install
    yarn install --check-files
    bundle exec rake db:migrate
    bundle exec rake tenant:init TENANT=default EMAIL=default@ekylibre.com PASSWORD=ekylibre;
    echo "$(tput setaf 2)A default farm has been created and will be accessible at http://default.ekylibre.lan:3000"
    echo "$(tput setaf 2)Email: default@ekylibre.com"
    echo "$(tput setaf 2)Password: ekylibre"
    echo "initialized" > docker/db/.initialized
fi
rm -f tmp/pids/server.pid
yarn install --check-files;
bundle install;
bundle exec rake db:migrate
RAILS_ENV=development ./bin/rails s -p 3000 -b '0.0.0.0';
