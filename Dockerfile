# Stage 1: Builder
FROM ruby:3.1.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    yarn \
    npm \
    git \
    tzdata \
    # Add required libs for Rails 7
    libc6-compat

WORKDIR /app

# Install specific bundler version first
RUN gem install bundler -v 2.3.6

# Install gems (with workaround for Rails 7.0.8.7)
COPY Gemfile Gemfile.lock ./
RUN bundle _2.3.6_ install --jobs 4 --retry 3

# Install npm packages
COPY package.json package-lock.json ./
RUN npm install

# Copy the rest of the application
COPY . .

# Precompile assets with secret key
ARG RAILS_ENV=production

ARG RAILS_MASTER_KEY

ENV RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle exec rails assets:precompile; \
    fi

# Stage 2: Runtime
FROM ruby:3.1.2-alpine

# Install runtime dependencies only
RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    tzdata \
    bash \
    # Required for Rails 7
    libc6-compat

WORKDIR /app

# Copy assets from builder stage
COPY --from=builder /app/public/assets /app/public/assets

# Copy gems from builder stage
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

# Copy npm modules from builder stage
COPY --from=builder /app/node_modules /app/node_modules

# Copy application code
COPY --from=builder /app /app

# Expose port 3000
EXPOSE 3000

# Start the application
CMD ["rails", "server", "-b", "0.0.0.0"]