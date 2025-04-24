# Stage 1: Builder
FROM ruby:3.1.2-alpine AS builder 

# Install essential build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git \
    nodejs \
    yarn \
    tzdata

# Update bundler to match your lockfile
RUN gem install bundler:2.3.6

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy the rest of the application
COPY . .

# Generate production assets
ARG RAILS_ENV=production
ARG SECRET_KEY_BASE=placeholder
RUN if [ "${RAILS_ENV}" = "production" ]; then \
    bundle exec rails assets:precompile; \
    fi

# Stage 2: Final
FROM ruby:3.1.2-alpine

# Install runtime dependencies only
RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    tzdata \
    && addgroup -g 1000 app \
    && adduser -u 1000 -G app -s /bin/sh -D app

WORKDIR /app

# Copy from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

COPY docker-entrypoint.sh /app/

# Fix permissions
RUN chmod +x /app/docker-entrypoint.sh && \
    mkdir -p /app/tmp /app/log && \
    chown -R app:app /app/tmp /app/log && \
    chmod -R 0755 /app/tmp /app/log

USER app
RUN ls -la /app/
ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true

EXPOSE 3000

CMD ["/app/docker-entrypoint.sh"]