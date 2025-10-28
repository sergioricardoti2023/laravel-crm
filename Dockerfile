dockerfile # Use uma imagem base PHP otimizada para web servers FROM php:8.2-fpm-alpine

# Instalar dependências do sistema e extensões PHP
# (Ajuste conforme as necessidades do Krayin CRM e Laravel)
RUN apk add --no-cache \
    nginx \
    git \
    supervisor \
    # Dependências PHP comuns
    # libpq (para PostgreSQL), pdo_mysql (para MySQL), bcmath, ctype, exif, gd, intl, mbstring, opcache, pdo, soap, zip
    postgresql-dev \
    mysql-client \
    imagemagick-dev \
    && docker-php-ext-install pdo_mysql bcmath ctype exif gd intl mbstring opcache pdo zip \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install gd \
    && docker-php-ext-enable opcache

# Configurar diretório de trabalho
WORKDIR /var/www/html

# Copiar arquivos da aplicação
# Certifique-se de que o .dockerignore exclua node_modules, vendor, etc. se você for construí-los dentro do container
COPY . .

# Instalar dependências do Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Gerar chave da aplicação, otimizar cache, etc.
# IMPORTANTE: Essas tarefas podem ser movidas para o processo de deploy no Easypanel
# RUN php artisan key:generate --ansi
# RUN php artisan config:cache
# RUN php artisan route:cache
# RUN php artisan view:cache

# Configuração Nginx para servir a pasta public
COPY nginx.conf /etc/nginx/nginx.conf

# Configuração PHP-FPM (para Laravel)
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf

# Copiar configuração do Supervisor para gerenciar PHP-FPM e Nginx
COPY supervisord.conf /etc/supervisord.conf

# Limpar caches de configuração
RUN php artisan cache:clear && \
    php artisan view:clear && \
    php artisan config:clear && \
    php artisan route:clear

# Expor porta 80 para Nginx
EXPOSE 80

# Comando para iniciar Supervisor, que iniciará Nginx e PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]