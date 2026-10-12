FROM node:22-bookworm-slim
WORKDIR /app
COPY gateway/server.mjs ./gateway/server.mjs
USER node
ENV PORT=8080
ENV WM_BIND_HOST=0.0.0.0
EXPOSE 8080
CMD ["node", "gateway/server.mjs"]
