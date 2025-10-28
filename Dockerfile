# Use uma imagem base PHP otimizada para web servers
FROM php:8.2-fpm-alpine

# Instalar dependências do sistema e extensões PHP
# Adicionamos make e g++ para compilar as extensões PHP, e os removemos no final para reduzir o tamanho da imagem.
RUN apk add --no-cache \
    nginx \
    git \
    supervisor \
    zlib-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    freetype-dev \
    postgresql-dev \
    mysql-client \
    imagemagick-dev \
    make \
    g++ \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) gd pdo_mysql bcmath ctype exif intl mbstring opcache pdo zip \
    && docker-php-ext-enable opcache \
    && rm -rf /var/cache/apk/* \
    && apk del make g++

# Configurar diretório de trabalho
WORKDIR /var/www/html

# Copiar arquivos da aplicação para o container
# Certifique-se de que o seu arquivo .dockerignore esteja configurado para ignorar arquivos desnecessários
COPY . .

# Instalar dependências do Composer
# Usamos uma imagem "composer:latest" para obter o executável do Composer.
# É importante que o Krayin CRM já tenha o arquivo composer.json na raiz do projeto.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Limpar caches de configuração do Laravel
# Estes comandos devem ser executados após o 'composer install'
RUN php artisan cache:clear && \
    php artisan view:clear && \
    php artisan config:clear && \
    php artisan route:clear

# Copiar configurações de Nginx, PHP-FPM e Supervisor
# Verifique se estes arquivos (nginx.conf, php-fpm.conf, supervisord.conf) estão na mesma pasta do Dockerfile
COPY nginx.conf /etc/nginx/nginx.conf
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY supervisord.conf /etc/supervisord.conf

# Expor a porta 80 para o Nginx
EXPOSE 80

# Comando para iniciar o Supervisor, que gerenciará Nginx e PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]