FROM ruby:3.4.2

# Instale dependências do sistema
RUN apt-get update -qq && \
    apt-get install -y build-essential curl sqlite3 libsqlite3-dev

# Instale Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Instale Yarn 1.22.x
RUN npm install -g yarn@1.22.22

WORKDIR /workspace

# Copie apenas os arquivos de dependências para instalar gems
COPY Gemfile* ./
RUN gem install bundler && bundle install

# Copie o restante do projeto (depois das dependências pra otimizar cache do Docker)
COPY . .
