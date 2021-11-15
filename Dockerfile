# Build development image
FROM        ruby:2.7 as development

RUN         apt-get update && apt-get install -y cron
RUN         useradd -m -U app \
         && su -s /bin/bash -c "mkdir -p /home/app/switchyard" app
WORKDIR     /home/app/switchyard
COPY        --chown=app:app . .
RUN         bundle install --with development test debug --without production
USER app
ENV         RACK_ENV=development
RUN         bundle exec whenever --update-crontab
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]

# Build production image
FROM        ruby:2.7 as production

RUN         apt-get update && apt-get install -y cron
RUN         useradd -m -U app \
         && su -s /bin/bash -c "mkdir -p /home/app/switchyard" app
WORKDIR     /home/app/switchyard
COPY        --chown=app:app . .
RUN         bundle install --without development test debug --with production
USER app
ENV         RACK_ENV=production
RUN         bundle exec whenever --update-crontab
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
# Run cron in a separate container with --user root and the command being `cron -f`
