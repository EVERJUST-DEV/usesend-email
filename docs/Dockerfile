# Build the Fumadocs static export, then serve it with nginx under /docs.
FROM node:20-alpine AS build
WORKDIR /app
# Copy the full source before installing — fumadocs-mdx's postinstall needs the
# project files (source.config.ts etc.); installing with only package.json fails.
COPY . .
RUN npm install --legacy-peer-deps
# basePath defaults to /docs (next.config.mjs) → links/assets under /docs.
RUN npm run build

FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
# Place the export under /docs so requests to /docs/* resolve to files.
COPY --from=build /app/out /usr/share/nginx/html/docs
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
