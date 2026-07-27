FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
COPY apps/backend/package*.json apps/backend/
COPY apps/frontend/package*.json apps/frontend/
RUN npm install
COPY . .
RUN npm run build
ENV NODE_ENV=production
EXPOSE 3003
CMD ["node", "apps/backend/server.js"]
