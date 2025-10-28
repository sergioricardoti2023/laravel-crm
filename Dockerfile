# --- Stage 1: Composer (para instalar dependências PHP) ---
FROM composer:latest as composer-build

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --optimize-autoloader

# Copia o restante dos arquivos do projeto
COPY . .
# Geração do autoloader para classes
RUN composer dump-autoload --optimize

# --- Stage 2: Aplicação Final ---
FROM php:8.1-fpm-alpine

# Instalação de dependências do sistema
# nginx: servidor web
# supervisor: gerenciador de processos
# openssl-dev: para extensões PHP como pdo_mysql
# git: para instalações via composer/repositórios
# wget: ferramenta para download
# build-base: para compilação de pacotes
# imagemagick-dev: para a extensão imagick (opcional, mas comum para imagem)
# libzip-dev: para a extensão zip
# freetype-dev, libpng-dev, libjpeg-turbo-dev: para a extensão gd
# libxml2-dev: para a extensão xml
RUN apk update && apk add --no-cache \
    nginx \
    supervisor \
    openssl-dev \
    git \
    wget \
    build-base \
    imagemagick-dev \
    libzip-dev \
    freetype-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    libxml2-dev \
    && rm -rf /var/cache/apk/*

# Instalação das extensões PHP
# gd: manipulação de imagens
# pdo_mysql: conexão com MySQL
# zip: compressão/descompressão
# xml: processamento de XML
# mbstring: manipulação de strings multi-byte
# exif: leitura de metadados de imagem
# opcache: cache de bytecode para PHP (performance)
# imagick: manipulação avançada de imagens
RUN docker-php-ext-install -j$(nproc) gd pdo_mysql zip xml mbstring exif opcache \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) bcmath \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# Configuração do Opcache (opcional, mas recomendado para performance)
#COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copiar arquivos de configuração customizados
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
# O php-fpm.conf customizado para logs (renomeando para www.conf)
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

# Criar diretório para logs do Supervisor
RUN mkdir -p /var/log/supervisor

# Diretório de trabalho da aplicação
WORKDIR /var/www/html

# Copiar os arquivos da aplicação
COPY . .

# Copiar as dependências do Composer do stage anterior
COPY --from=composer-build /app/vendor /var/www/html/vendor

# Definir permissões para os diretórios do Laravel/Krayin
# O usuário padrão do Nginx/PHP-FPM em Alpine é 'nginx' ou 'nobody'.
# Vamos usar o UID/GID do usuário padrão do FPM no Alpine, que geralmente é 82 para 'nginx'
# ou 'nobody' (65534). Usar `nginx` é um bom palpite inicial.
# Se o problema persistir, podemos tentar `chown -R 65534:65534 /var/www/html`
RUN chown -R nginx:nginx /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/public

# Expor a porta que o Nginx está ouvindo
EXPOSE 80

# Comando para iniciar o Supervisor que gerenciará Nginx e PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]