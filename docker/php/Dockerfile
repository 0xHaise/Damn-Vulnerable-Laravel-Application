FROM php:8.2-fpm

# Dependencias para Laravel
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libonig-dev libpng-dev libicu-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath intl

# Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# permisos y usuario
RUN chown -R www-data:www-data /var/www/html

EXPOSE 9000

CMD ["php-fpm"]
