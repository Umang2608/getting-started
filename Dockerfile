# Base Python stage with required build tools for pip
FROM --platform=$BUILDPLATFORM python:3.11-alpine AS base
WORKDIR /app

# Install build dependencies for compiling Python packages
RUN apk add --no-cache gcc musl-dev libffi-dev openssl-dev python3-dev cargo make

# Upgrade pip and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
 && pip install -r requirements.txt

# Base Node.js stage for app build
FROM --platform=$BUILDPLATFORM node:18-alpine AS app-base
WORKDIR /app
COPY app/package.json app/yarn.lock ./
COPY app/spec ./spec
COPY app/src ./src

# Run tests (optional, uncomment if tests are available)
FROM app-base AS test
# RUN yarn install
# RUN yarn test

# Create a zip of the Node.js app
FROM app-base AS app-zip-creator
COPY --from=test /app/package.json /app/yarn.lock ./
COPY app/spec ./spec
COPY app/src ./src
RUN apk add --no-cache zip \
 && zip -r /app.zip /app

# Dev-ready container for mkdocs live reload
FROM --platform=$BUILDPLATFORM base AS dev
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]

# Build the mkdocs static site
FROM --platform=$BUILDPLATFORM base AS build
COPY . .
RUN mkdocs build

# Final production image using Nginx
FROM --platform=$TARGETPLATFORM nginx:alpine
COPY --from=app-zip-creator /app.zip /usr/share/nginx/html/assets/app.zip
COPY --from=build /app/site /usr/share/nginx/html
