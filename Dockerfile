# Use official Ruby image
FROM ruby:3.2

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      curl \
      gnupg \
      build-essential \
      libpq-dev \
      nodejs \
      postgresql-client \
      git \
      vim \
      tzdata

# Install Yarn (modern method, no apt-key)
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list > /dev/null && \
    apt-get update && apt-get install -y yarn

# Set environment variables
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_JOBS=4 \
    BUNDLE_PATH=/bundle

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install --without development test

# Copy the rest of the app
COPY . .

# Precompile assets
# RUN bundle exec rake assets:precompile

# Expose port Rails will run on
EXPOSE 3000

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
