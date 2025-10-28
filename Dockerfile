# Use uma imagem base PHP otimizada para web servers
FROM php:8.2-fpm-alpine

# 1. Atualiza a lista de pacotes e instala as dependências do sistema.
# Inclui Nginx, Git, Supervisor, e as libs de desenvolvimento para GD, PostgreSQL, Imagemagick, Oniguruma (para mbstring) e libzip (para a extensão PHP zip).
# AS NOVAS DEPENDÊNCIAS PARA A EXTENSÃO CALENDAR TAMBÉM SÃO ADICIONADAS.
# As ferramentas de build (make, g++) são instaladas para a compilação das extensões PHP.
RUN apk update && apk add --no-cache \
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
    oniguruma-dev \
    libzip-dev \
    # Adicionando o pacote da extensão calendar
    php82-calendar \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# 2. Configura e instala a extensão GD (para processamento de imagens)
RUN docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) gd

# 3. Instala as outras extensões PHP necessárias
# Note que a extensão 'calendar' foi adicionada aqui também.
RUN docker-php-ext-install -j$(nproc) pdo_mysql bcmath ctype exif intl mbstring opcache pdo zip calendar

# 4. Habilita a extensão opcache
RUN docker-php-ext-enable opcache

# 5. Remove as ferramentas de build (make, g++) para reduzir o tamanho final da imagem Docker.
RUN apk del make g++

# Configurar diretório de trabalho da aplicação
WORKDIR /var/www/html

# Copiar arquivos da aplicação para o container
# Certifique-se de que o seu arquivo .dockerignore esteja configurado para ignorar arquivos desnecessários como node_modules, .git, etc.
COPY . .

# Instalar dependências do Composer
# Usamos uma imagem "composer:latest" para obter o executável do Composer, garantindo que seja uma versão atualizada.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Limpar caches de configuração do Laravel
# Estes comandos devem ser executados após o 'composer install' para garantir que as configurações sejam carregadas corretamente.
RUN php artisan cache:clear && \
    php artisan view:clear && \
    php artisan config:clear && \
    php artisan route:clear

# Copiar configurações de Nginx, PHP-FPM e Supervisor
# Estes arquivos devem estar na mesma pasta do Dockerfile.
COPY nginx.conf /etc/nginx/nginx.conf
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY supervisord.conf /etc/supervisord.conf

# *** ADICIONE ESTA LINHA AQUI ***
# Cria o diretório de logs para o Supervisor
RUN mkdir -p /var/log/supervisor

# Expor a porta 80, que será usada pelo Nginx
EXPOSE 80

# Comando principal para iniciar o Supervisor, que por sua vez iniciará Nginx e PHP-FPM
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]