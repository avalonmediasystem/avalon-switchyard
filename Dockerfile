# Build development image
FROM        ruby:4 AS development

RUN         apt-get update && apt-get install -y cron
RUN         useradd -m -U app \
         && su -s /bin/bash -c "mkdir -p /home/app/switchyard" app
WORKDIR     /home/app/switchyard
COPY        --chown=app:app . .
RUN         bundle config set --local with 'development test debug' \
         && bundle config set --local without 'production' \
         && bundle install
USER app
ENV         RACK_ENV=development
RUN         bundle exec whenever --update-crontab
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]

# Build production image
FROM        ruby:4 AS production

RUN         apt-get update && apt-get install -y cron
RUN         useradd -m -U app \
         && su -s /bin/bash -c "mkdir -p /home/app/switchyard" app
WORKDIR     /home/app/switchyard
COPY        --chown=app:app . .
RUN         bundle config set --local without 'development test debug' \
         && bundle config set --local with 'production' \
         && bundle install
USER app
ENV         RACK_ENV=production
RUN         bundle exec whenever --update-crontab
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
# Run cron in a separate container with --user root and the command being `cron -f`
