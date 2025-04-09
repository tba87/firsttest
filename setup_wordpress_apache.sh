#!/bin/bash

# WordPress Local Setup Script
# This script installs Apache2, PHP, MySQL, and WordPress for local development
# Note: This is for LOCAL DEVELOPMENT ONLY, not for production use

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt-get update

# Install Apache2
echo "Installing Apache2..."
apt-get install -y apache2

# Install MySQL (without secure installation)
echo "Installing MySQL server..."
debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
apt-get install -y mysql-server mysql-client

# Install PHP and required extensions
echo "Installing PHP and extensions..."
apt-get install -y php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

# Restart Apache to load PHP module
systemctl restart apache2

# Create WordPress database
echo "Creating WordPress database..."
mysql -u root -proot <<MYSQL_SCRIPT
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'wordpressuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Download and configure WordPress
echo "Setting up WordPress..."
cd /tmp || exit
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz

# Ask for installation directory
read -rp "Enter the directory name to install WordPress (e.g., 'mywebsite'): " dirname
read -rp "Enter the full path where to install WordPress (default: /var/www/html/): " installpath
installpath=${installpath:-/var/www/html/}

# Create directory and move WordPress files
mkdir -p "$installpath$dirname"
cp -r /tmp/wordpress/* "$installpath$dirname/"

# Set permissions
chown -R www-data:www-data "$installpath$dirname"
find "$installpath$dirname" -type d -exec chmod 755 {} \;
find "$installpath$dirname" -type f -exec chmod 644 {} \;

# Create WordPress config file
cp "$installpath$dirname/wp-config-sample.php" "$installpath$dirname/wp-config.php"

# Configure WordPress database settings
sed -i "s/database_name_here/wordpress/" "$installpath$dirname/wp-config.php"
sed -i "s/username_here/wordpressuser/" "$installpath$dirname/wp-config.php"
sed -i "s/password_here/password/" "$installpath$dirname/wp-config.php"

# Configure Apache virtual host
echo "Creating Apache virtual host..."
cat > /etc/apache2/sites-available/"$dirname".conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $installpath$dirname

    <Directory $installpath$dirname>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the site and rewrite module
a2ensite "$dirname".conf
a2enmod rewrite
systemctl restart apache2

# Clean up
rm -rf /tmp/wordpress /tmp/latest.tar.gz

# Display installation summary
echo ""
echo "============================================"
echo "WordPress installation complete!"
echo "============================================"
echo "Website URL: http://localhost/$dirname"
echo "Database Name: wordpress"
echo "Database User: wordpressuser"
echo "Database Password: password"
echo "MySQL Root Password: root"
echo ""
echo "You can now access WordPress setup in your browser."
echo "============================================"
