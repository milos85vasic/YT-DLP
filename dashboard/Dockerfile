# Build stage
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npx ng build --configuration production

# Serve stage
FROM nginx:alpine

COPY --from=builder /app/dist/yt-dlp-dashboard/browser /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/conf.d/default.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chmod -R 777 /etc/nginx/conf.d /var/cache/nginx /var/run /usr/share/nginx/html && \
    sed -i 's/user nginx;/user 1000;/g' /etc/nginx/nginx.conf

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
