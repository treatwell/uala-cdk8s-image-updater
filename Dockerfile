FROM ruby:2.7.5-slim AS base
RUN apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get install -y build-essential \
                       apt-transport-https \
                       git \
                       curl \
                       cmake \
                       libpq-dev \
                       libssl-dev \
                       libcurl4-openssl-dev
# Add Github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
     gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update -qq && apt-get install -y gh

# Remove unused packages
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile ./Gemfile
COPY Gemfile.lock ./Gemfile.lock
RUN gem install bundler && \
    bundle install

COPY . .
RUN chmod +x /usr/src/app/updater.rb

CMD ["/usr/src/app/updater.rb"]