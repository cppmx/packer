#!/bin/bash

# Instalar dependencias
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y nginx nodejs npm
sudo npm i -g pm2

# Crear el directorio de trabajo
sudo mkdir /app

# Mover los archivos de la carpeta temporal a y sus respectivas ubicaciones
sudo mv -f /tmp/app.js /app/app.js
sudo mv -f /tmp/nginx.conf /etc/nginx/nginx.conf

# Iniciar la aplicación como demonio y guardar el estado
sudo pm2 start /app/app.js
sudo pm2 save
sudo pm2 startup

# Iniciar el proxy Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

