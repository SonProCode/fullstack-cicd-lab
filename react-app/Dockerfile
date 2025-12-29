# ---------- Build stage ----------
FROM node:16-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# ---------- Runtime stage ----------
FROM nginx:alpine
# Copy code đã build vào
COPY --from=build /app/build /usr/share/nginx/html

# COPY FILE CONFIG NGINX VÀO ĐÂY
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]