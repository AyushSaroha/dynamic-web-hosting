# Use official lightweight Nginx image
FROM nginx:latest

# Remove default nginx website files
RUN rm -rf /usr/share/nginx/html/*

# Copy website files into nginx folder
COPY . /usr/share/nginx/html

# Expose container port
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]
