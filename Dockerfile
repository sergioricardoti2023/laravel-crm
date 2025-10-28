FROM php:8.1-fpm-alpine

# Instalação de dependências do sistema
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
    composer \
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
# calendar: **CORRIGIDO: agora instalado via docker-php-ext-install**
RUN docker-php-ext-install -j$(nproc) gd pdo_mysql zip xml mbstring exif opcache bcmath calendar \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# Configuração do Opcache
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copiar arquivos de configuração customizados
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

# Criar diretório para logs do Supervisor
RUN mkdir -p /var/log/supervisor

# Diretório de trabalho da aplicação
WORKDIR /var/www/html

# Copiar todos os arquivos da aplicação
COPY . .

# Instalar dependências do Composer aqui, APÓS as extensões PHP estarem instaladas
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --optimize-autoloader \
    && composer dump-autoload --optimize

# Definir permissões para os diretórios do Laravel/Krayin
RUN chown -R nginx:nginx /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/public

# Expor a porta que o Nginx está ouvindo
EXPOSE 80

# Comando para iniciar o Supervisor que gerenciará Nginx e PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]